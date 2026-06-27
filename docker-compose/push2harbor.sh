#!/usr/bin/env bash

set -euo pipefail

: "${HARBOR_URL:?Set HARBOR_URL, for example: harbor.example.com}"
: "${HARBOR_USERNAME:?Set HARBOR_USERNAME}"
: "${HARBOR_PASSWORD:?Set HARBOR_PASSWORD}"
: "${HARBOR_PROJECT:?Set HARBOR_PROJECT}"

IMAGE_FILTER="${IMAGE_FILTER:-bitnami}"

echo "${HARBOR_PASSWORD}" | docker login "${HARBOR_URL}" \
  --username "${HARBOR_USERNAME}" \
  --password-stdin

mapfile -t images < <(docker images --format "{{.Repository}}:{{.Tag}}" | grep "${IMAGE_FILTER}" || true)

if [[ ${#images[@]} -eq 0 ]]; then
  echo "No images matched filter: ${IMAGE_FILTER}"
  exit 0
fi

for image in "${images[@]}"; do
  repo="${image%:*}"
  tag="${image##*:}"
  harbor_image="${HARBOR_URL}/${HARBOR_PROJECT}/${repo}:${tag}"

  docker tag "${image}" "${harbor_image}"
  docker push "${harbor_image}"

  echo "Pushed ${image} to ${harbor_image}"
done

echo "All matching images were pushed to ${HARBOR_URL}/${HARBOR_PROJECT}."
