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
            commits_range = os.environ.get('TRAVIS_COMMIT_RANGE', 'origin/master...HEAD')
            differ = Differ(commits_range)
            to_build = self._dep_tree.find_updated_images(differ.changed)

        for dst, base in to_build:
            encoded_dst = encode_tag(dst)
            encoded_base = encode_tag(base)
            img, tag = encoded_dst.split('.', 1)

            all_targets.add(encoded_dst)
            if encoded_base:
                # dont add the empty base
                all_targets.add(encoded_base)

            self._print_target(encoded_dst, encoded_base)

            build_script = path.join(img, 'build')
            if os.access(build_script, os.X_OK):
                self._print_command('cd {} && ./build {}'.format(img, tag))
            elif tag == 'latest':
                self._print_command('docker build -t {0} {1}/'.format(dst, img))
            else:
                self._print_command('docker build -t {0} -f {1}/Dockerfile.{2} {1}/'.format(dst, img, tag))

            if not is_cron or force_date_tag:
                if tag == 'latest':
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

def strip_prefix(s, prefix):
    if s.startswith(prefix):
        return s[len(prefix):]
    return s

def encode_tag(tag):
    return strip_prefix(tag, 'ustcmirror/').replace(':', '.')

def get_dest_image(img, f):
    n = path.basename(f)
    default_name = 'Dockerfile'
    if n == default_name:
        return 'ustcmirror/{}:latest'.format(img)
    else:
        tag = strip_prefix(n, default_name)[1:]
        return 'ustcmirror/{}:{}'.format(img, tag)

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
