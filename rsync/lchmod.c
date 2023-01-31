#include <sys/stat.h>
#include <fcntl.h>

int lchmod(const char *path, mode_t mode) {
    struct stat st;

    int r = lstat(path, &st);
    if (r < 0) {
        return r;
    }

    if (S_ISLNK(st.st_mode)) {
        return 0;
    } else {
        return fchmodat(AT_FDCWD, path, mode, AT_SYMLINK_NOFOLLOW);
    }
}
