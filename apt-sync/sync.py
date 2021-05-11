#!/usr/bin/python3

import sys
import os
import subprocess


DEBUG = os.environ.get("DEBUG")
WORK_DIR = "/usr/local/lib/tunasync"

APTSYNC_URL = os.environ["APTSYNC_URL"]
APTSYNC_DISTS = os.environ["APTSYNC_DISTS"]
TO = os.environ["TO"]
DELETE = os.environ.get("APTSYNC_UNLINK", "")


os.chdir(WORK_DIR)

cmds = []
rets = []
for dist in APTSYNC_DISTS.split(":"):
    apt_dist, apt_comp, apt_arch, apt_dir = dist.strip().split("|")
    apt_arch = apt_arch.replace(" ", ",")
    apt_comp = apt_comp.replace(" ", ",")

    cmd = [sys.executable, "apt-sync.py"]
    if DELETE:
        cmd.append("--delete")

    cmd += [APTSYNC_URL + apt_dir, apt_dist, apt_comp, apt_arch, TO + "/" + apt_dir]
    cmds.append(cmd[:])
    cp = subprocess.run(cmd)
    rets.append(cp.returncode)

if DEBUG:
    for cmd, ret in zip(cmds, rets):
        print(f"CMD {cmd} = {ret}", file=sys.stderr)

sys.exit(sum(rets))
