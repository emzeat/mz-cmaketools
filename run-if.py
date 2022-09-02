#!/usr/bin/env python3
"""
 run-if.py

 Copyright (c) 2022 Marius Zwicker
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

import subprocess
import sys
import argparse
from pathlib import Path
import os

# tracks logging settings
RUN_IF_LOGFILE_ENV = 'RUN_IF_LOGFILE'
RUN_IF_LOGFILE = os.environ.get(RUN_IF_LOGFILE_ENV, None)
# tracks verbosity settings
RUN_IF_VERBOSE_ENV = 'RUN_IF_VERBOSE'
RUN_IF_VERBOSE = (RUN_IF_VERBOSE_ENV in os.environ) or (RUN_IF_LOGFILE is not None)
# the name by which self can be invoked
RUN_IF_SELF = sys.argv[0]


def log_info(msg: str) -> None:
    '''Helper to log a message'''
    sys.stderr.write(f'run-if: {msg}\n')
    if RUN_IF_LOGFILE:
        with open(RUN_IF_LOGFILE, 'a', encoding='utf8') as logfile:
            logfile.write(f'run-if: {msg}\n')


def log_debug(msg: str) -> None:
    '''Helper to log a debug message'''
    if RUN_IF_VERBOSE:
        log_info(msg)


def is_file_unchanged(file: Path, reference: str) -> bool:
    '''Uses git to test if the given file has been changed'''

    if reference is None:
        log_info(f"Failed to test '{file.name}' for changes - No diff reference provided")
        sys.exit(1)

    if not file.exists():
        log_info(f"Failed to test '{file.name}' for changes - File does not exist")
        sys.exit(1)

    git_args = ['git', 'diff', reference, '--exit-code', str(file)]
    log_debug(f"Testing '{file.name}' for changes: {git_args}")
    try:
        subprocess.check_output(git_args, cwd=file.parent, stderr=subprocess.STDOUT, encoding='utf8')
        # exit code 0 means no changes
        return True
    except subprocess.CalledProcessError as error:
        if error.returncode == 1:
            # exit code 1 means changes
            return False
        # everything else implies an error during diff
        log_info(f"Failed to test '{file.name}' for changes: {error}\n\n{error.output}")
        sys.exit(1)
    except FileNotFoundError as error:
        log_info(f"Failed to test '{file.name}' for changes - Failed to invoke git: {error}")
        sys.exit(1)


def invoke(cmd: str, with_args, with_env: dict) -> int:
    '''Helper to invoke cmd with with_args patching with_env'''
    log_debug(f"Invoking {cmd} with args={with_args} env={with_env}")
    try:
        patched_env = os.environ.copy()
        patched_env.update(with_env)
        subprocess.check_call([cmd] + with_args, env=patched_env)
        return 0
    except subprocess.CalledProcessError as error:
        log_debug(f"{cmd} failed: {error}")
        return error.returncode
    except FileNotFoundError as error:
        log_info(f"Failed to invoke {cmd}: {error}")
        return 1


# MAIN flow
log_debug(f"Invoked as {sys.argv}")

parser = argparse.ArgumentParser(description='Utility to invoke a subprocess based on conditions')
parser.add_argument('--env', default=[], type=str,
                    help='Modifications to the environment used for invoking cmd.', action='append')
parser.add_argument('--diff', metavar='FILE:REFERENCE', default=None, type=str,
                    help='A file and git reference such as "origin/master" to diff against. The cmd will only be invoked when a change to file since the reference was detected.')
parser.add_argument('--touch', metavar='FILE', default=None, type=Path,
                    help='A file to touch upon successful completion of cmd. Parent paths must exist.')
parser.add_argument('cmd', metavar='CMD', type=str, help='The command to be invoked.', nargs=1)
parser.add_argument('args', metavar='ARGS', type=str,
                    help='Any command  arguments to be passed.', nargs=argparse.REMAINDER)
args = parser.parse_args()

skip_cmd = False  # pylint: disable=invalid-name
if args.diff:
    diff_file, diff_reference = args.diff.rsplit(':', maxsplit=1)
    diff_file = Path(diff_file).absolute()
    if is_file_unchanged(diff_file, diff_reference):
        log_debug(f"Skipping '{diff_file.name}' - no changes since {diff_reference}")
        skip_cmd = True  # pylint: disable=invalid-name

if skip_cmd:
    ret = 0  # pylint: disable=invalid-name

else:
    env = {}
    for var in args.env:
        key, value = var.split('=', maxsplit=1)
        env[key] = value
    ret = invoke(args.cmd[0], args.args, env)

if args.touch and ret == 0:
    args.touch.touch()
sys.exit(ret)
