# ustcmirror-images

- [Introduction](#introduction)
- [Configuration](#configuration)
    - [Volumes](#volumes)
    - [Common Configuration Parameters](#common-configuration-parameters)
    - [rsync](#rsync)
    - [lftpsync](#lftpsync)
    - [gitsync](#gitsync)

# Introduction

Docker images used by `ustcmirror`

# Configuration

### Volumes

* `/data`: The mount point of the repository on the host. `export TO=/data` in `entry.sh`.
* `/log`: The mount point of the host directory that save logs. `export LOGDIR=/log` in `entry.sh`.

### Common Configuration Parameters

| Parameter | Description |
|-----------|-------------|
| `DEBUG` | Set this to `true` to enable debugging |
| `BIND_ADDRESS` | The local ip to be bound |

### rsync

| Parameter | Description |
|-----------|-------------|
| `RSYNC_HOST` | The hostname of the remote server. |
| `RSYNC_USER` | (Optional) No defaults. |
| `RSYNC_PASSWORD` | (Optional) No defaults. |
| `RSYNC_PATH` | The destination path on the remote server. |
| `RSYNC_BW` | Bandwidth limit. Defaults to `0`. |
| `RSYNC_OPTIONS` | Extra options. Defaults to `-4pPrltvHSB8192 --partial-dir=.rsync-partial --timeout 14400 --delay-updates --safe-links --delete-delay --delete-excluded`. |
| `RSYNC_EXCLUDE` | Files to be excluded. Defaults to `--exclude .~tmp~/`. |
| `RSYNC_MAXDELETE` | Maximum number of files that can be removed. Defaults to `4000`. |

### lftpsync

| Parameter | Description |
|-----------|-------------|
| `LFTPSYNC_HOST` | The hostname of the remote server. |
| `LFTPSYNC_PATH` | The destination path on the remote server. |
| `LFTPSYNC_EXCLUDE` | Files to be excluded. Defaults to `-X .~tmp~/`. |
| `LFTPSYNC_JOBS` | Defaults to `$(getconf _NPROCESSORS_ONLN)`. |

### gitsync

| Parameter | Description |
|-----------|-------------|
| `GITSYNC_URL` | Sets the url of upstream |
| `GITSYNC_BRANCH` | Defaults to `master:master` |
| `GITSYNC_REMOTE` | Defaults to `origin` |
| `GITSYNC_BITMAP` | Enable bitmap index. Defaults to `false` |
