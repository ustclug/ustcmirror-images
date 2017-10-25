# ustcmirror-images

[![Build Status](https://travis-ci.org/ustclug/ustcmirror-images.svg?branch=master)](https://travis-ci.org/ustclug/ustcmirror-images)

- [Introduction](#introduction)
- [Configuration](#configuration)
    - [Volumes](#volumes)
    - [Common Configuration Parameters](#common-configuration-parameters)
    - [aptsync](#aptsync)
    - [archvsync](#archvsync)
    - [debian-cd](#debian-cd)
    - [gitsync](#gitsync)
    - [gsutil-rsync](#gsutil-rsync)
    - [hackage](#hackage)
    - [homebrew-bottles](#homebrew-bottles)
    - [lftpsync](#lftpsync)
    - [nodesource](#nodesource)
    - [pypi](#pypi)
    - [rsync](#rsync)
    - [rubygems](#rubygems)
    - [stackage](#stackage)

# Introduction

Docker images used by [ustcmirror](https://github.com/ustclug/ustcmirror)

# Configuration

### Volumes

* `/data`: The mount point of the repository on the host. `export TO=/data/` in the entrypoint.
* `/log`: The mount point of the host directory that save logs. `export LOGDIR=/log/` in the entrypoint.

### Common Configuration Parameters

| Parameter | Description |
|-----------|-------------|
| `DEBUG` | Set this to `true` to enable debugging. |
| `BIND_ADDRESS` | Set the local ip to be bound. Require `--network=host`. |
| `OWNER` | Set the uid and gid of the process so that the downloaded files wont get messed up. Defaults to `0:0` (aka root:root). |
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

| Parameter | Description |
|-----------|-------------|
| `IGNORE_LOCK` | Purge lockfiles at first. Defaults to `false`. |

### debian-cd

`debian-cd` accepts the same parameters specified in `debian-cd-mirror.conf`

| Parameter | Description |
|-----------|-------------|
| `IGNORE_LOCK` | Purge lockfiles at first. Defaults to `false`. |

### gitsync

| Parameter | Description |
|-----------|-------------|
| `GITSYNC_URL` | Sets the url of upstream. |
| `GITSYNC_BRANCH` | Defaults to `master:master`. |
| `GITSYNC_REMOTE` | Defaults to `origin`. |
| `GITSYNC_BITMAP` | Enable bitmap index. Defaults to `false`. |

### gsutil-rsync

| Parameter | Description |
|-----------|-------------|
| `GS_URL` | Sets the url of upstream. e.g. `gs://golang/`. |

### hackage

| Parameter | Description |
|-----------|-------------|
| `HACKAGE_BASE_URL` | Set the URL of upstream. Defaults to `https://hackage.haskell.org` |

### homebrew-bottles

| Parameter                | Description                              |
| ------------------------ | ---------------------------------------- |
| `HOMEBREW_BOTTLE_DOMAIN` | Set the URL of upstream. Defaults to `http://homebrew.bintray.com` |

### lftpsync

| Parameter | Description |
|-----------|-------------|
| `LFTPSYNC_HOST` | The hostname of the remote server. |
| `LFTPSYNC_PATH` | The destination path on the remote server. |
| `LFTPSYNC_EXCLUDE` | Files to be excluded. Defaults to `-X .~tmp~/`. |
| `LFTPSYNC_JOBS` | Defaults to `$(getconf _NPROCESSORS_ONLN)`. |

### nodesource

Sync from official site. No parameter needed.

### pypi

| Parameter | Description |
|-----------|-------------|
| `BANDERSNATCH_WORKERS` | Defaults to `3`. |
| `BANDERSNATCH_STOP_ON_ERROR` | Defaults to `true`. |
| `BANDERSNATCH_TIMEOUT` | Defaults to `20`. |

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
| `RSYNC_RSH` | Specify the remote shell, e.g. `ssh -i /path/to/key`. |

### rubygems

| Parameter | Description |
|-----------|-------------|
| `UPSTREAM` | Defaults to `http://rubygems.org`. |

### stackage

Stackage doesn't need to specify upstream, but this mirror use cabal to install necessary Haskell packages. Replacing default mirror of cabal with faster one will speed up building process.

Read the [user guide](https://www.haskell.org/cabal/users-guide/installing-packages.html#repository-specification) before writing preferred mirror to `config`
