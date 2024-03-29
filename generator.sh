#!/usr/bin/env bash
# generator.sh
#
# Copyright (c) 2008 - 2024 Marius Zwicker
# All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

function help {
cat <<EOF

$0
==============================================

This file generates a project configuration for configuring
cmake using a predefined directory naming scheme

Valid arguments:
    'help' show this list
    'mode=(release|reldbg|debug)' to control build configuration, default: '$MZ_CMAKETOOLS_mode'
    'compiler=(clang|clang_arm64|gcc|ios|ios_legacy|ios_simulator|msvc)' to select compiler, default: '$MZ_CMAKETOOLS_compiler'
    'generator=(ninja|ninja_64|makefiles|sublime|xcode)', default: '$MZ_CMAKETOOLS_generator'
    'location=(inside|outside)' configures location of build files, default: '$MZ_CMAKETOOLS_location'
    '-DFOO=BAR' additional args to pass to cmake, default: '$MZ_CMAKETOOLS_args'

Can also be preselected using environment variables:
    MZ_CMAKETOOLS_mode=..
    MZ_CMAKETOOLS_compiler=..
    MZ_CMAKETOOLS_generator=..
    MZ_CMAKETOOLS_location=..
    MZ_CMAKETOOLS_args=..

EOF
}

function get_generator {
    case ${my_generator} in
        ninja)
            my_c_generator="Ninja"
            ;;
        eclipse)
            my_c_generator="Eclipse CDT4 - Unix Makefiles"
            ;;
        sublime)
            my_c_generator="Sublime Text 2 - Ninja"
            ;;
        xcode)
            my_c_generator="Xcode"
            ;;
        *)
            my_c_generator="Unix Makefiles"
            my_generator=makefiles
            ;;
    esac
}

function get_mode {
    case ${my_mode} in
        release)
            my_c_mode=Release
            ;;
        reldbg)
            my_c_mode=RelDbg
            ;;
        *)
            my_c_mode=Debug
            my_mode=debug
            ;;
    esac
}

function get_compiler {
    case ${my_compiler} in
        ios_simulator)
            my_cc=clang
            my_cxx=clang++
            my_args="${my_args} \
                -DCMAKE_TOOLCHAIN_FILE=${my_script_dir}/iOS.cmake \
                -DIOS_PLATFORM=SIMULATOR64 \
                -DENABLE_ARC=0 \
                -DENABLE_VISIBILITY=1 \
                -DENABLE_BITCODE=0 \
                -DIOS_DEPLOYMENT_TARGET=13.0"
            ;;
        ios_legacy)
            my_cc=clang
            my_cxx=clang++
            my_args="${my_args} \
                -DCMAKE_TOOLCHAIN_FILE=${my_script_dir}/iOS.cmake \
                -DIOS_PLATFORM=OS \
                -DENABLE_ARC=0 \
                -DENABLE_VISIBILITY=1 \
                -DENABLE_BITCODE=0 \
                -DIOS_DEPLOYMENT_TARGET=9.0 \
                -DIOS_ARCH=armv7"
            ;;
        ios)
            my_cc=clang
            my_cxx=clang++
            my_args="${my_args} \
                -DCMAKE_TOOLCHAIN_FILE=${my_script_dir}/iOS.cmake \
                -DIOS_PLATFORM=OS64 \
                -DENABLE_ARC=0 \
                -DENABLE_VISIBILITY=1 \
                -DENABLE_BITCODE=0 \
                -DIOS_DEPLOYMENT_TARGET=13.0 \
                -DIOS_ARCH=arm64"
            # force, the others do not work right now
            #my_c_generator="Unix Makefiles"
            ;;
        clang)
            my_cc=clang
            my_cxx=clang++
            case "$(uname -s)" in
                Darwin*)
                    export CONAN_CMAKE_SYSTEM_PROCESSOR=x86_64
                    export CONAN_CMAKE_OSX_ARCHITECTURES="x86_64"
                    my_args="${my_args} \
                        -DCMAKE_OSX_ARCHITECTURES=x86_64 \
                        -DCMAKE_SYSTEM_PROCESSOR=x86_64"
            esac
            ;;
        clang_arm64)
            export CONAN_CMAKE_SYSTEM_PROCESSOR=arm64
            export CONAN_CMAKE_OSX_ARCHITECTURES="arm64;x86_64"
            my_cc=clang
            my_cxx=clang++
            my_args="${my_args} \
                -DCMAKE_OSX_ARCHITECTURES=arm64;x86_64 \
                -DCMAKE_SYSTEM_PROCESSOR=arm64"
            ;;
        *)
            my_cc=gcc
            my_cxx=g++
            my_compiler=gcc
            ;;
    esac
}

function validate_config {
    if [ -z ${my_mode} ]; then
        echo "ERROR: Missing build mode"
        help
        exit 1
    fi

    if [ -z ${my_cc} ]; then
        echo "ERROR: Missing c compiler selection"
        help
        exit 1
    fi

    if [ -z ${my_cxx} ]; then
        echo "ERROR: Missing c++ compiler selection"
        help
        exit 1
    fi

    if [ -z ${my_generator} ]; then
        echo "ERROR: Missing cmake generator"
        help
        exit 1
    fi
}

function verbose {
    echo "-- my_mode=${my_mode}"
    echo "-- my_generator=${my_generator}"
    echo "-- my_c_mode=${my_c_mode}"
    echo "-- my_c_generator=${my_c_generator}"
    echo "-- my_compiler=${my_compiler}"
    echo "-- my_cxx=${my_cxx}"
    echo "-- my_cc=${my_cc}"
    echo "-- my_build_dir=${my_build_dir}"
    echo "-- my_script_dir=${my_script_dir}"
    echo "-- my_base_dir=${my_base_dir}"
    echo
}

function run_cmake {
    cd "${my_script_dir}"
    if [ ! -r ${my_build_dir} ] ; then
        mkdir -p ${my_build_dir}
    fi

    cd ${my_build_dir}

    echo "== configuring target system '${my_compiler}/${my_generator}/${my_mode}'"
    echo "-- additional arguments:${my_args}"
    CC=${my_cc} CXX=${my_cxx} \
    cmake   -D CMAKE_BUILD_TYPE=${my_c_mode} \
            ${my_args} \
            -G"${my_c_generator}" \
            ${my_base_dir}/
}

function install_conan {
    my_script_dir=`cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}"`
    my_script_dir=`dirname "${my_script_dir}"`

    source $my_script_dir/conan.sh
}

function debug_hint {
    echo
    echo -e "IMPORTANT HINT:\tWhen using this script to generate projects with build"
    echo -e "\t\ttype 'debug', please use the 'Debug' configuration for building"
    echo -e "\t\tbinaries only. Otherwise dependencies might not be set correctly."
    echo
    echo -e "\t\tTRICK:\tTo Build a Release Binary, run with argument 'mode=release'"
    echo
}

function detect_dir {

    echo "== running global configuration"

    # configuration detection
    my_base_dir=`cd "${0%/*}/.." 2>/dev/null; echo "$PWD"/"${0##*/}"`
    my_base_dir=`dirname "${my_base_dir}"`

    my_script_dir=`cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}"`
    my_script_dir=`dirname "${my_script_dir}"`

    case ${my_location} in
        inside)
            my_build_dir=${my_script_dir}/${my_compiler}-${my_generator}-${my_mode}
            ;;
        *)
            my_build_dir=${my_base_dir}_${my_compiler}-${my_generator}-${my_mode}
            ;;
    esac

    echo "-- determining working directory: ${my_script_dir}"
    echo "-- build root will be: ${my_base_dir}"
    echo "-- generating to: ${my_build_dir}"
    echo

}

# default to using env variables
my_generator=$MZ_CMAKETOOLS_generator
my_compiler=$MZ_CMAKETOOLS_compiler
my_mode=$MZ_CMAKETOOLS_mode
my_args=$MZ_CMAKETOOLS_args
my_location=$MZ_CMAKE_TOOLS_location

# parse the given arguments
for arg in "$@"
do
    type=`echo ${arg} | awk -F "=" '{print $1}'`
    value=`echo ${arg} | awk -F "=" '{print $2}'`

    case ${type} in
        generator)
            my_generator=${value}
            ;;
        mode)
            my_mode=${value}
            ;;
        compiler)
            my_compiler=${value}
            ;;
        location)
            my_location=${value}
            ;;
        help)
            help
            exit 0
            ;;
        *)
            my_args="${my_args} ${arg}"
            ;;
    esac
done

# align the conan version
install_conan

# switch to batch file if picking MSVC
if [[ "msvc" == $my_compiler ]] ; then
    my_script_dir=`cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}"`
    my_script_dir=`dirname "${my_script_dir}"`
    exec $my_script_dir/generator.bat $my_mode $my_generator $my_location $my_args
fi

# get the working directory
detect_dir

# convert arguments to params
get_generator
get_mode
get_compiler

# fallback to gcc
if [ -z ${my_cc} ]; then
    my_cc=gcc
fi

if [ -z ${my_cxx} ]; then
    my_cxx=g++
fi

# print obtained variable values
#verbose

if [ "${my_mode}" = "debug" ]; then
    debug_hint
fi

# finally execute the cmake generation
validate_config
run_cmake

echo

exit
