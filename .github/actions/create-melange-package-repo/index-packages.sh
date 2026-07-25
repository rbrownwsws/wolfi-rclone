#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(realpath "$REPO_DIR")

echo "Creating indexes for repo at ${REPO_DIR}"

# Get a temporary file to store the private signing key
SIGNING_KEY_FILE=$(mktemp --tmpdir="${RUNNER_TEMP}" --suffix=.rsa)

# Make sure we delete the private signing key file at the end of this step
trap 'rm -f "${SIGNING_KEY_FILE}"' EXIT

# Put the private signing key into a file
chmod 600 "${SIGNING_KEY_FILE}"
echo -n "${SIGNING_KEY}" > "${SIGNING_KEY_FILE}"

# Store the public signing key in the repo root
openssl rsa -in "${SIGNING_KEY_FILE}" -pubout -out "${REPO_DIR}/signing.rsa.pub"

for ARCH_DIR in "${REPO_DIR}"/*; do
  if [[ ! -d "${ARCH_DIR}" ]]; then
    continue
  fi

  ARCH=$(basename "${ARCH_DIR}")

  echo ""
  echo "Indexing arch '${ARCH}'..."
  melange index --signing-key="${SIGNING_KEY_FILE}" -o "${ARCH_DIR}/APKINDEX.tar.gz" "${ARCH_DIR}"/*.apk
done
