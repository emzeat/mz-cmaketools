# conan.cmake
#
# Copyright (c) 2019 - 2023 Marius Zwicker
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

##################################################
#
#   BUILD/CONAN.CMAKE
#
#   Automatically installs any conan packages when a conanfile.txt
#   or conanfile.py is found in the project root.
#
#   Will automatically add a remote to enable download of emzeat
#   specific conan packages. This can be overwritten with the following
#   env variables:
#       - MZ_CONAN_REMOTE_URL The url to a conan repository holding the packages
#       - MZ_CONAN_REMOTE_NAME The name to use for creating the remote
#       - MZ_CONAN_REMOTE_INDEX The index at which the remote will be added
#       - MZ_CONAN_ALLOW_ANY_REMOTE If all remotes shall be used during package
#                         install, not only the emzeat specific one
#
#   MZ_CONAN_INSTALL_DIR specify this to override the directory used for
#   importing dependencies when CONAN_EXPORT is defined, i.e. configuring
#   within a conan package.
#
#   CONAN_BUILD_MISSING set to true to build all missing packages
#   CONAN_BUILD_MISSING_RECIPES use this to define a list of selected packages
#                               to be built when missing
#

mz_include_guard(GLOBAL)

# if global.cmake was not included yet, report it
if (NOT HAS_MZ_GLOBAL)
    message(FATAL_ERROR "!! include global.cmake before including this file !!")
endif()

find_program(PYTHON3 python3 REQUIRED)
find_program(CONAN conan REQUIRED)
set(_MZ_CONAN_DIR ${CMAKE_SOURCE_DIR}/build/Conan)

# macros for convenient logging
macro(mz_conan_message MSG)
    mz_message("  conan: ${MSG}")
endmacro()
macro(mz_conan_debug MSG)
    mz_conan_message("${MSG}")
endmacro()
macro(mz_conan_warning MSG)
    mz_warning_message("  conan: ${MSG}")
endmacro()

# import the platform specific profile
if(MZ_MACOS)
    set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.macOS.conan)
    set(CONAN_DISABLE_CHECK_COMPILER ON)
elseif(MZ_IOS)
    if (IOS_PLATFORM STREQUAL "OS64")
        set(CMAKE_CROSSCOMPILING ON)
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.iOS.conan)
        set(_MZ_CONAN_BUILD_PROFILE ${_MZ_CONAN_DIR}/profile.macOS.conan)
    elseif (IOS_PLATFORM STREQUAL "SIMULATOR64")
        set(CMAKE_CROSSCOMPILING ON)
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.iOSsimulator.conan)
        set(_MZ_CONAN_BUILD_PROFILE ${_MZ_CONAN_DIR}/profile.macOS.conan)
    endif()
elseif(MZ_LINUX)
    if(MZ_IS_CLANG)
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.linux_clang.conan)
    else()
        set(CONAN_DISABLE_CHECK_COMPILER ON)
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.linux_gcc.conan)
    endif()
elseif(MZ_WINDOWS)
    if(MZ_IS_VS)
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.win32_msvc.conan)
    endif()
endif()
if(_MZ_CONAN_PROFILE AND NOT _MZ_CONAN_BUILD_PROFILE)
    set(_MZ_CONAN_BUILD_PROFILE ${_MZ_CONAN_PROFILE})
endif()
if(NOT _MZ_CONAN_PROFILE AND NOT CONAN_EXPORTED)
    mz_fatal_message("No CONAN profile on this platform")
endif()

# gather all conan option profiles
file(GLOB _MZ_CONAN_OPTION_FILES ${_MZ_CONAN_DIR}/Options/*.conan)
foreach(OPTION_FILE ${_MZ_CONAN_OPTION_FILES})
    list(APPEND _MZ_CONAN_PROFILE_INCLUDES "include(${OPTION_FILE})")
endforeach()
list(JOIN _MZ_CONAN_PROFILE_INCLUDES "\n" _MZ_CONAN_PROFILE_INCLUDES)

# test for the conanfile variant
if(EXISTS ${CMAKE_SOURCE_DIR}/conanfile.txt)
    set(_MZ_CONAN_FILE ${CMAKE_SOURCE_DIR}/conanfile.txt)
elseif(EXISTS ${CMAKE_SOURCE_DIR}/conanfile.py)
    set(_MZ_CONAN_FILE ${CMAKE_SOURCE_DIR}/conanfile.py)
elseif(NOT CONAN_EXPORTED)
    mz_conan_warning("No conanfile.(txt|py) - skipping install")
endif()

# will process all conan dependencies and install them
if(_MZ_CONAN_FILE AND NOT CONAN_EXPORTED)
    execute_process(COMMAND conan config home
        OUTPUT_VARIABLE _MZ_CONAN_HOME
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    string(REPLACE "\\" "/" _MZ_CONAN_HOME ${_MZ_CONAN_HOME})
    mz_conan_message("Home at ${_MZ_CONAN_HOME}")

    execute_process(COMMAND conan --version
        OUTPUT_VARIABLE _MZ_CONAN_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(_MZ_CONAN_VERSION MATCHES "Conan version 1.[0-9.]+")
        set(_MZ_CONAN_VERSION_1 ON)
        mz_conan_message("Detected Conan v1")
    else()
        set(_MZ_CONAN_VERSION_2 ON)
        mz_conan_message("Detected Conan v2")
    endif()

    set(MZ_CONAN_REMOTE_NAME emzeat)
    if(DEFINED ENV{MZ_CONAN_REMOTE_NAME})
        set(MZ_CONAN_REMOTE_NAME $ENV{MZ_CONAN_REMOTE_NAME})
    endif()
    set(MZ_CONAN_REMOTE_URL https://codeberg.org/api/packages/emzeat/conan)
    if(DEFINED ENV{MZ_CONAN_REMOTE_URL})
        set(MZ_CONAN_REMOTE_URL $ENV{MZ_CONAN_REMOTE_URL})
    endif()
    if(DEFINED ENV{MZ_CONAN_REMOTE_INDEX})
        if(_MZ_CONAN_VERSION_1)
            list(APPEND _MZ_CONAN_REMOTE_ARGS
                --insert=$ENV{MZ_CONAN_REMOTE_INDEX}
            )
        else()
            list(APPEND _MZ_CONAN_REMOTE_ARGS
                --index=$ENV{MZ_CONAN_REMOTE_INDEX}
            )
        endif()
    endif()

    execute_process(COMMAND conan remote list
        OUTPUT_VARIABLE _MZ_CONAN_REMOTES
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(_MZ_CONAN_REMOTES MATCHES "${MZ_CONAN_REMOTE_NAME}: ([^ ]+)")
        mz_conan_message("Found existing remote '${MZ_CONAN_REMOTE_NAME}' at ${CMAKE_MATCH_1}")
    else()
        mz_conan_message("Adding remote '${MZ_CONAN_REMOTE_NAME}' at ${MZ_CONAN_REMOTE_URL}")
        execute_process(
            COMMAND conan remote add ${_MZ_CONAN_REMOTE_ARGS} ${MZ_CONAN_REMOTE_NAME} ${MZ_CONAN_REMOTE_URL}
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()

    if(DEFINED ENV{MZ_CONAN_ALLOW_ANY_REMOTE})
        set(MZ_CONAN_ALLOW_ANY_REMOTE TRUE)
    endif()
    if(NOT MZ_CONAN_ALLOW_ANY_REMOTE)
        mz_conan_message("Forcing use of remote '${MZ_CONAN_REMOTE_NAME}'")
        list(APPEND _MZ_CONAN_INSTALL_ARGS
            --remote=${MZ_CONAN_REMOTE_NAME}
        )
    else()
        mz_conan_message("Will use packages from any remote")
    endif()

    mz_conan_message("Processing profile '${_MZ_CONAN_PROFILE}'")
    list(APPEND MZ_CONAN_ENV CFLAGS="${MZ_3RDPARTY_C_FLAGS}")
    list(APPEND MZ_CONAN_ENV CXXFLAGS="${MZ_3RDPARTY_CXX_FLAGS}")
    list(JOIN MZ_CONAN_ENV "\n" MZ_CONAN_ENV_ITEMS)
    configure_file(${_MZ_CONAN_PROFILE} ${CMAKE_BINARY_DIR}/profile.conan)
    configure_file(${_MZ_CONAN_BUILD_PROFILE} ${CMAKE_BINARY_DIR}/build_profile.conan)
    list(APPEND _MZ_CONAN_INSTALL_ARGS
        --profile:host ${CMAKE_BINARY_DIR}/profile.conan
        --profile:build ${CMAKE_BINARY_DIR}/build_profile.conan
        -s build_type=Release -s &:build_type=${CMAKE_BUILD_TYPE}
    )

    option(CONAN_BUILD_MISSING "Automatically build package binaries not on the remote" OFF)
    if(CONAN_BUILD_MISSING)
        mz_conan_message("Will build missing binary packages")
        list(APPEND _MZ_CONAN_INSTALL_ARGS
            --build=missing
        )
    elseif(CONAN_BUILD_MISSING_RECIPES)
        mz_conan_message("Will build missing binary packages for ${CONAN_BUILD_MISSING_RECIPES}")
        list(APPEND _MZ_CONAN_INSTALL_ARGS
            --build=${CONAN_BUILD_MISSING_RECIPES}
        )
    else()
        list(APPEND _MZ_CONAN_INSTALL_ARGS
            --build=never
        )
    endif()

    set(MZ_CONAN_INSTALL_DIR ${CMAKE_BINARY_DIR}/conan)
    list(APPEND _MZ_CONAN_INSTALL_ARGS
        --output-folder=${MZ_CONAN_INSTALL_DIR}
        --generator VirtualBuildEnv
        --generator VirtualRunEnv
    )
    if(_MZ_CONAN_VERSION_1)
        list(APPEND _MZ_CONAN_INSTALL_ARGS
            --install-folder=${MZ_CONAN_INSTALL_DIR}
        )
    endif()
    execute_process(
        COMMAND conan install ${_MZ_CONAN_INSTALL_ARGS} ${CMAKE_SOURCE_DIR}
        COMMAND_ECHO STDOUT
        COMMAND_ERROR_IS_FATAL ANY
    )

else()
    if(NOT MZ_CONAN_INSTALL_DIR)
        set(MZ_CONAN_INSTALL_DIR ${CMAKE_BINARY_DIR})
    endif()
    mz_conan_message("Using existing conan environment below '${MZ_CONAN_INSTALL_DIR}'")
endif()

# when 'CMakeToolchain' generator is used, automatically import it
# FIXME(zwicker): conan_toolchain.cmake is setting bad sysroot when only included now
if(FALSE AND EXISTS ${MZ_CONAN_INSTALL_DIR}/conan_toolchain.cmake)
    include(${MZ_CONAN_INSTALL_DIR}/conan_toolchain.cmake)
# add the module path to support the 'CMakeDeps' generator
else()
    mz_conan_message("Searching modules in ${MZ_CONAN_INSTALL_DIR}")
    list(PREPEND CMAKE_MODULE_PATH ${MZ_CONAN_INSTALL_DIR})
    list(PREPEND CMAKE_PREFIX_PATH ${MZ_CONAN_INSTALL_DIR})
endif()
# fixup the env to parse reliably
if(MZ_WINDOWS)
    string(REPLACE "\\" "/" _MZ_PATH "$ENV{PATH}")
endif()
# also make sure to include the env to import any binaries
if(MZ_WINDOWS)
    set(_MZ_PATH_SEP ";")
    file(WRITE ${MZ_CONAN_INSTALL_DIR}/echo_path.bat "
        @echo off
        SetLocal EnableDelayedExpansion
        call %1
        echo !PATH!
    ")
    file(GLOB MZ_CONAN_BUILD_ENV ${MZ_CONAN_INSTALL_DIR}/conanbuildenv-*.bat)
    if(MZ_CONAN_BUILD_ENV)
        execute_process(
            COMMAND ${MZ_CONAN_INSTALL_DIR}/echo_path.bat ${MZ_CONAN_BUILD_ENV}
            OUTPUT_VARIABLE MZ_CONAN_BUILD_ENV_PATH
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    endif()
    file(GLOB MZ_CONAN_RUN_ENV ${MZ_CONAN_INSTALL_DIR}/conanrunenv-*.bat)
    if(MZ_CONAN_RUN_ENV)
        execute_process(
            COMMAND ${MZ_CONAN_INSTALL_DIR}/echo_path.bat ${MZ_CONAN_RUN_ENV}
            OUTPUT_VARIABLE MZ_CONAN_RUN_ENV_PATH
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    endif()
else()
    set(_MZ_PATH_SEP ":")
    set(MZ_CONAN_BUILD_ENV ${MZ_CONAN_INSTALL_DIR}/conanbuild.sh)
    if(EXISTS ${MZ_CONAN_BUILD_ENV})
        execute_process(
            COMMAND bash -c "source ${MZ_CONAN_BUILD_ENV}; echo $PATH"
            OUTPUT_VARIABLE MZ_CONAN_BUILD_ENV_PATH
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    endif()
    set(MZ_CONAN_RUN_ENV ${MZ_CONAN_INSTALL_DIR}/conanrun.sh)
    if(EXISTS ${MZ_CONAN_RUN_ENV})
        execute_process(
            COMMAND bash -c "source ${MZ_CONAN_RUN_ENV}; echo $PATH"
            OUTPUT_VARIABLE MZ_CONAN_RUN_ENV_PATH
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    endif()
endif()
# calculate the delta added by Conan for use in the presets
if(MZ_CONAN_BUILD_ENV_PATH)
    string(REPLACE "$ENV{PATH}${_MZ_PATH_SEP}" "" _MZ_CONAN_BUILD_PATH "${MZ_CONAN_BUILD_ENV_PATH}")
    string(REPLACE "${_MZ_PATH_SEP}$ENV{PATH}" "" _MZ_CONAN_BUILD_PATH "${MZ_CONAN_BUILD_ENV_PATH}")
endif()
if(MZ_CONAN_RUN_ENV_PATH)
    string(REPLACE "$ENV{PATH}${_MZ_PATH_SEP}" "" _MZ_CONAN_RUN_PATH "${MZ_CONAN_RUN_ENV_PATH}")
    string(REPLACE "${_MZ_PATH_SEP}$ENV{PATH}" "" _MZ_CONAN_RUN_PATH "${MZ_CONAN_RUN_ENV_PATH}")
endif()
if(_MZ_CONAN_RUN_PATH OR _MZ_CONAN_BUILD_PATH)
    set(_MZ_CONAN_PATH "${_MZ_CONAN_RUN_PATH}${_MZ_PATH_SEP}${_MZ_CONAN_BUILD_PATH}")
    # update env with the full PATH
    set(ENV{PATH} "${_MZ_CONAN_PATH}${_MZ_PATH_SEP}$ENV{PATH}")
    string(REPLACE "\\" "\\\\" _MZ_CONAN_PATH "${_MZ_CONAN_PATH}")
endif()

include(${MZ_TOOLS_PATH}/presets.cmake)
