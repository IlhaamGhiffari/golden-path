#!/usr/bin/env bash
set -euo pipefail

# bump-image.sh <image-sha>
# Updates the image tag in k8s/deployment.yaml and commits + pushes it.
# Runs from CI right after a successful image push — this commit is what
# ArgoCD detects and syncs (GitOps).
#
# Loop-safety: the commit message MUST contain [skip ci] so this bump commit
# never re-triggers the CI workflow (belt: path filter is site/**, suspenders:
# [skip ci]).

SHA="${1:?usage: bump-image.sh <image-sha>}"
FILE="k8s/deployment.yaml"
IMAGE="ghcr.io/ilhaamghiffari/golden-path:${SHA}"

# Replace the image line (either a :<sha> or :latest tag) with the new SHA
sed -i.bak -E "s#image: ghcr.io/ilhaamghiffari/golden-path:[0-9a-f]+#image: ${IMAGE}#; s#image: ghcr.io/ilhaamghiffari/golden-path:latest#image: ${IMAGE}#" "$FILE"
rm -f "$FILE.bak"

git add "$FILE"
git -c user.name="golden-path-bot" -c user.email="actions@github.com" \
  commit -m "chore: bump image to ${SHA} [skip ci]"
git push origin HEAD:main

echo "deployment.yaml now points to ${IMAGE}"
