#
# semver.cmake
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
#

##################################################
#
#   BUILD/VERSION.CMAKE
#
#   Helper to get a sem ver compliant version string
#   out of CMake and the containing git repository.
#
#   This is assuming git tags are of the form "v0.0.0"
#
#   See https://semver.org/ on semantic versioning.
#
#   Some example version strings:
#    - no tags, commit only: "0.0.0+sha.a1b2d3c4"
#    - git tag v2.1.0: "2.1.0"
#    - git tag with 3 commits on top: "2.1.0+3.sha.a1b2d3c4"
#    - git tag with uncommited local changes: "2.1.0+dirty"
#    - git tag, 3 commits, local changes : "2.1.0+3.sha.a1b2d3c4.dirty"
#
# PROVIDED MACROS
# -----------------------
#
# mz_determine_sem_ver(PREFIX <prefix> [USE_CWD])
#       Determines the semantic version using git tag information
#       and stores the output as
#           <prefix>_VERSION
#           <prefix>_VERSION_SHORT
#
#       By default the prefix will be determined using CMAKE_CURRENT_LIST_DIR.
#       Pass the USE_CWD option to use the current working directory instead.
#
#       If the variables are defined before calling the macro
#       they will be respected
#
#  When included with MZ_SEMVER_TO_FILE defined as string it will
#  immediately try to determine the git tag version and write it
#  to the patch given by MZ_SEMVER_TO_FILE. Useful to e.g. execute
#  with cmake's script mode via `cmake -P`.
#
########################################################################

include_guard(GLOBAL)

find_package(Git REQUIRED)

macro(mz_determine_sem_ver)
    # see https://cmake.org/cmake/help/v3.18/command/cmake_parse_arguments.html#command:cmake_parse_arguments
    set(_mz_semver_options
        USE_CWD
    )
    set(_mz_semver_oneValueArgs
        PREFIX
    )
    set(_mz_semver_multiValueArgs
    )
    cmake_parse_arguments(_mz_semver
        "${_mz_semver_options}"
        "${_mz_semver_oneValueArgs}"
        "${_mz_semver_multiValueArgs}"
        ${ARGN}
    )
    if(_mz_semver_UNPARSED_ARGUMENTS)
        mz_fatal_message("No such option: ${_mz_semver_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT _mz_semver_PREFIX)
        mz_fatal_message("PREFIX is a required argument")
    endif()

    if(${_mz_semver_PREFIX}_VERSION)
        message("-- semver: Version defined from outside '${${_mz_semver_PREFIX}_VERSION}'")

    elseif(GIT_FOUND)

        if(NOT _mz_semver_USE_CWD)
            set(_WC_WKDIR WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR})
        endif()

        # we use a short hash
        execute_process(
            COMMAND ${GIT_EXECUTABLE} describe --tags --long --dirty
            ${_WC_WKDIR}
            OUTPUT_VARIABLE _WC_TAG
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        #set(_WC_TAG "v1.2.3-4-gabcdefg-dirty")
        #set(_WC_TAG "v1.2.3-4-gabcdefg")
        #set(_WC_TAG "v1.2.3")
        if(_WC_TAG MATCHES "^v([^-]+)(-([0-9]+)-g([a-z0-9]+))?(-dirty)?$")
            set(_WC_VER "${CMAKE_MATCH_1}")
            if(CMAKE_MATCH_3 AND CMAKE_MATCH_4)
                list(APPEND _WC_EXTRA "${CMAKE_MATCH_3}.sha.${CMAKE_MATCH_4}")
            endif()
            if(CMAKE_MATCH_5)
                list(APPEND _WC_EXTRA "dirty")
            endif()
            if(_WC_EXTRA)
                list(JOIN _WC_EXTRA "." _WC_EXTRA)
                set(_WC_TAG "${_WC_VER}+${_WC_EXTRA}")
                set(_WC_DIRTY TRUE)
            else()
                set(_WC_TAG "${_WC_VER}")
            endif()
        else()
            execute_process(
                COMMAND ${GIT_EXECUTABLE} log --pretty=format:%h -n 1
                ${_WC_WKDIR}
                OUTPUT_VARIABLE _WC_REVISION
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_QUIET
            )
            set(_WC_VER "0.0.0")
            set(_WC_TAG "0.0.0+sha.${_WC_REVISION}")
        endif()
    endif()

    set(${_mz_semver_PREFIX}_VERSION ${_WC_TAG})
    set(${_mz_semver_PREFIX}_VERSION_SHORT ${_WC_VER})
    set(${_mz_semver_PREFIX}_VERSION_DIRTY ${_WC_DIRTY})

endmacro()

if(MZ_SEMVER_TO_FILE)
    mz_determine_sem_ver(PREFIX "SCRIPTED" USE_CWD)
    message("-- semver: Writing '${SCRIPTED_VERSION}' to '${MZ_SEMVER_TO_FILE}")
    file(WRITE ${MZ_SEMVER_TO_FILE} ${SCRIPTED_VERSION})
endif()
