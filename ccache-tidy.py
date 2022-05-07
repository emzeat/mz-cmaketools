#!/usr/bin/env python3
"""
 ccache-tidy.py

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
import pathlib
import json
import os

# the ccache executable, override using the CCACHE env
CCACHE_ENV = 'CCACHE'
CCACHE = os.environ.get(CCACHE_ENV, 'ccache')
# the clang-tidy executable, override using the CLANG_TIDY env
CLANG_TIDY_ENV = 'CLANG_TIDY'
CLANG_TIDY = os.environ.get(CLANG_TIDY_ENV, 'clang-tidy')
# tracks the clang-tidy invocation arguments passed initially
CCACHE_TIDY_ARGS_ENV = 'CCACHE_TIDY_ARGS'
CCACHE_TIDY_ARGS = os.environ.get(CCACHE_TIDY_ARGS_ENV, None)
# tracks logging settings
CCACHE_TIDY_LOGFILE_ENV = 'CCACHE_TIDY_LOGFILE'
CCACHE_TIDY_LOGFILE = os.environ.get(CCACHE_TIDY_LOGFILE_ENV, None)
# tracks verbosity settings
CCACHE_TIDY_VERBOSE_ENV = 'CCACHE_TIDY_VERBOSE'
CCACHE_TIDY_VERBOSE = (CCACHE_TIDY_VERBOSE_ENV in os.environ) or (CCACHE_TIDY_LOGFILE is not None)
# the name by which self can be invoked
CCACHE_TIDY_SELF = sys.argv[0]


def log_info(msg: str) -> None:
    '''Helper to log a message'''
    sys.stderr.write(f'ccache-tidy: {msg}\n')
    if CCACHE_TIDY_LOGFILE:
        with open(CCACHE_TIDY_LOGFILE, 'a', encoding='utf8') as logfile:
            logfile.write(f'ccache-tidy: {msg}\n')


def log_debug(msg: str) -> None:
    '''Helper to log a debug message'''
    if CCACHE_TIDY_VERBOSE:
        log_info(msg)


def invoke_clang_tidy(with_args) -> int:
    '''Invokes clang-tidy using the given arguments'''

    def filter_clang_tidy(output) -> str:
        '''Filters the clang-tidy output

        This will drop useless messages like
            XXXX warnings generated.
        which will show for system headers even when these
        warnings have been ignored.
        '''
        return '\n'.join([line for line in output.split('\n') if 'warnings generated.' not in line])

    log_debug(f"Invoking {CLANG_TIDY} with args={with_args}")
    try:
        ct_output = subprocess.check_output([CLANG_TIDY] + with_args, stderr=subprocess.STDOUT, encoding='utf8')
        ct_output = filter_clang_tidy(ct_output)
        sys.stderr.write(ct_output)
        return 0
    except subprocess.CalledProcessError as error:
        log_info(f"clang-tidy failed: {error}")
        ct_output = error.output
        ct_output = filter_clang_tidy(ct_output)
        sys.stderr.write(ct_output)
        return error.returncode
    except FileNotFoundError as error:
        log_info(f"Failed to invoke clang-tidy: {error}")
        return 1


def invoke_ccache(with_args, with_env) -> int:
    '''Invokes ccache using the given arguments and env'''
    with_args = [CCACHE_TIDY_SELF] + with_args
    log_debug(f"Invoking {CCACHE} with args={with_args} env={with_env}")
    try:
        patched_env = os.environ.copy()
        patched_env.update(with_env)
        subprocess.check_call([CCACHE] + with_args, env=patched_env)
        return 0
    except subprocess.CalledProcessError as error:
        log_info(f"ccache failed: {error}")
        return error.returncode
    except FileNotFoundError as error:
        log_info(f"Failed to invoke ccache: {error}")
        return 1


def show_help() -> int:
    '''Prints a usage help for this and clang-tidy and quits'''
    print(f"""
        Wrapper to invoke clang-tidy through ccache to accelerate analysis as
        part of a regular compile job. Use as if running clang-tidy directly.

        Environment variables supported for configuration:
            {CLANG_TIDY_ENV}: Sets the clang-tidy executable.
            {CCACHE_ENV}: Sets the ccache executable.
            {CCACHE_TIDY_VERBOSE_ENV}: Enables debug messages.
            {CCACHE_TIDY_LOGFILE_ENV}: Logs to the given file (implies {CCACHE_TIDY_VERBOSE_ENV})
    """)
    return invoke_clang_tidy(['-h'])


# MAIN flow
log_debug(f"Invoked as {sys.argv}")

# if CCACHE_TIDY_ARGS_ENV was set we have been invoked through ccache
# and should simply run clang-tidy now
if CCACHE_TIDY_ARGS:
    fwd = json.loads(CCACHE_TIDY_ARGS)
    if '-E' in sys.argv:
        # ccache wants to get the preproc output
        sourcefile = pathlib.Path(fwd['sourcefile'])
        source = sourcefile.read_text(encoding='utf8')
        log_debug(f"Preprocessing '{sourcefile}':\n{source}")
        sys.stdout.write(source)
        sys.exit(0)
    else:
        # ccache is doing the actual run
        objectfile = pathlib.Path(fwd['objectfile'])
        ret = invoke_clang_tidy(fwd['args'])
        if ret == 0:
            objectfile.write_text('Success', encoding='utf8')
        sys.exit(ret)

# else determine the compile_db and any sources before running them through ccache
COMPILE_DB = None
sources = []
i = 1
while i < len(sys.argv):
    arg = sys.argv[i]
    if arg in ["-h", "--help"]:
        sys.exit(show_help())
    elif arg == "-p":
        # path to compiledb
        i += 1
        COMPILE_DB = pathlib.Path(sys.argv[i]) / 'compile_commands.json'
        if COMPILE_DB.exists():
            log_debug(f"Using compile database at {COMPILE_DB}")
        else:
            COMPILE_DB = None
    else:
        source = pathlib.Path(arg)
        if source.exists():
            # FIXME(zwicker): Handle multiple sources and a way to derive the object files
            sources = [source]
            log_debug(f"Handling source {source}")
    i += 1

if not sources:
    log_info("Missing source input file")
    sys.exit(1)

for sourcefile in sources:
    env = {}
    # forward the initial args to clang-tidy
    objectfile = sourcefile.with_suffix('.ccache-tidy')
    fwd_args = {
        'sourcefile': str(sourcefile),
        'objectfile': str(objectfile),
        'args': sys.argv[1:]
    }
    env[CCACHE_TIDY_ARGS_ENV] = json.dumps(fwd_args)

    # clang-tidy works like clang, force it
    env['CCACHE_COMPILERTYPE'] = 'clang'
    # ensure the compile db is considered
    if COMPILE_DB:
        extrafiles = os.environ.get('CCACHE_EXTRAFILES', None)
        SEP = ';' if sys.platform == 'win32' else ':'
        if extrafiles:
            extrafiles = extrafiles.split(SEP)
        else:
            extrafiles = []
        extrafiles.append(str(COMPILE_DB))
        env['CCACHE_EXTRAFILES'] = SEP.join(extrafiles)

    # ccache expects a regular compiler call here which is somewhat different
    # so we fake it and use a throw-away output. The actual arguments to clang-tidy
    # will be restored later when ccache is invoking us again in turn
    args = ['-c', '-o', objectfile, sourcefile]
    ret = invoke_ccache(args, env)

    # ccache forced us to generate an objectfile which we immediately remove again
    objectfile.unlink(missing_ok=True)

    # bail out on the first error
    if ret != 0:
        sys.exit(ret)

sys.exit(0)
