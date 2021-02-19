# ustcmirror-images

[![Build Status](https://github.com/ustclug/ustcmirror-images/workflows/Build/badge.svg)](https://github.com/ustclug/ustcmirror-images/actions)

# Table Of Content

- [ustcmirror-images](#ustcmirror-images)
- [Table Of Content](#table-of-content)
- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Volumes](#volumes)
    - [Common Configuration Parameters(AKA environment variables)](#common-configuration-parametersaka-environment-variables)
    - [aptsync](#aptsync)
    - [apt-sync](#apt-sync)
    - [archvsync](#archvsync)
    - [debian-cd](#debian-cd)
    - [fedora](#fedora)
    - [freebsd-pkg](#freebsd-pkg)
    - [freebsd-ports](#freebsd-ports)
    - [github-release](#github-release)
    - [gitsync](#gitsync)
    - [gsutil-rsync](#gsutil-rsync)
    - [hackage](#hackage)
    - [homebrew-bottles](#homebrew-bottles)
    - [julia](#julia)
    - [julia-storage](#julia-storage)
    - [lftpsync](#lftpsync)
    - [nix-channels](#nix-channels)
    - [nodesource](#nodesource)
    - [pypi](#pypi)
    - [rclone](#rclone)
    - [rsync](#rsync)
    - [rubygems](#rubygems)
    - [stackage](#stackage)
    - [yum-sync](#yum-sync)
- [License](#license)
- [Contributing](#contributing)

# Introduction

These images are designed for mirroring remote directories/repositories in a consistent and portable way. They are used by [ustcmirror (yuki)](https://github.com/ustclug/yuki).

# Quick Start

```sh
docker run --rm \
    -e LOG_ROTATE_CYCLE='5' \
    -e RSYNC_HOST='rsync.alpinelinux.org' \
    -e RSYNC_PATH='alpine/' \
    -e RSYNC_MAXDELETE='10000' \
    -v /var/repos/alpine:/data \
    -v /var/sync-logs/alpine:/log \
    ustcmirror/rsync:latest
```

# Configuration

### Volumes

* `/data`: The mount point of the repository on the host. You can refer to it as environment variable `TO` in your program.
* `/log`: The mount point of the host directory that save logs. You can refer to it as environment variable `LOG` in your program.

### Common Configuration Parameters(AKA environment variables)

| Parameter | Description |
|-----------|-------------|
| `DEBUG` | Set this to `true` to enable debugging. |
| `BIND_ADDRESS` | Set the local ip to be bound. Require `--network=host`. (Some programs don't support this parameter) |
| `OWNER` | Set the uid and gid of the process so that the downloaded files wont get messed up. Defaults to `0:0` (aka root:root). |
| `LOG_ROTATE_CYCLE` | Specify how many cycle versions of the logfile to be saved. Set this to `0` will disable rotation. Defaults to `0`. |
| `REPO` | Name of the repository. Required in `archvsync`. |
| `RETRY` | Times to re-sync if the process exits abnormally. Defaults to `0`. |

### aptsync

[![](https://images.microbadger.com/badges/image/ustcmirror/aptsync.svg)](https://microbadger.com/images/ustcmirror/aptsync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `APTSYNC_URL` | Sets the url of upstream. |
| `APTSYNC_NTHREADS` | Defaults to `20`. |
| `APTSYNC_UNLINK` | Set this to `1` to remove unneeded files automatically. Defaults to `0`. |
| `APTSYNC_CREATE_DIR` | Set this to `true` to create same directory tree as upstream URL. Defaults to `true`. |
| `APTSYNC_DISTS` | Various distros can be specified in the format `<release> [...]\|<componenet> [...]\|<arch> [...][:...]`. |

Notes: The following `mirror.list`:

```
deb-i386 https://apt.dockerproject.org/repo debian-jessie main
deb-amd64 https://apt.dockerproject.org/repo debian-jessie main
deb-armhf https://apt.dockerproject.org/repo raspbian-jessie main testing
```

is equivalent to the following parameters:

```
APTSYNC_URL='https://apt.dockerproject.org/repo'
APTSYNC_DISTS='debian-jessie|main|i386 amd64:raspbian-jessie|main testing|armhf'
```

### apt-sync

[![](https://images.microbadger.com/badges/image/ustcmirror/apt-sync.svg)](https://microbadger.com/images/ustcmirror/apt-sync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `APTSYNC_URL` | Sets the url of upstream. |
| `APTSYNC_UNLINK` | Set this to `1` to remove unneeded files automatically. Defaults to `0`. |
| `APTSYNC_DISTS` | Various distros can be specified in the format `<release> [...]\|<componenet> [...]\|<arch> [...]\|<download_dir> [...][:...]`. |

It is almost the same as aptsync. Except that `APTSYNC_DISTS` accepts 4 parameters (rather than 3) for every item.

Consider use `apt-sync` when the upstream replaces packages in-place, as `aptsync` will simply ignore if there're any changes in existed packages.

### archvsync

[![](https://images.microbadger.com/badges/image/ustcmirror/archvsync.svg)](https://microbadger.com/images/ustcmirror/archvsync "Get your own image badge on microbadger.com")

A.K.A. [ftpsync](https://anonscm.debian.org/cgit/mirror/archvsync.git/)

`archvsync` respects the env vars used in `ftpsync`

| Parameter | Description |
|-----------|-------------|
| `IGNORE_LOCK` | Purge lockfiles at first. Defaults to `false`. |

### debian-cd

[![](https://images.microbadger.com/badges/image/ustcmirror/debian-cd.svg)](https://microbadger.com/images/ustcmirror/debian-cd "Get your own image badge on microbadger.com")

`debian-cd` accepts the same parameters specified in `debian-cd-mirror.conf`

| Parameter | Description |
|-----------|-------------|
| `IGNORE_LOCK` | Purge lockfiles at first. Defaults to `false`. |

### fedora

[![](https://images.microbadger.com/badges/image/ustcmirror/fedora.svg)](https://microbadger.com/images/ustcmirror/fedora "Get your own image badge on microbadger.com")

[fedora-quick-mirror](https://pagure.io/quick-fedora-mirror)

See [dist conf](https://pagure.io/quick-fedora-mirror/blob/master/f/quick-fedora-mirror.conf.dist) for parameters meaning.

| Parameter | Description |
|-----------|-------------|
| `MODULE`    | fedora module to be mirrored, e.g. fedora-enchilada,fedora-epel |
| `FILTEREXP` | A regular expression used to filter the file lists. It must be quoted (or very carefully escaped) |
| `VERBOSE`   | log level(0-8), default is 7 |
| `CHECKIN_SITE`     | see in mirrormanager |
| `CHECKIN_PASSWORD` | see in mirrormanager |
| `CHECKIN_HOST`     | see in mirrormanager |

Note: This image is not in use now, as `quick-fedora-mirror` has some mysterious bugs when being used.

### freebsd-pkg

[![](https://images.microbadger.com/badges/image/ustcmirror/freebsd-pkg.svg)](https://microbadger.com/images/ustcmirror/freebsd-pkg "Get your own image badge on microbadger.com")

| Parameter           | Description                              |
| ------------------- | ---------------------------------------- |
| `FBSD_PKG_UPSTREAM` | Set the URL of upstream. Defaults to `http://pkg.freebsd.org`. |
| `FBSD_PKG_JOBS`     | Defaults to `1`.                         |
| `FBSD_PKG_EXCLUDE`  | Exclude ABI by regular expression. Defaults to `^FreeBSD:[89]:`. |

### freebsd-ports

[![](https://images.microbadger.com/badges/image/ustcmirror/freebsd-ports.svg)](https://microbadger.com/images/ustcmirror/freebsd-ports "Get your own image badge on microbadger.com")

Notice: BIND_ADDRESS is only added for `curl` in freebsd-ports. Make sure that github.com is accessible under default network settings.

| Parameter                       | Description                              |
| ------------------------------- | ---------------------------------------- |
| `FBSD_PORTS_INDEX_UPSTREAM`     | Set the URL of upstream git index. Defaults to `https://github.com/freebsd/freebsd-ports.git`. |
| `FBSD_PORTS_DISTFILES_UPSTREAM` | Set the URL of upstream distfiles. Defaults to `http://distcache.freebsd.org/ports-distfiles`. |
| `FBSD_PORTS_JOBS`               | Defaults to `1`.                         |

### github-release

[![](https://images.microbadger.com/badges/image/ustcmirror/github-release.svg)](https://microbadger.com/images/ustcmirror/github-release "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `UPSTREAM_URL` | GitHub API base URL. Defaults to `https://api.github.com/repos/`. |
| `WORKERS` | Number of concurrent downloading jobs. Defaults to `8`. |
| `FAST_SKIP` | Not verify size and timestamp of existing files. Set it to any true string to enable the skipping. |
| `REPOS` | YAML-format repo list config. See below for details. |

To specified the repo list to sync, you can:

- Read-only bind mount a YAML file into the container at `/repos.yaml`. See the [example](github-release/examples/repos.yaml).
- Pass the YAML-format repo list string as `REPOS` env.

### gitsync

[![](https://images.microbadger.com/badges/image/ustcmirror/gitsync.svg)](https://microbadger.com/images/ustcmirror/gitsync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `GITSYNC_URL` | Sets the url of upstream. |
| `GITSYNC_BRANCH` | Defaults to `master:master`. |
| `GITSYNC_REMOTE` | Defaults to `origin`. |
| `GITSYNC_BITMAP` | Enable bitmap index. Defaults to `false`. |

### gsutil-rsync

[![](https://images.microbadger.com/badges/image/ustcmirror/gsutil-rsync.svg)](https://microbadger.com/images/ustcmirror/gsutil-rsync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `GS_URL` | Sets the url of upstream. e.g. `gs://golang/`. |
| `GS_EXCLUDE` | Files to be excluded. Defaults to empty. |

### hackage

[![](https://images.microbadger.com/badges/image/ustcmirror/hackage.svg)](https://microbadger.com/images/ustcmirror/hackage "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `HACKAGE_BASE_URL` | Set the URL of upstream. Defaults to `https://hackage.haskell.org` |

### homebrew-bottles

[![](https://images.microbadger.com/badges/image/ustcmirror/homebrew-bottles.svg)](https://microbadger.com/images/ustcmirror/homebrew-bottles "Get your own image badge on microbadger.com")

| Parameter                | Description                              |
| ------------------------ | ---------------------------------------- |
| `HOMEBREW_BOTTLE_DOMAIN` | Set the URL of upstream. Defaults to `http://homebrew.bintray.com` |
| `HOMEBREW_REPO`          | Set the URL of core repo. Defaults to `git://github.com/homebrew/homebrew-core.git`  |
| `TARGET_OS`              | `mac` or `linux`. Defaults to `mac`      |

### julia

[![](https://images.microbadger.com/badges/image/ustcmirror/julia.svg)](https://microbadger.com/images/ustcmirror/julia "Get your own image badge on microbadger.com")

Sync from official site.  No parameters needed. (Deprecated)

### julia-storage

[![](https://images.microbadger.com/badges/image/ustcmirror/julia-storage.svg)](https://microbadger.com/images/ustcmirror/julia-storage "Get your own image badge on microbadger.com")

A new solution to sync Julia general registry (using `StorageMirrorServer.jl`). No parameters needed.

### lftpsync

[![](https://images.microbadger.com/badges/image/ustcmirror/lftpsync.svg)](https://microbadger.com/images/ustcmirror/lftpsync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `LFTPSYNC_HOST` | The hostname of the remote server. |
| `LFTPSYNC_PATH` | The destination path on the remote server. |
| `LFTPSYNC_EXCLUDE` | Files to be excluded. Defaults to `-X .~tmp~/`. |
| `LFTPSYNC_JOBS` | Defaults to `$(getconf _NPROCESSORS_ONLN)`. |

### nix-channels

[![](https://images.microbadger.com/badges/image/ustcmirror/nix-channels.svg)](https://microbadger.com/images/ustcmirror/nix-channels "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `NIX_MIRROR_UPSTREAM` | Main page of Nix channels. No trailing slash. Defaults to [`https://nixos.org/channels`](https://nixos.org/channels) |
| `NIX_MIRROR_BASE_URL` | The root URL this mirror will be served at. No trailing slash. Defaults to [`https://mirrors.ustc.edu.cn/nix-channels`](https://mirrors.ustc.edu.cn/nix-channels) |
| `NIX_MIRROR_PATH_BATCH` | Number of paths to pass to `nix` each time, to avoid `E2BIG`. Defaults to `8192`, which is about 1/4 of the 2M `ARG_MAX`. |
| `NIX_MIRROR_THREADS` | Number of threads to use to download in parallel. Defaults to 10 |
| `NIX_MIRROR_RETAIN_DAYS` | Days to consider old versions as reachable. Defaults to 30. (The newest version of a release is always reachable) |
| `NIX_MIRROR_DELETE_OLD` | Whether to actually delete files in garbage collection. Set to `1` to delete and `0` to not delete. Defaults to `1` |

### nodesource

[![](https://images.microbadger.com/badges/image/ustcmirror/nodesource.svg)](https://microbadger.com/images/ustcmirror/nodesource "Get your own image badge on microbadger.com")

Sync from official site. No parameter needed.

### pypi

[![](https://images.microbadger.com/badges/image/ustcmirror/pypi.svg)](https://microbadger.com/images/ustcmirror/pypi "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `BANDERSNATCH_WORKERS` | Defaults to `3`. |
| `BANDERSNATCH_STOP_ON_ERROR` | Defaults to `true`. |
| `BANDERSNATCH_TIMEOUT` | Defaults to `20`. |

### rclone

[![](https://images.microbadger.com/badges/image/ustcmirror/rclone.svg)](https://microbadger.com/images/ustcmirror/rclone "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `RCLONE_PATH` | The destination path. Note that the rclone remote has been hard-coded as `remote`. |
| `RCLONE_EXTRA` | Extra options passed to `rclone sync`. Defaults to empty. |
| `RCLONE_CHECKERS` | Set the number of checkers. Defaults to `$(getconf _NPROCESSORS_ONLN)`. |
| `RCLONE_TRANSFERS` | Set the number of file transfers. Defaults to `$(getconf _NPROCESSORS_ONLN)`. |
| `RCLONE_CONFIG_REMOTE_*` | Set config file options. |

ref:

* [rclone environment variables](https://rclone.org/docs/#environment-variables)
* [rclone-sync manual](https://rclone.org/commands/rclone_sync/)

### rsync

[![](https://images.microbadger.com/badges/image/ustcmirror/rsync.svg)](https://microbadger.com/images/ustcmirror/rsync "Get your own image badge on microbadger.com")

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

[![](https://images.microbadger.com/badges/image/ustcmirror/rsync.svg)](https://microbadger.com/images/ustcmirror/rsync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `UPSTREAM` | Defaults to `http://rubygems.org`. |

### stackage

[![](https://images.microbadger.com/badges/image/ustcmirror/stackage.svg)](https://microbadger.com/images/ustcmirror/stackage "Get your own image badge on microbadger.com")

Stackage doesn't need to specify upstream, but this mirror use cabal to install necessary Haskell packages. Replacing default mirror of cabal with faster one will speed up building process.

Read the [user guide](https://www.haskell.org/cabal/users-guide/installing-packages.html#repository-specification) before writing preferred mirror to `config`

### yum-sync

[![](https://images.microbadger.com/badges/image/ustcmirror/yum-sync.svg)](https://microbadger.com/images/ustcmirror/yum-sync "Get your own image badge on microbadger.com")

| Parameter | Description |
|-----------|-------------|
| `YUMSYNC_URL` | Sets the url of upstream. |
| `YUMSYNC_DISTS` | Various distros can be specified in the format `<release> [...]\|<component> [...]\|<arch> [...]\|<reponame>\|<download_dir> [:...]`. |
| `YUMSYNC_DOWNLOAD_REPODATA` | Whether to download repodata files instead of generating them by `createrepo` |

`yum-sync` tries to imitate the parameters of `aptsync`, and it supports the following substitution rule for `YUMSYNC_URL` and `<reponame>` & `<download_dir>` in `YUMSYNC_DISTS`:

- `@{arch}`: Architecture (x86_64, armhf, ...)
- `@{os_ver}`: OS version (6-8, ...)
- `@{comp}`: The `<component>` in `YUMSYNC_DISTS`

`yum-sync.py` is modified to get the same directory structure as upstream when syncing. And `<reponame>` should be named the same as the directory containing `repodata` dir.

Notes:

The following repo configuration:

```
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el$releasever-$basearch
```

translates to:

```
YUMSYNC_URL='https://packages.cloud.google.com/yum/repos/kubernetes-el@{os_ver}-@{arch}'
YUMSYNC_DISTS='6-7|kubernetes|x86_64,aarch64,armhfp,ppc64le,s390x|kubernetes-el@{os_ver}-@{arch}|/yum/repos/kubernetes-el@{os_ver}-@{arch}'
```

And the following:

```
[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=http://repo.mysql.com/yum/mysql-8.0-community/el/$releasever/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql

[mysql57-community]
name=MySQL 5.7 Community Server
baseurl=http://repo.mysql.com/yum/mysql-5.7-community/el/$releasever/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql
```

translates to:

```
YUMSYNC_URL='https://repo.mysql.com/yum/@{comp}/el/@{os_ver}/@{arch}/'
YUMSYNC_DISTS='6-8|mysql-8.0-community,mysql-5.7-community|aarch64,i386,x86_64|@{arch}|/yum/@{comp}/el/@{os_ver}/@{arch}/'
```

# License

Specially, contents of folder `apt-sync` and `yum-sync` and the generated container image from them are under GPLv3 license, as it uses code from <https://github.com/tuna/tunasync-scripts>.

Other contents are under MIT license.

# Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
