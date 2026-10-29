# Remote ccache For ATS CI

This directory holds everything needed to run the shared ccache that
the Jenkins docker agents use for GitHub PR builds. The server is
[bazel-remote](https://github.com/buchgr/bazel-remote), an HTTP cache that
ccache can use as remote storage. It runs on `docker11`
(`72.167.32.163`), an agent that is out of Jenkins rotation.

## Why

Each agent has its own local ccache in `/home/jenkins/ccache`. Jenkins usually
sends a job back to the host it last ran on, but sharded jobs such as URTest,
and any job on a host it hasn't visited lately, start with a cache that has
none of their objects. A cold ATS build takes 17 to 21 minutes on these 4-core
hosts. With the remote cache, an object compiled on one agent is a hit on all
of them.

Measured on docker11 with the `ci-fedora-cxx20` preset, 1,426 compiles:

| Scenario | Compile time |
|---|---|
| Cold, no cache | 1031 s |
| Cold, writing to the remote cache | 1005 s |
| Warm local cache | 69 s |
| Warm remote cache, 1.5 ms RTT (agent to agent) | 71 s |
| Remote cache filled from master 3 commits later | 446 s (80% hits) |
| Remote cache filled from master 40 commits later | 584 s (71% hits) |

The network adds about 2 seconds to a full build. One full build adds about
220 MB to the cache.

## Clients

The pipelines opt in by setting:

```groovy
CCACHE_REMOTE_STORAGE = "http://72.167.32.163:9090|layout=bazel"
```

Currently that is `jenkins/github/urtest.pipeline`, `fedora.pipeline`, and
`debian.pipeline`. Those images ship ccache 4.12 (`fedora:44`) and 4.7
(`debian:12`).

`CCACHE_REMOTE_STORAGE` needs ccache 4.7 or newer. ccache 4.4 through 4.6 call
the same setting `CCACHE_SECONDARY_STORAGE` and silently ignore
`CCACHE_REMOTE_STORAGE`; `ubuntu:22.04` and `rockylinux:9` ship 4.5. The
`rockylinux:8`, `centos:7`, and `ubuntu:20.04` images ship ccache 3.7, which has
no remote storage support at all, so those pipelines don't set it.

The same pipelines set `CCACHE_STATSLOG` and print `ccache --show-log-stats -v`
after the Build stage. Its `Remote storage` section shows that build's remote
hits, misses, errors, and timeouts. A build that reaches no server looks like a
cold build otherwise.

Things to keep in mind when adding a client:

- **Paths must match across agents.** ATS builds use `-g`, so ccache hashes
  the working directory (`hash_dir`, on by default) because it ends up in the
  debug info. Jenkins gives a job the same workspace path on every agent
  (`/home/jenkins/workspace/Github_Builds/<job>`), and each agent has one
  executor, so there are no `@2` workspaces. Keep `CCACHE_BASEDIR` set to
  `${WORKSPACE}` and leave `hash_dir` on.
- **A different job name is a different cache.** Renaming a job changes its
  workspace path, so its first builds are cold.
- **Failures fall back to compiling.** If the server is down or unreachable,
  ccache counts a miss and compiles locally. A refused connection costs
  nothing. A dropped one costs ccache's 100 ms connect timeout per lookup,
  about a minute over a full build on 4 cores.

## Server

| Item | Value |
|---|---|
| Host | `docker11`, `72.167.32.163` |
| Port | `9090/tcp`, HTTP only (gRPC and the profiling endpoint are disabled) |
| Storage | `/var/lib/ccache-remote`, owned by the `ccache-remote` system user |
| Size limit | 60 GiB (`CACHE_MAX_SIZE_GIB`), LRU eviction by bazel-remote |
| Service | `ccache-remote.service`, which runs `docker-compose` in `/opt/ccache-remote` |
| Access control | ufw rules for the addresses in `config/allowed-clients.txt` |

bazel-remote has no authentication here. The container uses host networking so
that ufw decides who can connect: a published Docker port would be opened by
Docker's own iptables rules, which ufw does not see.

ccache's `max_size` only governs each agent's local cache. The remote cache is
bounded only by bazel-remote's `--max_size`, which evicts least recently used
entries. docker11 has about 100 GB free, so 60 GiB leaves room for Docker images
and logs.

## Install

On docker11:

```bash
git clone https://ci.trafficserver.apache.org/mirror/trafficserver-ci.git
cd trafficserver-ci
sudo ccache-remote/bin/install.sh
```

The script creates the system user and cache directory, installs this package
into `/opt/ccache-remote`, syncs the ufw rules for port 9090 with
`config/allowed-clients.txt`, and starts the service. It refuses to run unless
ufw is active and denies incoming connections by default, since ufw is the only
access control. The client list must contain bare IPv4 addresses.

It is safe to rerun after editing the client list. A rerun keeps the installed
size limit and storage path unless they are passed in. To change the size:

```bash
sudo CACHE_MAX_SIZE_GIB=80 ccache-remote/bin/install.sh
```

When an agent is added, renumbered, or retired, update
`config/allowed-clients.txt` and rerun the script.

## Operations

Status, including current and maximum size in bytes:

```bash
curl -s http://72.167.32.163:9090/status
```

That works from docker11 or any allowed agent. Service logs:

```bash
sudo journalctl -u ccache-remote
```

To see whether a build used the remote cache, look for the
`ccache --show-log-stats -v` output after the Build stage in its console log.

To empty the cache:

```bash
sudo systemctl stop ccache-remote
sudo find /var/lib/ccache-remote -mindepth 1 -delete
sudo systemctl start ccache-remote
```

## Rollback

Remove `CCACHE_REMOTE_STORAGE` from the pipelines. Builds then use only their
local caches. To also take down the server:

```bash
sudo systemctl disable --now ccache-remote
sudo ufw show added | grep ccache-remote   # lists each rule
sudo ufw delete allow from <addr> to any port 9090 proto tcp   # for each one
```
