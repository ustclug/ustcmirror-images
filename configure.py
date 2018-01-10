#!/usr/bin/python -O
# -*- coding: utf-8 -*-
from __future__ import print_function, unicode_literals, with_statement, division, absolute_import

import os
from os import path
import sys
import configparser
import subprocess
from datetime import datetime
from collections import defaultdict

class NaryTree():
    def __init__(self, name):
        self.name = name
        self._children = dict()

    def add_child(self, name, tree):
        self._children[name] = tree

    def get_child(self, name):
        return self._children.get(name, None)

    def find_updated_images(self, check):
        q = [self]
        while True:
            if not q:
                break
            t = q.pop(0)
            if not check(t.name):
                for c in t._children.values():
                    q.append(c)
            else:
                yield from t.enum_all(empty_parent=True)

    def enum_all(self, empty_parent=False):
        if empty_parent:
            yield (self.name, '')
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
        self._dep_tree = NaryTree('base')

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
        for derived in self._bases['base']:
            root.add_child(derived, NaryTree(derived))
        for base, derived in self._bases.items():
            if base == 'base':
                continue
            t = root.get_child(base)
            for i in derived:
                t.add_child(i, NaryTree(i))
        event_type = os.environ.get('TRAVIS_EVENT_TYPE', '')
        self._generate(build_all=event_type == 'cron')

    def _generate(self, build_all):
        all_targets = set()

        if build_all:
            to_build = self._dep_tree.enum_all(empty_parent=True)
        else:
            commits_range = os.environ.get('TRAVIS_COMMIT_RANGE', 'origin/master...HEAD')
            differ = Differ(commits_range)
            to_build = self._dep_tree.find_updated_images(differ.changed)

        for img, base in to_build:
            all_targets.add(img)
            all_targets.add(base)

            self._print_target(img, base)
            build_script = path.join(img, 'build.sh')
            if path.isfile(build_script) and os.access(build_script, os.X_OK):
                self._print_command('cd {} && ./build.sh'.format(img))
            else:
                self._print_command('docker build -t ustcmirror/{0}:latest --label ustcmirror.images {0}/'.format(img))
            if not build_all:
                if img == 'base':
                    self._print_command('@docker tag ustcmirror/base:alpine ustcmirror/base:alpine-{}'.format(self._now))
                    self._print_command('@docker tag ustcmirror/base:debian ustcmirror/base:debian-{}'.format(self._now))
                else:
                    self._print_command('@docker tag ustcmirror/{0}:latest ustcmirror/{0}:{1}'.format(img, self._now))
            self._print_command('@touch build/{}'.format(img))

        if '' in all_targets:
            all_targets.remove('')

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

def get_images(d):
    _, dirs, _ = next(os.walk(d))
    for d in dirs:
        if d.startswith('.') or d == 'build' or d == 'base':
            continue
        yield d

def main():
    here = os.getcwd()
    cfg_path = path.join(here, 'deps.ini')
    if not path.isfile(cfg_path):
        print('not a file: {}'.format(cfg_path))
        return 1

    # Dont catch the Exception
    os.makedirs('build', exist_ok=True)

    config = configparser.ConfigParser()
    config.read([cfg_path])
    if config.has_section('override'):
        override = config['override']
    else:
        print('`override` section is missing')
        return 1

    deps = {img: 'base' for img in get_images(here)}
    for k, v in override.items():
        if deps.get(k, None) is None:
            print('unknown image: {}', k)
            return 1
        deps[k] = v

    with Builder() as builder:
        for k, v in deps.items():
            builder.add(k, v)
        builder.finish()

if __name__ == '__main__':
    sys.exit(main())
