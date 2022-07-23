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
#   Automatically installs any conan packages when a conanfile.txt
#   or conanfile.py is found in the project root.
#
#   Will automatically add a remote to enable download of emzeat
#   specific conan packages. This can be overwritten with the following
#   env variables:
#       - MZ_CONAN_REMOTE_URL The url to a conan repository holding the packages
#       - MZ_CONAN_REMOTE_NAME The name to use for creating the remote
#       - MZ_CONAN_REMOTE_INDEX The index at which the remote will be added

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
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.iOS.conan)
    elseif (IOS_PLATFORM STREQUAL "SIMULATOR64")
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.iOSsimulator.conan)
    endif()
elseif(MZ_LINUX)
    if(MZ_IS_CLANG)
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.linux_clang.conan)
    else()
        set(_MZ_CONAN_PROFILE ${_MZ_CONAN_DIR}/profile.linux_gcc.conan)
    endif()
endif()

# gather all conan option profiles
file(GLOB _MZ_CONAN_OPTION_FILES ${_MZ_CONAN_DIR}/Options/*.conan)
foreach(OPTION_FILE ${_MZ_CONAN_OPTION_FILES})
    list(APPEND _MZ_CONAN_PROFILE_INCLUDES "include(${OPTION_FILE})")
endforeach()
list(JOIN _MZ_CONAN_PROFILE_INCLUDES "\n" _MZ_CONAN_PROFILE_INCLUDES)

# test for the conanfile variant
if(EXISTS ${CMAKE_SOURCE_DIR}/conanfile.txt)
    configure_file(${CMAKE_SOURCE_DIR}/conanfile.txt ${CMAKE_BINARY_DIR}/conanfile.txt)
    set(_MZ_CONAN_FILE ${CMAKE_BINARY_DIR}/conanfile.txt)
elseif(EXISTS ${CMAKE_SOURCE_DIR}/conanfile.py)
    configure_file(${CMAKE_SOURCE_DIR}/conanfile.py ${CMAKE_BINARY_DIR}/conanfile.py)
    set(_MZ_CONAN_FILE ${CMAKE_BINARY_DIR}/conanfile.py)
else()
    mz_conan_warning("No conanfile.(txt|py) - skipping install")
endif()

# will process all conan dependencies and install them
if(_MZ_CONAN_FILE)
    include(${_MZ_CONAN_DIR}/conan.cmake)

    set(MZ_CONAN_REMOTE_NAME emzeat)
    if(DEFINED ENV{MZ_CONAN_REMOTE_NAME})
        set(MZ_CONAN_REMOTE_NAME $ENV{MZ_CONAN_REMOTE_NAME})
    endif()
    set(MZ_CONAN_REMOTE_URL https://mirrors.emzeat.de/repository/conan/)
    if(DEFINED ENV{MZ_CONAN_REMOTE_URL})
        set(MZ_CONAN_REMOTE_URL $ENV{MZ_CONAN_REMOTE_URL})
    endif()
    if(DEFINED ENV{MZ_CONAN_REMOTE_INDEX})
        set(_MZ_CONAN_REMOTE_ARGS 
            INDEX $ENV{MZ_CONAN_REMOTE_INDEX}
        )
    endif()

    execute_process(COMMAND conan remote list
        OUTPUT_VARIABLE _MZ_CONAN_REMOTES
        ERROR_QUIET
    )
    if(_MZ_CONAN_REMOTES MATCHES "${MZ_CONAN_REMOTE_NAME}: ")
        mz_conan_message("Using existing '${MZ_CONAN_REMOTE_NAME}'")
    else()
        conan_add_remote(NAME ${MZ_CONAN_REMOTE_NAME}
            URL ${MZ_CONAN_REMOTE_URL}
            ${_MZ_CONAN_REMOTE_ARGS}
            VERIFY_SSL True
        )
    endif()

    mz_conan_message("Processing profile '${_MZ_CONAN_PROFILE}'")
    list(APPEND MZ_CONAN_ENV CFLAGS="${MZ_3RDPARTY_C_FLAGS}")
    list(APPEND MZ_CONAN_ENV CXXFLAGS="${MZ_3RDPARTY_CXX_FLAGS}")
    list(JOIN MZ_CONAN_ENV "\n" MZ_CONAN_ENV_ITEMS)
    configure_file(${_MZ_CONAN_PROFILE} ${CMAKE_BINARY_DIR}/profile.conan)

    option(CONAN_BUILD_MISSING "Automatically build package binaries not on the remote" OFF)
    if(CONAN_BUILD_MISSING)
        mz_conan_message("Will build missing binary packages")
        set(_MZ_CONAN_BUILD missing)
    else()
        set(_MZ_CONAN_BUILD never)
    endif()

    conan_cmake_install(
        PATH_OR_REFERENCE ${_MZ_CONAN_FILE}
        BUILD ${_MZ_CONAN_BUILD}
        PROFILE ${CMAKE_BINARY_DIR}/profile.conan
    )
    # when 'cmake' generator is used, automatically import it
    if(EXISTS ${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
        include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
        conan_basic_setup(TARGETS NO_OUTPUT_DIRS)
        mz_conan_debug("Imported Targets: ${CONAN_TARGETS}")
    endif()
    # when 'cmake_find_package' generator is used, support it as well
    set(CMAKE_MODULE_PATH ${CMAKE_BINARY_DIR} ${CMAKE_MODULE_PATH})
endif()
