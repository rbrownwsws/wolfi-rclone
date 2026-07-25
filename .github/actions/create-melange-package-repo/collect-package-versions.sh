#!/usr/bin/env bash
set -euo pipefail

: "${REPO_DIR:?REPO_DIR must be set}"

# 800MiB
LIMIT_BYTES=838860800

API_BASE="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/releases"

AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

total_downloaded_bytes=0

per_page=100
page=1
while true; do
  releases_json=$(curl -sSf "${AUTH_HEADER[@]}" \
    "${API_BASE}?per_page=${per_page}&page=${page}")

  releases_count=$(jq 'length' <<<"${releases_json}")
  if [[ "${releases_count}" -eq 0 ]]; then
    break
  fi

  for release_idx in $(seq 0 $((releases_count - 1))); do
    release_json=$(jq ".[${release_idx}]" <<<"${releases_json}")
    tag=$(jq -r ".tag_name" <<<"${release_json}")
    echo "Found release '${tag}'"

    apk_assets_json=$(jq '[.assets[] | select(.name | endswith(".apk")) | {name: .name, size: .size, url: .browser_download_url}]' <<<"${release_json}")

    packages_count=$(jq 'length' <<<"${apk_assets_json}")

    echo ""
    echo "'${tag}' contains ${packages_count} package(s):"
    jq -r '.[] | .name' <<<"${apk_assets_json}"

    packages_total_size_bytes=$(jq "[.[].size] | add // 0" <<<"${apk_assets_json}")

    potential_total_downloaded_bytes=$((total_downloaded_bytes + packages_total_size_bytes))

    if [[ "${potential_total_downloaded_bytes}" -gt "${LIMIT_BYTES}" ]]; then
      echo ""
      echo "Stopping: release '${tag}' would take us over the size limit"
      exit 0
    fi

    for package_idx in $(seq 0 $((packages_count -1))); do
      package_filename=$(jq -r ".[${package_idx}].name" <<<"${apk_assets_json}")
      package_url=$(jq -r ".[${package_idx}].url" <<<"${apk_assets_json}")

      if [[ "${package_filename}" =~ ^(.+)-([^-]+)-r([0-9]+)-([^-]+)-([^-]+)\.apk$ ]]; then
          name="${BASH_REMATCH[1]}"
          version="${BASH_REMATCH[2]}"
          epoch="${BASH_REMATCH[3]}"
          distro="${BASH_REMATCH[4]}"
          arch="${BASH_REMATCH[5]}"

          # TODO: What do we do with distro? Error out if not what we expect?
      else
          echo "Failed to parse: ${package_filename}" >&2
          exit 1
      fi

      echo "Downloading ${package_filename}"

      target_dir="${REPO_DIR}/${arch}"
      mkdir -p "${target_dir}"

      curl -sSfL "${AUTH_HEADER[@]}" -o "${target_dir}/${name}-${version}-r${epoch}.apk" "${package_url}"

    done

    total_downloaded_bytes="${potential_total_downloaded_bytes}"
  done

  page=$((page + 1))
done

echo ""
echo "No more releases available"
