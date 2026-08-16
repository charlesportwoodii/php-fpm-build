#!/usr/bin/env bash
# Start the Drone publish pipeline and wait for it to finish.
#
# Builds created through the Drone API carry the `custom` event type, which
# is what .drone.yml gates on. See:
#   https://docs.drone.io/api/builds/build_create/
#
# Requires DRONE_SERVER, DRONE_TOKEN, DRONE_REPO. Exits non-zero unless the
# build reaches `success`.
set -euo pipefail

: "${DRONE_SERVER:?DRONE_SERVER is required}"
: "${DRONE_TOKEN:?DRONE_TOKEN is required}"
: "${DRONE_REPO:?DRONE_REPO is required}"

BRANCH="${DRONE_BRANCH:-drone}"
POLL_SECONDS="${POLL_SECONDS:-15}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-1800}"

# Strip a trailing slash so the URLs below never double up.
DRONE_SERVER="${DRONE_SERVER%/}"

api() {
  curl --silent --show-error --fail-with-body \
    -H "Authorization: Bearer ${DRONE_TOKEN}" "$@"
}

json_field() {
  python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"
}

echo "Triggering Drone publish on ${DRONE_REPO} (${BRANCH})"
created=$(api -X POST \
  "${DRONE_SERVER}/api/repos/${DRONE_REPO}/builds?branch=${BRANCH}")

number=$(printf '%s' "$created" | json_field number)
echo "Drone build ${number}: ${DRONE_SERVER}/${DRONE_REPO}/${number}"

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
while :; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "Timed out after ${TIMEOUT_SECONDS}s waiting for build ${number}" >&2
    exit 1
  fi

  status=$(api "${DRONE_SERVER}/api/repos/${DRONE_REPO}/builds/${number}" \
    | json_field status)

  case "$status" in
    success)
      echo "Drone build ${number} succeeded"
      exit 0
      ;;
    failure|killed|error|declined|skipped)
      echo "Drone build ${number} finished with status: ${status}" >&2
      exit 1
      ;;
    *)
      echo "  status=${status}; waiting ${POLL_SECONDS}s"
      sleep "${POLL_SECONDS}"
      ;;
  esac
done
