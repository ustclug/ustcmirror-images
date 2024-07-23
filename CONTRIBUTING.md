:+1::tada: 非常高兴您愿意花时间来改进这个项目，请接受我最为诚挚的感谢！ :tada::+1:

以下是您可能会感兴趣的内容：

* [如何增加新的同步方式？](#增加新的同步方式)
    * [约定](#约定)
* [整个项目是如何构建的？](#整个项目的构建过程)

## 增加新的同步方式

在项目根目录下新建一个文件夹，命名请参考下面的[约定](#约定)。文件夹中至少应该包含：

* `Dockerfile`
* `sync.sh`：需要被赋予可执行权限，并添加到根目录
* 其他需要用到的文件

`sync.sh` 中应该只包含同步的逻辑，如果您需要在同步前或同步后做一些额外的工作的话，可以分别添加 `pre-sync.sh` 或 `post-sync.sh` （均需要可执行权限）到根目录，它们都会以 `root` 的身份执行，而 `sync.sh` 在执行前可能会被降权，取决于 `$OWNER` 的值。可以参考 [pypi](pypi) 文件夹下的内容。

### 约定

* 如果同步方式具有普适性，建议命名为 `xx-sync`，比如 `rsync`，`gitsync` 等。
* 如果同步方式只适用于某一个特定的源，建议命名为那个源的名字，比如 `nodesource`，`stackage` 等。
* 任何同步方式对应的 image 都应该直接或间接地基于 `ustcmirror/base`。
* 如果您构建的镜像需要打上 `latest` 以外的 tag，请创建新的 `Dockerfile` 并把 tag 作为 `Dockerfile` 的后缀名。可以参考 [base](base) 以及 [lftpsync](lftpsync) 文件夹下的内容。
* 如果构建镜像前需要做额外的工作，您可以创建 `$your-sync-method/build` 来实现（需要可执行权限）。可以参考 [aptsync](aptsync)，[archvsync](archvsync) 文件夹下的内容。您的自定义构建程序应该 fail fast，如果是 Bash script 的话，请记得 `set -e`。构建时会以 `cd $your-sync-method/ && ./build $tag` 的方式来调用您的构建程序，如果需要构建多个镜像的话，可以根据第一个参数来决定构建哪一个。
* 同步程序应该读取环境变量作为参数，并且这些参数应该加上合适的前缀以示区分，比如 `RSYNC_HOST`，`GITSYNC_URL` 等。
* 同步程序应该把文件下载到 `$TO` 对应的目录下。
* 如果您的 `sync.sh` 最终只需要调用一个外部程序的话，应该以 `exec program` 的方式调用，方便接收 signal。
* 同步时产生的日志应该都输出到 `stdout` 或 `stderr`。
* 在不会过分麻烦您的前提下，请让构建出来的镜像尽可能小，构建的时间尽可能短。
* 如果 image 添加了对 `BIND_ADDRESS` 的支持，在 `Dockerfile` 中添加 `LABEL bind_support=true`（反之不需要）。

如果您对整个项目是如何构建的感兴趣的话，可以继续往下阅读。

## 整个项目的构建过程

执行 `./configure.py` 后会生成构建需要更新的镜像的 Makefile，接着执行 `make all` 进行构建。

生成 Makefile 的大概过程如下：

1. 枚举含有 `Dockerfile*` 的文件夹，根据 `Dockerfile` 的名字决定镜像的 tag
2. 分析 `Dockerfile` 提取依赖信息
3. 根据以上获取的依赖信息，构建一棵如下格式的 n 叉树：

```
$root$:
    base.alpine-3.6:
        lftpsync.alpine-3.6
    base.alpine:
        lftpsync.latest
        gitsync.latest:
            freebsd-ports.latest
        ...
    base.debian:
        stackage.latest
```

4. 对该树进行广度优先遍历，如果发现该结点对应的目录下的内容有改变的话（由 `git diff $TRAVIS_COMMIT_RANGE -- dir` 或 `git diff origin/master HEAD -- dir` 决定），就把该结点及其所有的子孙结点视为待构建的 targets，否则把其子结点加入到遍历队列。
5. 根据 targets 生成 Makefile
