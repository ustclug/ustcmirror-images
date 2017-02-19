# ustcmirror-images

[![Build Status](https://travis-ci.org/ustclug/ustcmirror-images.svg?branch=master)](https://travis-ci.org/ustclug/ustcmirror-images)

- [Introduction](#introduction)
- [TODO](#todo)
- [Configuration](#configuration)
    - [Volumes](#volumes)
    - [Common Configuration Parameters](#common-configuration-parameters)
    - [rsync](#rsync)
    - [lftpsync](#lftpsync)
    - [gitsync](#gitsync)
- [Other Images](#other-images)
    - [MongoDB](#mongodb)

# Introduction

Docker images used by [ustcmirror](https://github.com/ustclug/ustcmirror)

# TODO

* [ ] Support ftpsync

# Configuration

### Volumes

* `/data`: The mount point of the repository on the host. `export TO=/data` in `entry.sh`.
* `/log`: The mount point of the host directory that save logs. `export LOGDIR=/log` in `entry.sh`.

### Common Configuration Parameters

| Parameter | Description |
|-----------|-------------|
| `DEBUG` | Set this to `true` to enable debugging. |
| `BIND_ADDRESS` | Set the local ip to be bound. |
| `OWNER` | Recommended to specify `$uid:$gid`. Defaults to `0:0`. |

### rsync

| Parameter | Description |
|-----------|-------------|
| `RSYNC_HOST` | The hostname of the remote server. |
| `RSYNC_USER` | (Optional) No defaults. |
| `RSYNC_PASSWORD` | (Optional) No defaults. |
| `RSYNC_PATH` | The destination path on the remote server. |
| `RSYNC_BW` | Bandwidth limit. Defaults to `0`. |
| `RSYNC_EXTRA_OPTS` | Extra options. Defaults to empty. |
| `RSYNC_EXCLUDE` | Files to be excluded. Defaults to `--exclude .~tmp~/`. |
| `RSYNC_BLKSIZE` | Defaults to `8192`. |
| `RSYNC_TIMEOUT` | Defaults to `14400`. |
| `RSYNC_DELAY_UPDATES` | Defaults to `true`. |
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
| `GITSYNC_URL` | Sets the url of upstream. |
| `GITSYNC_BRANCH` | Defaults to `master:master`. |
| `GITSYNC_REMOTE` | Defaults to `origin`. |
| `GITSYNC_BITMAP` | Enable bitmap index. Defaults to `false`. |

# Other Images

### MongoDB

| Parameter | Description |
|-----------|-------------|
| `MONGO_USER` | Sets the username of the db admin. Defaults to `mirror`. |
| `MONGO_PASS` | Sets the password. Defaults to `averylongpass`. |
| `MONGO_DB` | Sets the name of the db. Defaults to `mirror`. |
