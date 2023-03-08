#!/usr/bin/env python3
"""
 cache-tidy.py

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

import subprocess
import sys
from shutil import which
from pathlib import Path
import json
import os

# the ccache executable, override using the CCACHE env
CCACHE_ENV = 'CCACHE'
CCACHE = os.environ.get(CCACHE_ENV, None) or which('ccache')
# the clang-tidy executable, override using the CLANG_TIDY env
CLANG_TIDY_ENV = 'CLANG_TIDY'
CLANG_TIDY = os.environ.get(CLANG_TIDY_ENV, None) or which('clang-tidy')
# tracks the clang-tidy invocation arguments passed initially
CCACHE_TIDY_ARGS_ENV = 'CACHE_TIDY_ARGS'
CCACHE_TIDY_ARGS = os.environ.get(CCACHE_TIDY_ARGS_ENV, None)
# tracks logging settings
CCACHE_TIDY_LOGFILE_ENV = 'CACHE_TIDY_LOGFILE'
CCACHE_TIDY_LOGFILE = os.environ.get(CCACHE_TIDY_LOGFILE_ENV, None)
# tracks verbosity settings
CCACHE_TIDY_VERBOSE_ENV = 'CACHE_TIDY_VERBOSE'
CCACHE_TIDY_VERBOSE = (CCACHE_TIDY_VERBOSE_ENV in os.environ) or (CCACHE_TIDY_LOGFILE is not None)
# the name by which self can be invoked
CCACHE_TIDY_SELF = sys.argv[0]


def log_info(msg: str) -> None:
    '''Helper to log a message'''
    sys.stderr.write(f'cache-tidy: {msg}\n')
    if CCACHE_TIDY_LOGFILE:
        with open(CCACHE_TIDY_LOGFILE, 'a', encoding='utf8') as logfile:
            logfile.write(f'cache-tidy: {msg}\n')


def log_debug(msg: str) -> None:
    '''Helper to log a debug message'''
    if CCACHE_TIDY_VERBOSE:
        if CCACHE_TIDY_LOGFILE:
            with open(CCACHE_TIDY_LOGFILE, 'a', encoding='utf8') as logfile:
                logfile.write(f'cache-tidy: {msg}\n')
        else:
            log_info(msg)


def invoke_clang_tidy(with_args, capture_output=False) -> int:
    '''Invokes clang-tidy using the given arguments'''

    def filter_clang_tidy(output) -> str:
        '''Filters the clang-tidy output

        This will drop useless messages like
            XXXX warnings generated.
        which will show for system headers even when these
        warnings have been ignored.
        '''
        return '\n'.join([line for line in output.split('\n') if 'warnings generated.' not in line])

    if CLANG_TIDY is None:
        log_info("clang-tidy not found. Put on path or define CLANG_TIDY env variable")
        sys.exit(1)

    log_debug(f"Invoking {CLANG_TIDY} with args={with_args}")
    try:
        ct_output = subprocess.check_output([CLANG_TIDY] + with_args, stderr=subprocess.STDOUT, encoding='utf8')
        ct_output = filter_clang_tidy(ct_output)
        if capture_output:
            return 0, ct_output
        sys.stderr.write(ct_output)
        return 0
    except subprocess.CalledProcessError as error:
        log_debug(f"clang-tidy failed: {error}")
        ct_output = error.output
        ct_output = filter_clang_tidy(ct_output)
        if capture_output:
            return error.returncode, ct_output
        sys.stderr.write(ct_output)
        return error.returncode
    except FileNotFoundError as error:
        log_info(f"Failed to invoke clang-tidy: {error}")
        return 1


def invoke_ccache(with_args, with_env) -> int:
    '''Invokes ccache using the given arguments and env'''

    if CCACHE is None:
        log_info("ccache not found. Put on path or define CCACHE env variable")
        sys.exit(1)

    with_args = [CCACHE_TIDY_SELF] + with_args
    log_debug(f"Invoking {CCACHE} with args={with_args} env={with_env}")
    try:
        patched_env = os.environ.copy()
        patched_env.update(with_env)
        patched_env['CCACHE_PREFIX'] = sys.executable
        subprocess.check_call([CCACHE] + with_args, env=patched_env)
        return 0
    except subprocess.CalledProcessError as error:
        log_debug(f"ccache failed: {error}")
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

        Special flags supported to override configuration:
            --cache-tidy-o=<location of a stamp file to be touched on success>
            --cache-tidy-{CCACHE_ENV}=<location of the ccache executable>
            --cache-tidy-{CLANG_TIDY_ENV}=<location of the clang-tidy executable>
    """)
    return invoke_clang_tidy(['-h'])


def parse_arguments(argv=None):
    '''Parses the arguments to determine the compile path and sources'''
    if argv is None:
        argv = sys.argv

    class Args:
        '''Describes consumed arguments'''

        def __init__(self):
            self.help = False
            self.compdb = None
            self.sources = []
            self.tidyargs = []
            self.objectfile = None

        def __str__(self):
            return str(dict(help=self.help, compdb=self.compdb, sources=self.sources, tidyargs=self.tidyargs))

    parsed_args = Args()
    i = 1
    while i < len(sys.argv):
        arg = sys.argv[i]
        parsed_args.tidyargs.append(arg)
        if arg in ["-h", "--help"]:
            parsed_args.help = True
            break
        if arg == "-p":
            # path to compile db
            i += 1
            parsed_args.tidyargs.append(sys.argv[i])
            candidate = Path(sys.argv[i]) / 'compile_commands.json'
            if candidate.exists():
                parsed_args.compdb = candidate
        elif arg.startswith("-p="):
            # path to compile db
            candidate = Path(arg.split('=')[1]) / 'compile_commands.json'
            if candidate.exists():
                parsed_args.compdb = candidate
        elif arg in ['--config-file', '--export-fixes', '-load', '--vfsoverlay']:
            # if the arg is given as '-arg=value' it will be handled in the next case
            # if given as '-arg value' we will match here and skip the value as these
            # are special params taking a path we must not mix up with sources below
            i += 1
            parsed_args.tidyargs.append(sys.argv[i])
        elif arg.startswith('--cache-tidy'):
            # special cache-tidy option
            parsed_args.tidyargs.pop()
            arg = arg[12:]
            if arg.startswith('-o='):
                # output was explicitly given
                parsed_args.objectfile = arg[3:]
            elif arg.startswith(f'-{CCACHE_ENV}='):
                # ccache binary was overridden
                global CCACHE  # pylint: disable=global-statement
                CCACHE = arg[len(CCACHE_ENV)+2:]
            elif arg.startswith(f'-{CLANG_TIDY_ENV}='):
                # clang-tidy binary was overridden
                global CLANG_TIDY  # pylint: disable=global-statement
                CLANG_TIDY = arg[len(CLANG_TIDY_ENV)+2:]
        elif arg.startswith("-"):
            # skip any args identified by a -dash
            pass
        else:
            candidate = Path(arg)
            if candidate.exists():
                parsed_args.sources.append(candidate)
                # remove the source from args again
                del parsed_args.tidyargs[-1]
        i += 1
    return parsed_args


def filter_compdb(database: Path, sourcepath: Path) -> str:
    '''Filters the given compdb for lines affecting sourcefile'''
    out = []
    with open(database, 'r', encoding='utf8') as raw:
        # as a minimal performance tuning just iterate
        # all lines of the file and spare the overhead
        # to do a full json parsing
        for line in raw:
            # match any lines with our filename, while
            # this might cause false positives it is good
            # enough and avoids more complicated matching logic
            if sourcepath.name in line:
                out.append(line)
    return ''.join(out)


# MAIN flow
log_debug(f"Invoked as {sys.argv}")

# if CCACHE_TIDY_ARGS_ENV was set we have been invoked through ccache
# and should simply run clang-tidy now
if CCACHE_TIDY_ARGS:
    fwd = json.loads(CCACHE_TIDY_ARGS)
    if '-E' in sys.argv:
        # some versions of ccache request an output for
        # the preprocessed data and do not simply use stdout
        j = 1
        PREPROC_OUTPUT = None
        while j < len(sys.argv):
            argp = sys.argv[j]
            if argp.startswith('-o='):
                PREPROC_OUTPUT = argp[3:]
                break
            if argp.startswith('-o'):
                PREPROC_OUTPUT = sys.argv[j+1]
                break
            j += 1

        # ccache wants to get the preproc output
        # we create this from
        #   a) the source
        #   b) the effective config
        #   c) the effective lines in compdb
        sourcefile = Path(fwd['src'])
        FLAGS = filter_compdb(fwd['db'], sourcefile)
        SOURCE = sourcefile.read_text(encoding='utf8')
        ret, CONFIG = invoke_clang_tidy(['--dump-config'] + fwd['args'], capture_output=True)
        log_debug(f"Preprocessing '{sourcefile}' to {PREPROC_OUTPUT}:\n{SOURCE}\n{fwd['args']}\n{FLAGS}\n{CONFIG}")
        if ret == 0:
            if PREPROC_OUTPUT:
                with open(PREPROC_OUTPUT, 'w', encoding='utf-8') as sink:
                    sink.write(SOURCE)
                    sink.write(CONFIG)
                    sink.write(FLAGS)
            else:
                sys.stdout.write(SOURCE)
                sys.stdout.write(CONFIG)
                sys.stdout.write(FLAGS)
        sys.exit(ret)
    else:
        # ccache is doing the actual run
        ret = invoke_clang_tidy(fwd['args'] + [fwd['src']])
        if ret == 0:
            objectfile = Path(fwd['obj'])
            objectfile.write_text('Success', encoding='utf8')
            log_debug(f"Wrote result to {objectfile}")
        sys.exit(ret)

# else determine the compile_db and any sources before running them through ccache
args = parse_arguments()
if args.help:
    ret = show_help()
    sys.exit(ret)
if args.compdb:
    log_debug(f"Using compile database at {args.compdb}")
if not args.sources:
    log_info("Missing source input file(s)")
    sys.exit(1)

for sourcefile in args.sources:
    cc_env = {}
    extrafiles = os.environ.get('CCACHE_EXTRAFILES', None)
    SEP = ';' if sys.platform == 'win32' else ':'
    if extrafiles:
        extrafiles = extrafiles.split(SEP)
    else:
        extrafiles = []

    # forward the initial args to clang-tidy
    if args.objectfile is None:
        objectfile = sourcefile.with_suffix('.cache-tidy')
    else:
        objectfile = Path(args.objectfile)
    fwd_args = {
        'src': str(sourcefile),
        'obj': str(objectfile),
        'db': str(args.compdb),
        'args': args.tidyargs
    }
    cc_env[CCACHE_TIDY_ARGS_ENV] = json.dumps(fwd_args)
    cc_env[CLANG_TIDY_ENV] = CLANG_TIDY

    # clang-tidy works like clang, force it
    cc_env['CCACHE_COMPILERTYPE'] = 'clang'

    # in order to work reliably we force the plain preprocessor
    # mode as this is the most efficient due to our lack of actual
    # compiler flags and includes
    cc_env['CCACHE_NODEPEND'] = '1'
    cc_env['CCACHE_NODIRECT'] = '1'

    # ccache is considering this script as the compiler to be invoked
    # and hence will not track any changes to the clang-tidy binary
    # itself. Manually inject it to the xtra files in case we know the
    # full path
    if CLANG_TIDY and os.path.exists(CLANG_TIDY):
        extrafiles.append(CLANG_TIDY)

    if extrafiles:
        cc_env['CCACHE_EXTRAFILES'] = SEP.join(extrafiles)

    # ccache expects a regular compiler call here which is somewhat different
    # so we fake it and use a throw-away output. The actual arguments to clang-tidy
    # will be restored later when ccache is invoking us again in turn
    cc_args = ['-o', str(objectfile), '-c', str(sourcefile)]
    ret = invoke_ccache(cc_args, cc_env)

    # ccache forced us to generate an objectfile which we immediately remove again
    if args.objectfile is None or ret != 0:
        objectfile.unlink(missing_ok=True)

    # bail out on the first error
    if ret != 0:
        sys.exit(ret)

sys.exit(0)
