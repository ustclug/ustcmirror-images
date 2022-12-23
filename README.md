# ustcmirror-images

[![Build Status](https://github.com/ustclug/ustcmirror-images/workflows/Build/badge.svg)](https://github.com/ustclug/ustcmirror-images/actions)

## Table Of Content

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
    - [crates-io-index](#crates-io-index)
    - [debian-cd](#debian-cd)
    - [docker-ce](#docker-ce)
    - [fedora](#fedora)
    - [freebsd-pkg](#freebsd-pkg)
    - [freebsd-ports](#freebsd-ports)
    - [ghcup](#ghcup)
    - [github-release](#github-release)
    - [gitsync](#gitsync)
    - [google-repo](#google-repo)
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

## Introduction

These images are designed for mirroring remote directories/repositories in a consistent and portable way. They are used by [ustcmirror (yuki)](https://github.com/ustclug/yuki).

## Quick Start

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

## Configuration

### Volumes

- `/data`: The mount point of the repository on the host. You can refer to it as environment variable `TO` in your program.
- `/log`: The mount point of the host directory that save logs. You can refer to it as environment variable `LOG` in your program.

### Common Configuration Parameters(AKA environment variables)

| Parameter          | Description                                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `DEBUG`            | Set this to `true` to enable debugging.                                                                                |
| `BIND_ADDRESS`     | Set the local ip to be bound. Require `--network=host`. (Some programs don't support this parameter)                   |
| `OWNER`            | Set the uid and gid of the process so that the downloaded files wont get messed up. Defaults to `0:0` (aka root:root). |
| `LOG_ROTATE_CYCLE` | Specify how many cycle versions of the logfile to be saved. Set this to `0` will disable rotation. Defaults to `0`.    |
| `REPO`             | Name of the repository. Required in `archvsync`.                                                                       |
| `RETRY`            | Times to re-sync if the process exits abnormally. Defaults to `0`.                                                     |

### aptsync

[![aptsync](https://img.shields.io/docker/image-size/ustcmirror/aptsync/latest)](https://hub.docker.com/r/ustcmirror/aptsync "aptsync")
[![aptsync](https://img.shields.io/docker/pulls/ustcmirror/aptsync)](https://hub.docker.com/r/ustcmirror/aptsync "aptsync")

| Parameter            | Description                                                                                               |
| -------------------- | --------------------------------------------------------------------------------------------------------- |
| `APTSYNC_URL`        | Sets the url of upstream.                                                                                 |
| `APTSYNC_NTHREADS`   | Defaults to `20`.                                                                                         |
| `APTSYNC_UNLINK`     | Set this to `1` to remove unneeded files automatically. Defaults to `0`.                                  |
| `APTSYNC_CREATE_DIR` | Set this to `true` to create same directory tree as upstream URL. Defaults to `true`.                     |
| `APTSYNC_DISTS`      | Various distros can be specified in the format `<release> [...]\|<componenet> [...]\|<arch> [...][:...]`. |

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

[![apt-sync](https://img.shields.io/docker/image-size/ustcmirror/apt-sync/latest)](https://hub.docker.com/r/ustcmirror/apt-sync "apt-sync")
[![apt-sync](https://img.shields.io/docker/pulls/ustcmirror/apt-sync)](https://hub.docker.com/r/ustcmirror/apt-sync "apt-sync")

| Parameter        | Description                                                                                                                     |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `APTSYNC_URL`    | Sets the url of upstream.                                                                                                       |
| `APTSYNC_UNLINK` | Set this to `1` to remove unneeded files automatically. Defaults to `0`.                                                        |
| `APTSYNC_DISTS`  | Various distros can be specified in the format `<release> [...]\|<componenet> [...]\|<arch> [...]\|<download_dir> [...][:...]`. |

It is almost the same as aptsync. Except that `APTSYNC_DISTS` accepts 4 parameters (rather than 3) for every item.

Consider use `apt-sync` when the upstream replaces packages in-place, as `aptsync` will simply ignore if there're any changes in existed packages.

### archvsync

[![archvsync](https://img.shields.io/docker/image-size/ustcmirror/archvsync/latest)](https://hub.docker.com/r/ustcmirror/archvsync "archvsync")
[![archvsync](https://img.shields.io/docker/pulls/ustcmirror/archvsync)](https://hub.docker.com/r/ustcmirror/archvsync "archvsync")

A.K.A. [ftpsync](https://anonscm.debian.org/cgit/mirror/archvsync.git/)

`archvsync` respects the env vars used in `ftpsync`

| Parameter     | Description                                    |
| ------------- | ---------------------------------------------- |
| `IGNORE_LOCK` | Purge lockfiles at first. Defaults to `false`. |

### crates-io-index

[![crates-io-index](https://img.shields.io/docker/image-size/ustcmirror/crates-io-index/latest)](https://hub.docker.com/r/ustcmirror/crates-io-index "crates-io-index")
[![crates-io-index](https://img.shields.io/docker/pulls/ustcmirror/crates-io-index)](https://hub.docker.com/r/ustcmirror/crates-io-index "crates-io-index")

A dedicated script to sync <https://github.com/rust-lang/crates.io-index>.

| Parameter        | Description                                                                                                |
| ---------------- | ---------------------------------------------------------------------------------------------------------- |
| `CRATES_PROXY`   | The URL that crates will be redirected to. Defaults to `https://crates-io.proxy.ustclug.org/api/v1/crates` |
| `CRATES_GITMSG`  | The commit message of `config.json`. Defaults to `Redirect to USTC Mirrors`                                |
| `CRATES_GITMAIL` | `user.email` when committing `config.json`. Defaults to `lug AT ustc.edu.cn`                               |
| `CRATES_GITNAME` | `user.name` when committing `config.json`. Defaults to `mirror`                                            |

### debian-cd

[![debian-cd](https://img.shields.io/docker/image-size/ustcmirror/debian-cd/latest)](https://hub.docker.com/r/ustcmirror/debian-cd "debian-cd")
[![debian-cd](https://img.shields.io/docker/pulls/ustcmirror/debian-cd)](https://hub.docker.com/r/ustcmirror/debian-cd "debian-cd")

`debian-cd` accepts the same parameters specified in `debian-cd-mirror.conf`

| Parameter     | Description                                    |
| ------------- | ---------------------------------------------- |
| `IGNORE_LOCK` | Purge lockfiles at first. Defaults to `false`. |

### docker-ce

[![docker-ce](https://img.shields.io/docker/image-size/ustcmirror/docker-ce/latest)](https://hub.docker.com/r/ustcmirror/docker-ce "docker-ce")
[![docker-ce](https://img.shields.io/docker/pulls/ustcmirror/docker-ce)](https://hub.docker.com/r/ustcmirror/docker-ce "docker-ce")

`docker-ce` accepts following parameters:

| Parameter         | Description                                                                              |
| ----------------- | ---------------------------------------------------------------------------------------- |
| `SYNC_WORKERS`    | Download workers. Defaults to 1.                                                         |
| `SYNC_USER_AGENT` | The user agent of `docker-ce` syncing program. Defaults to `Docker-ce Syncing Tool/1.0`. |
| `SYNC_EXTRA`      | Extra parameters. `--fast-skip` can be set to skip size & timestamp check.               |

### fedora

[![fedora](https://img.shields.io/docker/image-size/ustcmirror/fedora/latest)](https://hub.docker.com/r/ustcmirror/fedora "fedora")
[![fedora](https://img.shields.io/docker/pulls/ustcmirror/fedora)](https://hub.docker.com/r/ustcmirror/fedora "fedora")

[fedora-quick-mirror](https://pagure.io/quick-fedora-mirror)

See [dist conf](https://pagure.io/quick-fedora-mirror/blob/master/f/quick-fedora-mirror.conf.dist) for parameters meaning.

| Parameter          | Description                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------- |
| `MODULE`           | fedora module to be mirrored, e.g. fedora-enchilada,fedora-epel                                   |
| `FILTEREXP`        | A regular expression used to filter the file lists. It must be quoted (or very carefully escaped) |
| `VERBOSE`          | log level(0-8), default is 7                                                                      |
| `CHECKIN_SITE`     | see in mirrormanager                                                                              |
| `CHECKIN_PASSWORD` | see in mirrormanager                                                                              |
| `CHECKIN_HOST`     | see in mirrormanager                                                                              |

Note: This image is not in use now, as `quick-fedora-mirror` has some mysterious bugs when being used.

### freebsd-pkg

[![freebsd-pkg](https://img.shields.io/docker/image-size/ustcmirror/freebsd-pkg/latest)](https://hub.docker.com/r/ustcmirror/freebsd-pkg "freebsd-pkg")
[![freebsd-pkg](https://img.shields.io/docker/pulls/ustcmirror/freebsd-pkg)](https://hub.docker.com/r/ustcmirror/freebsd-pkg "freebsd-pkg")

| Parameter           | Description                                                      |
| ------------------- | ---------------------------------------------------------------- |
| `FBSD_PKG_UPSTREAM` | Set the URL of upstream. Defaults to `http://pkg.freebsd.org`.   |
| `FBSD_PKG_JOBS`     | Defaults to `1`.                                                 |
| `FBSD_PKG_EXCLUDE`  | Exclude ABI by regular expression. Defaults to `^FreeBSD:[89]:`. |

### freebsd-ports

[![freebsd-ports](https://img.shields.io/docker/image-size/ustcmirror/freebsd-ports/latest)](https://hub.docker.com/r/ustcmirror/freebsd-ports "freebsd-ports")
[![freebsd-ports](https://img.shields.io/docker/pulls/ustcmirror/freebsd-ports)](https://hub.docker.com/r/ustcmirror/freebsd-ports "freebsd-ports")

Notice: BIND_ADDRESS is only added for `curl` in freebsd-ports. Make sure that github.com is accessible under default network settings.

| Parameter                       | Description                                                                                    |
| ------------------------------- | ---------------------------------------------------------------------------------------------- |
| `FBSD_PORTS_INDEX_UPSTREAM`     | Set the URL of upstream git index. Defaults to `https://github.com/freebsd/freebsd-ports.git`. |
| `FBSD_PORTS_DISTFILES_UPSTREAM` | Set the URL of upstream distfiles. Defaults to `http://distcache.freebsd.org/ports-distfiles`. |
| `FBSD_PORTS_JOBS`               | Defaults to `1`.                                                                               |

### ghcup

[![ghcup](https://img.shields.io/docker/image-size/ustcmirror/ghcup/latest)](https://hub.docker.com/r/ustcmirror/ghcup "ghcup")
[![ghcup](https://img.shields.io/docker/pulls/ustcmirror/ghcup)](https://hub.docker.com/r/ustcmirror/ghcup "ghcup")

ghcup does not have outstanding configuration options. See also [stackage](#stackage) on replacing the Hackage repository.

### github-release

[![github-release](https://img.shields.io/docker/image-size/ustcmirror/github-release/latest)](https://hub.docker.com/r/ustcmirror/github-release "github-release")
[![github-release](https://img.shields.io/docker/pulls/ustcmirror/github-release)](https://hub.docker.com/r/ustcmirror/github-release "github-release")

| Parameter      | Description                                                                                        |
| -------------- | -------------------------------------------------------------------------------------------------- |
| `UPSTREAM_URL` | GitHub API base URL. Defaults to `https://api.github.com/repos/`.                                  |
| `WORKERS`      | Number of concurrent downloading jobs. Defaults to `8`.                                            |
| `FAST_SKIP`    | Not verify size and timestamp of existing files. Set it to any true string to enable the skipping. |
| `REPOS`        | YAML-format repo list config. See below for details.                                               |

To specified the repo list to sync, you can:

- Read-only bind mount a YAML file into the container at `/repos.yaml`. See the [example](github-release/examples/repos.yaml).
- Pass the YAML-format repo list string as `REPOS` env.

### gitsync

[![gitsync](https://img.shields.io/docker/image-size/ustcmirror/gitsync/latest)](https://hub.docker.com/r/ustcmirror/gitsync "gitsync")
[![gitsync](https://img.shields.io/docker/pulls/ustcmirror/gitsync)](https://hub.docker.com/r/ustcmirror/gitsync "gitsync")

| Parameter        | Description                                                                                                                               |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `GITSYNC_URL`    | Sets the url of upstream.                                                                                                                 |
| `GITSYNC_BRANCH` | Defaults to `master:master`.                                                                                                              |
| `GITSYNC_REMOTE` | Defaults to `origin`.                                                                                                                     |
| `GITSYNC_BITMAP` | Enable bitmap index. Defaults to `false`.                                                                                                 |
| `GITSYNC_MIRROR` | A shortcut to sync all branches and tags as if `GITSYNC_BRANCH='+refs/heads/*:refs/heads/*'`. `GITSYNC_BRANCH` is ignored when it is set. |

### google-repo

[![google-repo](https://img.shields.io/docker/image-size/ustcmirror/google-repo/latest)](https://hub.docker.com/r/ustcmirror/google-repo "google-repo")
[![google-repo](https://img.shields.io/docker/pulls/ustcmirror/google-repo)](https://hub.docker.com/r/ustcmirror/google-repo "google-repo")

A script for syncing projects (especially AOSP) using Google's `repo` tool.

| Parameter  | Description                                                                  |
| ---------- | ---------------------------------------------------------------------------- |
| `UPSTREAM` | Upstream URL. Defaults to `https://android.googlesource.com/mirror/manifest` |

### gsutil-rsync

[![gsutil-rsync](https://img.shields.io/docker/image-size/ustcmirror/gsutil-rsync/latest)](https://hub.docker.com/r/ustcmirror/gsutil-rsync "gsutil-rsync")
[![gsutil-rsync](https://img.shields.io/docker/pulls/ustcmirror/gsutil-rsync)](https://hub.docker.com/r/ustcmirror/gsutil-rsync "gsutil-rsync")

| Parameter    | Description                                    |
| ------------ | ---------------------------------------------- |
| `GS_URL`     | Sets the url of upstream. e.g. `gs://golang/`. |
| `GS_EXCLUDE` | Files to be excluded. Defaults to empty.       |

### hackage

[![hackage](https://img.shields.io/docker/image-size/ustcmirror/hackage/latest)](https://hub.docker.com/r/ustcmirror/hackage "hackage")
[![hackage](https://img.shields.io/docker/pulls/ustcmirror/hackage)](https://hub.docker.com/r/ustcmirror/hackage "hackage")

| Parameter          | Description                                                        |
| ------------------ | ------------------------------------------------------------------ |
| `HACKAGE_BASE_URL` | Set the URL of upstream. Defaults to `https://hackage.haskell.org` |

### homebrew-bottles

[![homebrew-bottles](https://img.shields.io/docker/image-size/ustcmirror/homebrew-bottles/latest)](https://hub.docker.com/r/ustcmirror/homebrew-bottles "homebrew-bottles")
[![homebrew-bottles](https://img.shields.io/docker/pulls/ustcmirror/homebrew-bottles)](https://hub.docker.com/r/ustcmirror/homebrew-bottles "homebrew-bottles")

| Parameter               | Description                         |
| ----------------------- | ----------------------------------- |
| `HOMEBREW_BOTTLES_JOBS` | Parallel jobs. Defaults to `1`      |
| `TARGET_OS`             | `mac` or `linux`. Defaults to `mac` |

### julia-storage

[![julia-storage](https://img.shields.io/docker/image-size/ustcmirror/julia-storage/latest)](https://hub.docker.com/r/ustcmirror/julia-storage "julia-storage")
[![julia-storage](https://img.shields.io/docker/pulls/ustcmirror/julia-storage)](https://hub.docker.com/r/ustcmirror/julia-storage "julia-storage")

A new solution to sync Julia general registry (using `StorageMirrorServer.jl`). No parameters needed.

### lftpsync

[![lftpsync](https://img.shields.io/docker/image-size/ustcmirror/lftpsync/latest)](https://hub.docker.com/r/ustcmirror/lftpsync "lftpsync")
[![lftpsync](https://img.shields.io/docker/pulls/ustcmirror/lftpsync)](https://hub.docker.com/r/ustcmirror/lftpsync "lftpsync")

| Parameter                 | Description                                                                                                                |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `LFTPSYNC_HOST`           | The hostname of the remote server.                                                                                         |
| `LFTPSYNC_PATH`           | The destination path on the remote server.                                                                                 |
| `LFTPSYNC_EXCLUDE`        | Files to be excluded. Defaults to `-X .~tmp~/`.                                                                            |
| `LFTPSYNC_JOBS`           | Defaults to `$(getconf _NPROCESSORS_ONLN)`.                                                                                |
| `LFTPSYNC_MIRROR_ARGS`    | Parameters for mirror command. Defaults to `--verbose --use-cache -aec`                                                    |
| `LFTPSYNC_EXTRA_COMMANDS` | Extra commands for lftp (ie. `set sftp:connect-program "ssh -axi <keyfile>";`). Will be executed before opening connection |

### nix-channels

[![nix-channels](https://img.shields.io/docker/image-size/ustcmirror/nix-channels/latest)](https://hub.docker.com/r/ustcmirror/nix-channels "nix-channels")
[![nix-channels](https://img.shields.io/docker/pulls/ustcmirror/nix-channels)](https://hub.docker.com/r/ustcmirror/nix-channels "nix-channels")

| Parameter                | Description                                                                                                                                                       |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NIX_MIRROR_UPSTREAM`    | Main page of Nix channels. No trailing slash. Defaults to [`https://nixos.org/channels`](https://nixos.org/channels)                                              |
| `NIX_MIRROR_BASE_URL`    | The root URL this mirror will be served at. No trailing slash. Defaults to [`https://mirrors.ustc.edu.cn/nix-channels`](https://mirrors.ustc.edu.cn/nix-channels) |
| `NIX_MIRROR_PATH_BATCH`  | Number of paths to pass to `nix` each time, to avoid `E2BIG`. Defaults to `8192`, which is about 1/4 of the 2M `ARG_MAX`.                                         |
| `NIX_MIRROR_THREADS`     | Number of threads to use to download in parallel. Defaults to 10                                                                                                  |
| `NIX_MIRROR_RETAIN_DAYS` | Days to consider old versions as reachable. Defaults to 30. (The newest version of a release is always reachable)                                                 |
| `NIX_MIRROR_DELETE_OLD`  | Whether to actually delete files in garbage collection. Set to `1` to delete and `0` to not delete. Defaults to `1`                                               |

### pypi

[![pypi](https://img.shields.io/docker/image-size/ustcmirror/pypi/latest)](https://hub.docker.com/r/ustcmirror/pypi "pypi")
[![pypi](https://img.shields.io/docker/pulls/ustcmirror/pypi)](https://hub.docker.com/r/ustcmirror/pypi "pypi")

| Parameter                    | Description         |
| ---------------------------- | ------------------- |
| `BANDERSNATCH_WORKERS`       | Defaults to `3`.    |
| `BANDERSNATCH_STOP_ON_ERROR` | Defaults to `true`. |
| `BANDERSNATCH_TIMEOUT`       | Defaults to `20`.   |

### rclone

[![rclone](https://img.shields.io/docker/image-size/ustcmirror/rclone/latest)](https://hub.docker.com/r/ustcmirror/rclone "rclone")
[![rclone](https://img.shields.io/docker/pulls/ustcmirror/rclone)](https://hub.docker.com/r/ustcmirror/rclone "rclone")

| Parameter                | Description                                                                        |
| ------------------------ | ---------------------------------------------------------------------------------- |
| `RCLONE_PATH`            | The destination path. Note that the rclone remote has been hard-coded as `remote`. |
| `RCLONE_EXTRA`           | Extra options passed to `rclone sync`. Defaults to empty.                          |
| `RCLONE_CHECKERS`        | Set the number of checkers. Defaults to `$(getconf _NPROCESSORS_ONLN)`.            |
| `RCLONE_TRANSFERS`       | Set the number of file transfers. Defaults to `$(getconf _NPROCESSORS_ONLN)`.      |
| `RCLONE_CONFIG_REMOTE_*` | Set config file options.                                                           |

ref:

- [rclone environment variables](https://rclone.org/docs/#environment-variables)
- [rclone-sync manual](https://rclone.org/commands/rclone_sync/)

### rsync

[![rsync](https://img.shields.io/docker/image-size/ustcmirror/rsync/latest)](https://hub.docker.com/r/ustcmirror/rsync "rsync")
[![rsync](https://img.shields.io/docker/pulls/ustcmirror/rsync)](https://hub.docker.com/r/ustcmirror/rsync "rsync")

| Parameter             | Description                                                      |
| --------------------- | ---------------------------------------------------------------- |
| `RSYNC_HOST`          | The hostname of the remote server.                               |
| `RSYNC_USER`          | (Optional) No defaults.                                          |
| `RSYNC_PASSWORD`      | (Optional) No defaults.                                          |
| `RSYNC_PATH`          | The destination path on the remote server.                       |
| `RSYNC_BW`            | Bandwidth limit. Defaults to `0`.                                |
| `RSYNC_EXTRA`         | Extra options. Defaults to empty.                                |
| `RSYNC_EXCLUDE`       | Files to be excluded. Defaults to `--exclude .~tmp~/`.           |
| `RSYNC_BLKSIZE`       | Defaults to `8192`.                                              |
| `RSYNC_TIMEOUT`       | Defaults to `14400`.                                             |
| `RSYNC_SPARSE`        | Defaults to `true`.                                              |
| `RSYNC_DELAY_UPDATES` | Defaults to `true`.                                              |
| `RSYNC_DELETE_DELAY`  | Defaults to `true`. Use `--delete-delay` rather than `--delete`  |
| `RSYNC_MAXDELETE`     | Maximum number of files that can be removed. Defaults to `4000`. |
| `RSYNC_RSH`           | Specify the remote shell, e.g. `ssh -i /path/to/key`.            |

### rubygems

[![rubygems](https://img.shields.io/docker/image-size/ustcmirror/rubygems/latest)](https://hub.docker.com/r/ustcmirror/rubygems "rubygems")
[![rubygems](https://img.shields.io/docker/pulls/ustcmirror/rubygems)](https://hub.docker.com/r/ustcmirror/rubygems "rubygems")

| Parameter  | Description                        |
| ---------- | ---------------------------------- |
| `UPSTREAM` | Defaults to `http://rubygems.org`. |

### stackage

[![stackage](https://img.shields.io/docker/image-size/ustcmirror/stackage/latest)](https://hub.docker.com/r/ustcmirror/stackage "stackage")
[![stackage](https://img.shields.io/docker/pulls/ustcmirror/stackage)](https://hub.docker.com/r/ustcmirror/stackage "stackage")

Stackage doesn't need to specify upstream, but this mirror use cabal to install necessary Haskell packages. Replacing default mirror of cabal with faster one will speed up building process.

Read the [user guide](https://www.haskell.org/cabal/users-guide/installing-packages.html#repository-specification) before writing preferred mirror to `config`

### yum-sync

[![yum-sync](https://img.shields.io/docker/image-size/ustcmirror/yum-sync/latest)](https://hub.docker.com/r/ustcmirror/yum-sync "yum-sync")
[![yum-sync](https://img.shields.io/docker/pulls/ustcmirror/yum-sync)](https://hub.docker.com/r/ustcmirror/yum-sync "yum-sync")

| Parameter                   | Description                                                                                                                           |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `YUMSYNC_URL`               | Sets the url of upstream.                                                                                                             |
| `YUMSYNC_DISTS`             | Various distros can be specified in the format `<release> [...]\|<component> [...]\|<arch> [...]\|<reponame>\|<download_dir> [:...]`. |
| `YUMSYNC_DOWNLOAD_REPODATA` | Whether to download repodata files instead of generating them by `createrepo`                                                         |

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

## License

Specially, contents of folder `apt-sync`, `yum-sync`, `github-release`, `docker-ce` and the generated container image from them are under GPLv3 license, as it uses code from <https://github.com/tuna/tunasync-scripts>.

Other contents are under MIT license.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
