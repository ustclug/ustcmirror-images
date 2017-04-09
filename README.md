# ustcmirror-images

[![Build Status](https://travis-ci.org/ustclug/ustcmirror-images.svg?branch=master)](https://travis-ci.org/ustclug/ustcmirror-images)

- [Introduction](#introduction)
- [Configuration](#configuration)
    - [Volumes](#volumes)
    - [Common Configuration Parameters](#common-configuration-parameters)
    - [aptsync](#aptsync)
    - [archvsync](#archvsync)
    - [gitsync](#gitsync)
    - [lftpsync](#lftpsync)
    - [rsync](#rsync)
    - [pypi](#pypi)
- [Other Images](#other-images)
    - [MongoDB](#mongodb)

# Introduction

Docker images used by [ustcmirror](https://github.com/ustclug/ustcmirror)

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
| `LOG_ROTATE_CYCLE` | Specify how many cycle versions of the logfile to be saved. Set this to `0` will disable rotation. Defaults to `0`. |
| `REPO` | Name of the repository. Required in `archvsync`. |

### aptsync

| Parameter | Description |
|-----------|-------------|
| `APTSYNC_URL` | Sets the url of upstream. |
| `APTSYNC_NTHREADS` | Defaults to `20`. |
| `APTSYNC_UNLINK` | Set this to `1` to remove unneeded files automatically. Defaults to `0`. |
| `APTSYNC_DISTS` | Various distros can be specified in the format `<release> [...]|<componenet> [...]|<arch> [...][:...]`. |

Notes: The following `mirror.list`:

```
deb-i386 https://apt.dockerproject.org/repo debian-jessie main
deb-amd64 https://apt.dockerproject.org/repo debian-jessie main
deb-armhf https://apt.dockerproject.org/repo raspbian-jessie main testing
```

is equivalent to the following `APTSYNC_DISTS`:

```
APTSYNC_DISTS='debian-jessie|main|i386 amd64:raspbian-jessie|main testing|armhf'
```

### archvsync

A.K.A. [ftpsync](https://anonscm.debian.org/cgit/mirror/archvsync.git/)

`archvsync` respects the env vars used in `ftpsync`

### gitsync

| Parameter | Description |
|-----------|-------------|
| `GITSYNC_URL` | Sets the url of upstream. |
| `GITSYNC_BRANCH` | Defaults to `master:master`. |
| `GITSYNC_REMOTE` | Defaults to `origin`. |
| `GITSYNC_BITMAP` | Enable bitmap index. Defaults to `false`. |

### lftpsync

| Parameter | Description |
|-----------|-------------|
| `LFTPSYNC_HOST` | The hostname of the remote server. |
| `LFTPSYNC_PATH` | The destination path on the remote server. |
| `LFTPSYNC_EXCLUDE` | Files to be excluded. Defaults to `-X .~tmp~/`. |
| `LFTPSYNC_JOBS` | Defaults to `$(getconf _NPROCESSORS_ONLN)`. |

### rsync

| Parameter | Description |
|-----------|-------------|
| `RSYNC_HOST` | The hostname of the remote server. |
| `RSYNC_USER` | (Optional) No defaults. |
| `RSYNC_PASSWORD` | (Optional) No defaults. |
| `RSYNC_PATH` | The destination path on the remote server. |
| `RSYNC_BW` | Bandwidth limit. Defaults to `0`. |
| `RSYNC_EXTRA` | Extra options. Defaults to empty. |
| `RSYNC_EXCLUDE` | Files to be excluded. Defaults to `--exclude .~tmp~/`. |
| `RSYNC_BLKSIZE` | Defaults to `8192`. |
| `RSYNC_TIMEOUT` | Defaults to `14400`. |
| `RSYNC_SPARSE` | Defaults to `true`. |
| `RSYNC_DELAY_UPDATES` | Defaults to `true`. |
| `RSYNC_MAXDELETE` | Maximum number of files that can be removed. Defaults to `4000`. |
| `RSYNC_REMOTE_SHELL` | Specify the remote shell, e.g. `ssh -i /path/to/key`. |

### pypi

| Parameter | Description |
|-----------|-------------|
| `BANDERSNATCH_WORKERS` | Defaults to `3`. |
| `BANDERSNATCH_STOP_ON_ERROR` | Defaults to `true`. |
| `BANDERSNATCH_TIMEOUT` | Defaults to `20`. |

# Other Images

### MongoDB

| Parameter | Description |
|-----------|-------------|
| `MONGO_USER` | Sets the username of the db admin. Defaults to `mirror`. |
| `MONGO_PASS` | Sets the password. Defaults to `averylongpass`. |
| `MONGO_DB` | Sets the name of the db. Defaults to `mirror`. |
