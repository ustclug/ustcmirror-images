#!/usr/bin/python -O
# -*- coding: utf-8 -*-
import os
from os import path
import sys
import glob
import subprocess
from datetime import datetime
from collections import defaultdict


def invoke(cmd, fail_fast=False):
    from subprocess import call, DEVNULL
    if fail_fast:
        ret = call(cmd, stdout=DEVNULL)
        if ret != 0:
            sys.exit(ret)
    else:
        ret = call(cmd, stdout=DEVNULL, stderr=DEVNULL)
    return ret


class InvalidFrom(Exception):
    pass


class NoBaseImage(Exception):
    pass


class Git():
    @staticmethod
    def is_invalid_commit(desc):
        return invoke(['git', 'cat-file', '-e', desc]) != 0

    @staticmethod
    def branch_exists(branch):
        return invoke(['git', 'rev-parse', '--verify', branch]) == 0

    @staticmethod
    def fetch_master_branch():
        invoke([
            'git', 'config', 'remote.origin.fetch',
            '+refs/heads/*:refs/remotes/origin/*'
        ])
        invoke(['git', 'fetch', 'origin', 'master:master'], fail_fast=True)

    @staticmethod
    def is_current_branch(branch):
        return subprocess.getoutput('git symbolic-ref --short HEAD') == branch


class NaryTree():
    """
    A n-ary tree
    """

    def __init__(self, name):
        self.name = name
        self._children = dict()

    def add_child(self, name):
        self._children[name] = NaryTree(name)

    def get_child(self, name):
        return self._children.get(name, None)

    def find_updated_images(self, check):
        q = list(self._children.values())
        while True:
            if not q:
                break
            t = q.pop(0)
            encoded = encode_tag(t.name)
            img = encoded.split('.')[0]
            if not check(img):
                q.extend(t._children.values())
            else:
                yield (t.name, self.name)
                yield from t.enum_all()

    def enum_all(self):
        """
        Enumerate all derived images and images based on the derived images
        """
        for c in self._children.keys():
            yield (c, self.name)
        for c in self._children.values():
            yield from c.enum_all()

    def print(self):
        self._print(0)

    def _print(self, lvl):
        print(' ' * lvl, end='')
        print(self.name)
        for v in self._children.values():
            v._print(lvl + 4)


class Differ():
    def __init__(self, prev, now):
        self._prev = prev
        self._now = now

    def changed(self, img):
        return invoke(
            ['git', 'diff', '--quiet', self._prev, self._now, '--', img]) != 0


class Builder():
    def __init__(self):
        self._targets = {}
        self._now = datetime.today().strftime('%Y%m%d')
        self._bases = defaultdict(list)
        self._dep_tree = NaryTree('')

    def __enter__(self):
        self._fout = open('Makefile', 'w')
        self._fout.write('.PHONY: all\r\n')
        return self

    def __exit__(self, *args):
        self._fout.close()

    def add(self, img, base):
        self._bases[base].append(img)

    def finish(self):
        root = self._dep_tree
        self._build_tree(root)
        is_cron = os.environ.get('GITHUB_EVENT', '') == 'schedule'
        date_tag = os.environ.get('DATE_TAG', '') != ''
        self._generate(is_cron=is_cron, force_date_tag=date_tag)

    def _build_tree(self, root):
        for derived in self._bases[root.name]:
            root.add_child(derived)
            if derived in self._bases:
                sub = root.get_child(derived)
                self._build_tree(sub)

    def _generate(self, *, is_cron, force_date_tag):
        all_targets = set()

        if is_cron:
            to_build = self._dep_tree.enum_all()
        else:
            # TRAVIS_COMMIT_RANGE is empty for builds
            # triggered by the initial commit of a new branch.
            commits_range = os.environ.get('TRAVIS_COMMIT_RANGE', '')
            print('TRAVIS_COMMIT_RANGE: {}'.format(commits_range))
            if not commits_range:
                # GitHub Actions ($COMMIT_FROM & $COMMIT_TO)
                commit_from = os.environ.get('COMMIT_FROM', '')
                commit_to = os.environ.get('COMMIT_TO', '')
                if commit_from and commit_to:
                    commits_range = "{}...{}".format(commit_from, commit_to)
                else:
                    # git clone --branch <branch> on travis
                    # need to add master branch back
                    if not Git.branch_exists('master'):
                        print('fetching master branch...')
                        Git.fetch_master_branch()
                    commits_range = 'origin/master...HEAD'
            prev, current = commits_range.split('...')
            if Git.is_invalid_commit(prev):
                if Git.is_current_branch('master'):
                    # fallback
                    print('invalid commit: {}, fallback to <HEAD~5>'.format(
                        prev))
                    prev = 'HEAD~5'
                else:
                    prev = 'origin/master'
            print('prev: {}'.format(prev))
            print('current: {}'.format(current))
            differ = Differ(prev, current)
            to_build = self._dep_tree.find_updated_images(differ.changed)

        for dst, base in to_build:
            encoded_dst = encode_tag(dst)
            encoded_base = encode_tag(base)
            img, tag = encoded_dst.split('.', 1)

            all_targets.add(encoded_dst)
            all_targets.add(encoded_base)

            self._print_target(encoded_dst, encoded_base)

            build_script = path.join(img, 'build')
            if os.access(build_script, os.X_OK):
                self._print_command('cd {} && ./build {}'.format(img, tag))
            elif tag == 'latest':
                self._print_command('docker build -t {0} {1}/'.format(
                    dst, img))
            else:
                self._print_command(
                    'docker build -t {0} -f {1}/Dockerfile.{2} {1}/'.format(
                        dst, img, tag))

            if not is_cron or force_date_tag:
                if tag == 'latest':
                    self._print_command('@docker tag {0} {1}'.format(
                        dst, dst.replace('latest', self._now)))
                else:
                    self._print_command('@docker tag {0} {0}-{1}'.format(
                        dst, self._now))

        self._fout.write('all: {}\r\n'.format(' '.join(all_targets)))

    def _print_target(self, target, dep):
        self._fout.write('{}: {}\r\n'.format(target, dep))

    def _print_command(self, cmd):
        self._fout.write('\t' + cmd + '\r\n')


def strip_prefix(s, prefix):
    if s.startswith(prefix):
        return s[len(prefix):]
    return s


def encode_tag(tag):
    return strip_prefix(tag, 'ustcmirror/').replace(':', '.')


def get_dest_image(img, f):
    n = path.basename(f)
    # tag may contain a dot
    tag = strip_prefix(n, 'Dockerfile')
    if tag:
        return 'ustcmirror/{}:{}'.format(img, tag[1:])
    else:
        return 'ustcmirror/{}:latest'.format(img)


def get_base_image(f):
    with open(f) as fin:
        for l in fin:
            l = l.strip()
            if not l.startswith('FROM'):
                continue
            s = l.split()
            if len(s) != 2:
                raise InvalidFrom(f)
            tag = s[1]
            if ':' not in tag:
                return tag + ':latest'
            return tag
    raise NoBaseImage(f)


def find_all_images(d):
    root, dirs, _ = next(os.walk(d))
    imgs = {}
    for d in dirs:
        rule = path.join(root, d, 'Dockerfile*')
        files = glob.glob(rule)
        if not files:
            continue
        for f in files:
            dst_img = get_dest_image(d, f)
            base_img = get_base_image(f)
            imgs[dst_img] = base_img
    return imgs


def main():
    here = os.getcwd()

    imgs = find_all_images(here)

    with Builder() as b:
        for dst, base in imgs.items():
            if base.startswith('ustcmirror'):
                b.add(dst, base)
            else:
                b.add(dst, '')
        b.finish()

    return 0


if __name__ == '__main__':
    sys.exit(main())
