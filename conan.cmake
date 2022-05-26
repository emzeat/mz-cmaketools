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
    set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.iOS.conan)
endif()

# will process all conan dependencies and install them
function(_mz_conan_process_requires)
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
endfunction()

# will link all conan dependencies to their targets
function(_mz_conan_process_link_libraries)
    cmake_policy(SET CMP0079 NEW) # allow target_link_libraries from different dir
    foreach(TARGET ${MZ_CONAN_TARGETS})
        get_property(TARGET_PLAIN TARGET ${TARGET} PROPERTY MZ_CONAN)
        if(TARGET_PLAIN)
            mz_conan_debug("Linkage for ${TARGET}: ${TARGET_PLAIN}")
            target_link_libraries(${TARGET}
                ${TARGET_PLAIN}
            )
        endif()
        get_property(TARGET_PUB TARGET ${TARGET} PROPERTY MZ_CONAN_PUBLIC)
        if(TARGET_PUB)
            mz_conan_debug("Public linkage for ${TARGET}: ${TARGET_PUB}")
            target_link_libraries(${TARGET}
                PUBLIC ${TARGET_PUB}
            )
        endif()
        get_property(TARGET_PRV TARGET ${TARGET} PROPERTY MZ_CONAN_PRIVATE)
        if(TARGET_PRV)
            mz_conan_debug("Private linkage for ${TARGET}: ${TARGET_PRV}")
            target_link_libraries(${TARGET}
                PRIVATE ${TARGET_PUB}
            )
        endif()
    endforeach()
endfunction()

# calls automatically deferred to the end of the configure phase
function(_mz_conan_deferred_calls)
    _mz_conan_process_requires()
    _mz_conan_process_link_libraries()
endfunction()
cmake_language(DEFER 
    DIRECTORY ${CMAKE_SOURCE_DIR}
    CALL _mz_conan_deferred_calls
)

# helper to split a conan dependency into version and name
function(_mz_conan_split DEPENDENCY NAME VERSION)
    string(REGEX MATCH "^([^/]+)/" _NAME ${DEPENDENCY})
    string(REGEX MATCH "/([^/]+)$" _VERSION ${DEPENDENCY})
    # NAME is <package>/ so strip the trailing /
    string(REPLACE "/" "" _NAME ${_NAME})
    # VERSION is /<version> so strip the leading /
    string(REPLACE "/" "" _VERSION ${_VERSION})
    # export the values
    set(${NAME} ${_NAME} PARENT_SCOPE)
    set(${VERSION} ${_VERSION} PARENT_SCOPE)
endfunction()

# processes conan requirement statements
function(_mz_conan_handle_requires VAR DESC ITEMS)
    foreach(ITEM ${ITEMS})
        _mz_conan_split(${ITEM} ITEM_NAME ITEM_VERSION)
        if(NOT ${VAR} MATCHES "${ITEM_NAME}/")
            mz_conan_message("New ${DESC}: ${ITEM_NAME}/${ITEM_VERSION}")
            set(${VAR}
                "${${VAR}};${ITEM}"
                CACHE INTERNAL "mz_conan_${DESC}"
            )

            # the actual targets will get generated by _mz_conan_process_requires
            # above which will be too late to use them. Fix by predefining
            # the target here and let it be populated later on
            #add_library(MZ_CONAN_PKG::${ITEM_NAME} INTERFACE IMPORTED)

            # apply any predefined options
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
set(MZ_CONAN_TARGETS "" CACHE INTERNAL "mz_conan_targets" )
# function used identically to target_link_libraries() but
# instead of targets this will accept conan package declarations
function(mz_conan_target_link_libraries TARGET)
    cmake_parse_arguments( _mzC
        "" # options
        "" # one_value_keywords
        "PRIVATE PUBLIC" # multi_value_keywords
        ${ARGN}
    )
    # gather the target names and store them for later
    set(MZ_CONAN_TARGETS "${MZ_CONAN_TARGETS};${TARGET}" CACHE INTERNAL "mz_conan_targets" )
    mz_conan_debug("${TARGET}: ${_mzC_PRIVATE}")
    foreach(ITEM ${_mzC_UNPARSED_ARGUMENTS})
        _mz_conan_split(${ITEM} ITEM_NAME ITEM_VERSION)
        set_property(TARGET ${TARGET} APPEND PROPERTY MZ_CONAN "CONAN_PKG::${ITEM_NAME}")
    endforeach()
    mz_conan_debug("${TARGET} PUBLIC: ${_mzC_PUBLIC}")
    foreach(ITEM ${_mzC_PUBLIC})
        _mz_conan_split(${ITEM} ITEM_NAME ITEM_VERSION)
        set_property(TARGET ${TARGET} APPEND PROPERTY MZ_CONAN_PUBLIC "CONAN_PKG::${ITEM_NAME}")
    endforeach()
    mz_conan_debug("${TARGET} PRIVATE: ${_mzC_PRIVATE}")
    foreach(ITEM ${_mzC_PRIVATE})
        _mz_conan_split(${ITEM} ITEM_NAME ITEM_VERSION)
        set_property(TARGET ${TARGET} APPEND PROPERTY MZ_CONAN_PRIVATE "CONAN_PKG::${ITEM_NAME}")
    endforeach()
    # pull the resulting dependencies
    _mz_conan_handle_requires(MZ_CONAN_REQUIRES requirement "${_mzC_PUBLIC};${_mzC_PRIVATE};${_mzC_UNPARSED_ARGUMENTS}")
endfunction()

set(MZ_CONAN_TOOL_REQUIRES "" CACHE INTERNAL "mz_conan_tool" )
function(mz_conan_tool_requires)
    _mz_conan_handle_requires(MZ_CONAN_TOOL_REQUIRES tool "${ARGV}")
endfunction()
