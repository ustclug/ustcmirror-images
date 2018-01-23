#!/usr/bin/python -O
# -*- coding: utf-8 -*-
from __future__ import print_function, unicode_literals, with_statement, division, absolute_import

import os
from os import path
import sys
import glob
import subprocess
from datetime import datetime
from collections import defaultdict

class InvalidFrom(Exception):
    pass

class NoBaseImage(Exception):
    pass

class NaryTree():
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
                for c in t._children.values():
                    q.append(c)
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
    def __init__(self, spec):
        prev, now = spec.split('...')
        self._prev = prev
        self._now = now

    def changed(self, img):
        return 0 != subprocess.call(['git', 'diff', '--quiet', self._prev, self._now, '--', img])


class Builder():
    def __init__(self):
        self._targets = {}
        self._now = datetime.today().strftime('%Y%m%d')
        self._bases = defaultdict(list)
        self._dep_tree = NaryTree('')

    def __enter__(self):
        self._fout = open('Makefile', 'w')
        self._fout.write('.PHONY: all clean\r\n')
        self._fout.write('export LABELS=--label ustcmirror.images --label org.ustcmirror.images=true\r\n')
        return self

    def __exit__(self, *args):
        self._fout.close()

    def add(self, img, base):
        self._bases[base].append(img)

    def finish(self):
        root = self._dep_tree
        self._build_tree(root)
        is_cron = os.environ.get('TRAVIS_EVENT_TYPE', '') == 'cron'
        date_tag = os.environ.get('DATE_TAG', '') != ''
        self._generate(build_all=is_cron, date_tag=date_tag)

    def _build_tree(self, root):
        for derived in self._bases[root.name]:
            root.add_child(derived)
            if derived in self._bases:
                sub = root.get_child(derived)
                self._build_tree(sub)

    def _generate(self, *, build_all, date_tag):
        all_targets = set()

        if build_all:
            to_build = self._dep_tree.enum_all()
        else:
            commits_range = os.environ.get('TRAVIS_COMMIT_RANGE', 'origin/master...HEAD')
            differ = Differ(commits_range)
            to_build = self._dep_tree.find_updated_images(differ.changed)

        for dst, base in to_build:
            encoded_dst = encode_tag(dst)
            encoded_base = encode_tag(base)
            img, tag = encoded_dst.split('.', 1)

            all_targets.add(encoded_dst)
            if encoded_base:
                all_targets.add(encoded_base)

            self._print_target(encoded_dst, encoded_base)
            build_script = path.join(img, 'build')
            if os.access(build_script, os.X_OK):
                self._print_command('cd {} && ./build {}'.format(img, tag))
            else:
                self._print_command('docker build -t {0} $$LABELS {1}/'.format(dst, img))
            if date_tag:
                if dst.endswith('latest'):
                    self._print_command('@docker tag {0} {1}'.format(dst, dst.replace('latest', self._now)))
                else:
                    self._print_command('@docker tag {0} {0}-{1}'.format(dst, self._now))
            self._print_command('@touch build/{}'.format(encoded_dst))

        prefixed = lambda s: 'build/{}'.format(s)
        self._fout.write('all: {}\r\n'.format(' '.join(map(prefixed, all_targets))))
        self._fout.write('clean:\r\n\trm -f build/*')

    def _print_target(self, target, dep):
        if dep:
            self._fout.write('build/{}: build/{}\r\n'.format(target, dep))
        else:
            self._fout.write('build/{}:\r\n'.format(target))

    def _print_command(self, cmd):
        self._fout.write('\t' + cmd + '\r\n')

def encode_tag(tag):
    if tag:
        return tag[len("ustcmirror/"):].replace(':', '.')
    return ''

def get_dest_image(img, f):
    with open(f) as fin:
        l = fin.readline().strip()

    if l.startswith('##! repo:tag='):
        spec = l.lstrip('##! repo:tag=')
        if ':' not in spec:
            return spec + ':latest'
        return spec
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

    # Dont catch the Exception
    os.makedirs('build', exist_ok=True)

    imgs = find_all_images(here)

    with Builder() as b:
        for dst, base in imgs.items():
            if base.startswith('ustcmirror'):
                b.add(dst, base)
            else:
                b.add(dst, '')
        b.finish()

if __name__ == '__main__':
    sys.exit(main())
