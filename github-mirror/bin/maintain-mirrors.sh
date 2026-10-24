#!/usr/bin/env bash
# Nightly mirror maintenance: consolidate the per-fetch packs into one pack
# with a reachability bitmap and commit-graph, so git-upload-pack can serve
# clones by reusing the pack instead of re-enumerating and re-deltifying
# objects. Takes the same flock that update-mirror.sh uses, so it never
# repacks under a webhook fetch.
set -euo pipefail

MIRROR_ROOT=${MIRROR_ROOT:-/home/mirror}
LOCK_ROOT=${LOCK_ROOT:-${MIRROR_ROOT}/.locks}
LOCK_WAIT=${LOCK_WAIT:-900}
GIT=${GIT:-git}

for repo in trafficserver trafficserver-ci; do
  repo_dir="${MIRROR_ROOT}/${repo}.git"
  [ -d "${repo_dir}" ] || continue
  (
    exec 9>"${LOCK_ROOT}/${repo}.lock"
    flock -w "${LOCK_WAIT}" 9 || { echo "timed out waiting for ${repo} lock" >&2; exit 1; }
    echo "repacking ${repo_dir}" >&2
    # This one off-peak full repack can afford more threads and delta window
    # than the smart-http image allows each of its up to 16 concurrent
    # upload-packs (pack.threads 1, pack.windowMemory 64m). The fallback
    # container has no memory limit, and better deltas here shrink the single
    # pack that every clone then reuses.
    "${GIT}" --git-dir="${repo_dir}" -c pack.threads=2 -c pack.windowMemory=128m \
      repack -a -d -b
    "${GIT}" --git-dir="${repo_dir}" commit-graph write --reachable --split=replace
    "${GIT}" --git-dir="${repo_dir}" prune --expire=2.weeks.ago
  )
done
