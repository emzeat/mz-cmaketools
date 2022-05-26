#
# 3rdparty.cmake
#
# Copyright (c) 2019 - 2022 Marius Zwicker
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
#   BUILD/CONAN.CMAKE
#
#   Wrapper macros to transparently integrate conan with
#   the cmake build system such that individual targets
#   or submodules can declare their own dependencies and
#   the resulting global conan dependencies get aggregated
#   and installed automatically
#

# if global.cmake was not included yet, report it
if (NOT HAS_MZ_GLOBAL)
    message(FATAL_ERROR "!! include global.cmake before including this file !!")
endif()

find_program(PYTHON3 python3 REQUIRED)
find_program(CONAN conan REQUIRED)
set(_MZ_CONAN_DIR ${CMAKE_SOURCE_DIR}/build/Conan)

macro(mz_conan_message MSG)
    mz_message("  conan: ${MSG}")
endmacro()
macro(mz_conan_warning MSG)
    mz_warning_message("  conan: ${MSG}")
endmacro()

if(MZ_MACOS)
    set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.macOS.conan)
    set(CONAN_DISABLE_CHECK_COMPILER ON)
elseif(MZ_IOS)
    set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.iOS.conan)
endif()

function(_mz_conan_process_requires _variable _access _value _current_list_file _stack)
    if(_value STREQUAL "")
        mz_conan_message("Processing requirements: ${MZ_CONAN_REQUIRES}")
        list(JOIN MZ_CONAN_REQUIRES "\n" MZ_CONAN_REQUIRES_ITEMS)
        list(JOIN MZ_CONAN_TOOL_REQUIRES "\n" MZ_CONAN_TOOL_REQUIRES_ITEMS)
        configure_file(${_MZ_CONAN_DIR}/conanfile.txt.in ${CMAKE_BINARY_DIR}/conanfile.txt)

        mz_conan_message("Processing profile: ${_MZ_CONAN_PROFILE}")
        list(APPEND MZ_CONAN_ENV CFLAGS="${MZ_3RDPARTY_C_FLAGS}")
        list(APPEND MZ_CONAN_ENV CXXFLAGS="${MZ_3RDPARTY_CXX_FLAGS}")
        list(JOIN MZ_CONAN_ENV "\n" MZ_CONAN_ENV_ITEMS)
        configure_file(${_MZ_CONAN_PROFILE} ${CMAKE_BINARY_DIR}/profile.conan)

        include(${_MZ_CONAN_DIR}/conan.cmake)
        conan_cmake_run(
            CONANFILE ${CMAKE_BINARY_DIR}/conanfile.txt
            CONAN_COMMAND ${CONAN}
            PROFILE ${CMAKE_BINARY_DIR}/profile.conan
            BUILD missing
            BUILD_TYPE Release
            BASIC_SETUP CMAKE_TARGETS
        )
        mz_conan_message("Imported Targets: ${CONAN_TARGETS}")
    endif()
endfunction()
variable_watch(CMAKE_CURRENT_LIST_DIR _mz_conan_process_requires)

function(_mz_conan_handle_requires VAR DESC ITEMS)
    foreach(ITEM ${ITEMS})
        string(REGEX MATCH "^([^/]+)/" ITEM_NAME ${ITEM})
        if(NOT ${VAR} MATCHES ${ITEM_NAME})
            mz_conan_message("New ${DESC}: ${ITEM}")
            set(${VAR}
                "${${VAR}};${ITEM}"
                CACHE INTERNAL "mz_conan_${DESC}"
            )
            # ITEM_NAME is <package>/ so strip the trailing /
            string(REPLACE "/" "" ITEM_NAME ${ITEM_NAME})
            if(EXISTS ${_MZ_CONAN_DIR}/Options/${ITEM_NAME}.conan)
                mz_conan_message("Importing options: ${_MZ_CONAN_DIR}/Options/${ITEM_NAME}.conan")
                file(READ ${_MZ_CONAN_DIR}/Options/${ITEM_NAME}.conan _MZ_CONAN_TMP_OPTS)
                set(${VAR}_OPTS
                    "${${VAR}_OPTS}\n${_MZ_CONAN_TMP_OPTS}"
                    CACHE INTERNAL "mz_conan_${DESC}_opts"
                )
            endif()
        else()
            mz_conan_message("Using ${DESC}: ${ITEM}")
        endif()
    endforeach()
endfunction()

set(MZ_CONAN_REQUIRES "" CACHE INTERNAL "mz_conan_requirement" )
function(mz_conan_requires)
    _mz_conan_handle_requires(MZ_CONAN_REQUIRES requirement "${ARGV}")
endfunction()

set(MZ_CONAN_TOOL_REQUIRES "" CACHE INTERNAL "mz_conan_tool" )
function(mz_conan_tool_requires)
    _mz_conan_handle_requires(MZ_CONAN_TOOL_REQUIRES tool "${ARGV}")
endfunction()
