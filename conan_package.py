#!/usr/bin/env python3
"""
 conan_package.py

 Copyright (c) 2022 - 2023 Marius Zwicker
 All rights reserved.

 SPDX-License-Identifier: Apache-2.0

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
"""

import argparse
import subprocess
from pathlib import Path
from shutil import rmtree
import os
import sys
import re


def discover_profile(cwd, name_expr):
    '''Helper to glob for the first matching directory or file'''
    for profile in cwd.glob(name_expr):
        return profile
    return None


# the name by which conan can be invoked
CONAN = 'conan'
# the name by which cmake can be invoked
CMAKE = 'cmake'
# the remote to which packages get uploaded
REMOTE = os.environ.get('MZ_CONAN_REMOTE_NAME', 'emzeat')
# tracks verbosity settings
VERBOSE_ENV = 'VERBOSE'
VERBOSE = os.environ.get(VERBOSE_ENV, False)
# working directory assuming this gets invoked from within ./build
DEFAULT_WKDIR = Path(__file__).parent.parent
# default recipe
DEFAULT_RECIPE = DEFAULT_WKDIR / 'conanfile.py'
# default channel name
DEFAULT_CHANNEL = 'emzeat/oss'
# default host profile
DEFAULT_PROFILE = discover_profile(DEFAULT_WKDIR / 'build', '*/profile.conan')
# default build profile
DEFAULT_BUILD_PROFILE = discover_profile(DEFAULT_WKDIR / 'build', '*/build_profile.conan')
# default directory to test in
DEFAULT_TEST_DIR = DEFAULT_PROFILE.parent / 'conan_package' if DEFAULT_PROFILE else None


def log_fatal(msg: str) -> None:
    '''Helper to log a message and abort'''
    log_info('!! ' + msg)
    sys.exit(1)


def log_info(msg: str) -> None:
    '''Helper to log a message'''
    sys.stderr.write(f'conan-package: {msg}\n')


def log_debug(msg: str) -> None:
    '''Helper to log a debug message'''
    if VERBOSE:
        log_info(msg)


def invoke_conan(with_args, cwd=DEFAULT_WKDIR, failure_ok=False) -> None:
    '''Invokes conan using the given arguments'''

    with_args = [str(arg) for arg in with_args]
    log_debug(f"Invoking {CONAN} with args={with_args} cwd={cwd}")
    try:
        subprocess.check_call([CONAN] + with_args, encoding='utf8', cwd=cwd, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as error:
        if failure_ok:
            log_info(f"conan failed but not fatal: {error}")
        else:
            log_fatal(f"conan failed: {error}")
    except FileNotFoundError as error:
        log_fatal(f"Failed to invoke conan: {error}")


def invoke_cmake(with_args, cwd=DEFAULT_WKDIR) -> None:
    '''Invokes cmake using the given arguments'''

    log_debug(f"Invoking {CMAKE} with args={with_args} cwd={cwd}")
    try:
        subprocess.check_call([CMAKE] + with_args, encoding='utf8', cwd=cwd, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as error:
        log_fatal(f"cmake failed: {error}")
    except FileNotFoundError as error:
        log_fatal(f"Failed to invoke cmake: {error}")


parser = argparse.ArgumentParser(description='Helper to test and deploy conan packages')
parser.add_argument('--test', default=False, help='Test the conan recipe step-by-step', action='store_true')
parser.add_argument('--create', default=False,
                    help='Create the conan package including a build for the given profile.', action='store_true')
parser.add_argument('--build', default=False,
                    help='Create a build for the given profile using the previously created package.', action='store_true')
parser.add_argument('--upload', default=False, help='Upload the conan package', action='store_true')
parser.add_argument('--verbose', default=VERBOSE, help='Enable verbose logging', action='store_true')
parser.add_argument('--recipe', default=DEFAULT_RECIPE,
                    help=f'Specifies conan recipe to be processed Default: {DEFAULT_RECIPE}', type=Path)
parser.add_argument('--profile', default=DEFAULT_PROFILE,
                    help=f'Configures the conan profile to be used. Default: {DEFAULT_PROFILE}', type=Path)
parser.add_argument('--build-profile', default=DEFAULT_BUILD_PROFILE,
                    help=f'Configures the conan build profile to be used for cross building. Default: {DEFAULT_BUILD_PROFILE}', type=Path)
parser.add_argument('-o', '--option', default=[], nargs='*',
                    help="Override an option in the conan recipe ot be processed, e.g. backend_qt5=False")
parser.add_argument('--test-dir', default=DEFAULT_TEST_DIR,
                    help=f'Specifies the directory to test the package in. Default: {DEFAULT_TEST_DIR}', type=Path)
parser.add_argument('--version', default=None,
                    help='Specifies the version which will be parsed from git elsewise.', type=str)
args = parser.parse_args()

VERBOSE = args.verbose
if args.recipe.exists():
    log_info(f"Processing '{args.recipe}'")
else:
    log_fatal(f"No such recipe: {args.recipe}")

rmtree(args.test_dir, ignore_errors=True)
args.test_dir.mkdir(parents=True, exist_ok=True)
log_debug(f"Testing below '{args.test_dir}'")

name = re.search(r'name\s*=\s*[\'"]([^\'"]+)', args.recipe.read_text(), re.MULTILINE)
if name:
    args.name = name.group(1)
else:
    log_fatal("Failed to match name from recipe")
log_info(f"Package name '{args.name}'")

if args.version is None:
    version_txt = args.test_dir / 'version.txt'
    invoke_cmake([f'-DMZ_SEMVER_TO_FILE={version_txt}', '-P', 'build/semver.cmake'])
    args.version = version_txt.read_text().strip()
log_info(f"Package version '{args.version}'")

if args.build_profile:
    options = ['-pr:h', args.profile, '-pr:b', args.build_profile]
else:
    options = ['-pr', args.profile]
for opt in args.option:
    options += ['-o:h' if args.build_profile else '-o', opt]

if args.test:
    source_dir = args.test_dir / 'source'
    source_dir.mkdir(parents=True, exist_ok=True)
    build_dir = args.test_dir / 'build'
    build_dir.mkdir(parents=True, exist_ok=True)
    install_dir = args.test_dir / 'install'
    install_dir.mkdir(parents=True, exist_ok=True)
    package_dir = args.test_dir / 'package'
    package_dir.mkdir(parents=True, exist_ok=True)
    invoke_conan(['source', '-sf', source_dir, args.recipe])
    invoke_conan(['install', '-if', install_dir] + options + [args.recipe])
    invoke_conan(['build', '-bf', build_dir, '-if', install_dir, '-pf', package_dir, '-sf', source_dir, args.recipe])
    invoke_conan(['package', '-bf', build_dir, '-if', install_dir, '-pf', package_dir, '-sf', source_dir, args.recipe])

elif args.create:
    reference = f'{args.name}/{args.version}@{DEFAULT_CHANNEL}'
    test_package = args.recipe.parent / 'test_package'
    if not test_package.exists():
        log_fatal(f"Missing 'test_package' dir at '{test_package}' - cannot verify recipe so aborting")

    log_info("Cleaning local cache")
    invoke_conan(['remove', '--force', reference], failure_ok=True)

    log_info(f"Creating package as '{reference}'")
    invoke_conan(['create', '-tbf', args.test_dir] + options + [args.recipe, reference])

    if args.upload:
        log_info(f"Uploading to '{REMOTE}'")
        invoke_conan(['upload', '-r', REMOTE, '--all', '--check', '--confirm', reference])

elif args.build:
    reference = f'{args.name}/{args.version}@{DEFAULT_CHANNEL}'
    out_dir = args.test_dir / 'out'
    out_dir.mkdir(parents=True, exist_ok=True)
    install_dir = args.test_dir / 'install'
    install_dir.mkdir(parents=True, exist_ok=True)

    log_info("Cleaning local cache")
    invoke_conan(['remove', '--force', reference], failure_ok=True)

    log_info(f"Building package '{reference}'")
    invoke_conan(['install', '-if', install_dir, '-of', out_dir] + options + ['-b', args.name, reference])

    if args.upload:
        log_info(f"Uploading to '{REMOTE}'")
        invoke_conan(['upload', '-r', REMOTE, '--all', '--check', '--confirm', reference])

else:
    log_fatal("Please pass --test, --create or --build")
