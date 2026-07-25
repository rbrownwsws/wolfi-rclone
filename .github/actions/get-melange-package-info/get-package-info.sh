#!/usr/bin/env bash
set -euo pipefail

warn() {
  echo "::warning file=${MELANGE_CONFIG_FILE}::$*" >&2
}

detect_distro() {
  # If distro has already been set just return that.
  if [[ -n "${PACKAGE_DISTRO:-}" ]]; then
    echo "${PACKAGE_DISTRO}"
    return 0
  fi

  local seen_wolfi=false
  local -A seen_alpine_versions=()

  local repos=()
  mapfile -t repos < <(yq ".environment.contents.repositories[]" "${MELANGE_CONFIG_FILE}")

  local repo
  for repo in "${repos[@]}"; do
    if [[ "${repo}" =~ packages\.wolfi\.dev ]]; then
      seen_wolfi=true
    elif [[ "${repo}" =~ /alpine/(v[0-9]+\.[0-9]+|edge)/ ]]; then
      seen_alpine_versions["${BASH_REMATCH[1]#v}"]=1
    fi
  done

  if ${seen_wolfi} && [[ "${#seen_alpine_versions[@]}" -gt 0 ]]; then
    warn "package references both wolfi and alpine repos - treating distro as unknown"
  fi

  if [[ "${#seen_alpine_versions[@]}" -gt 1 ]]; then
    warn "package references multiple alpine versions (${!seen_alpine_versions[*]}) — treating distro as unknown"
  fi

  if ${seen_wolfi} && [[ "${#seen_alpine_versions[@]}" -eq 0 ]]; then
    echo "wolfi"
    return 0
  elif ! ${seen_wolfi} && [[ "${#seen_alpine_versions[@]}" -eq 1 ]]; then
    local alpine_version
    for alpine_version in "${!seen_alpine_versions[@]}"; do break; done

    echo "alpine${alpine_version}"
    return 0
  else
    echo "unknown"
    return 0
  fi
}

PACKAGE_NAME=$(yq ".package.name" "${MELANGE_CONFIG_FILE}")
PACKAGE_VERSION=$(yq ".package.version" "${MELANGE_CONFIG_FILE}")
PACKAGE_EPOCH=$(yq ".package.epoch" "${MELANGE_CONFIG_FILE}")
PACKAGE_DISTRO=$(detect_distro)

echo "package-name=${PACKAGE_NAME}" >> "${GITHUB_OUTPUT}"
echo "package-version=${PACKAGE_VERSION}" >> "${GITHUB_OUTPUT}"
echo "package-epoch=${PACKAGE_EPOCH}" >> "${GITHUB_OUTPUT}"
echo "package-fullname=${PACKAGE_NAME}-${PACKAGE_VERSION}-r${PACKAGE_EPOCH}" >> "${GITHUB_OUTPUT}"
echo "package-fullversion=${PACKAGE_VERSION}-r${PACKAGE_EPOCH}" >> "${GITHUB_OUTPUT}"
echo "package-distro=${PACKAGE_DISTRO}" >> "${GITHUB_OUTPUT}"
