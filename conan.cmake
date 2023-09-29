#
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
    configure_file(${CMAKE_SOURCE_DIR}/conanfile.txt ${CMAKE_BINARY_DIR}/conanfile.txt)
    set(_MZ_CONAN_FILE ${CMAKE_BINARY_DIR}/conanfile.txt)
elseif(EXISTS ${CMAKE_SOURCE_DIR}/conanfile.py)
    configure_file(${CMAKE_SOURCE_DIR}/conanfile.py ${CMAKE_BINARY_DIR}/conanfile.py)
    set(_MZ_CONAN_FILE ${CMAKE_BINARY_DIR}/conanfile.py)
else()
    mz_conan_warning("No conanfile.(txt|py) - skipping install")
endif()

# will process all conan dependencies and install them
if(_MZ_CONAN_FILE AND NOT CONAN_EXPORTED)
    include(${_MZ_CONAN_DIR}/conan.cmake)

    set(MZ_CONAN_REMOTE_NAME emzeat)
    if(DEFINED ENV{MZ_CONAN_REMOTE_NAME})
        set(MZ_CONAN_REMOTE_NAME $ENV{MZ_CONAN_REMOTE_NAME})
    endif()
    set(MZ_CONAN_REMOTE_URL https://codeberg.org/api/packages/emzeat/conan)
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
        mz_conan_message("Found existing remote '${MZ_CONAN_REMOTE_NAME}'")
    else()
        conan_add_remote(NAME ${MZ_CONAN_REMOTE_NAME}
            URL ${MZ_CONAN_REMOTE_URL}
            ${_MZ_CONAN_REMOTE_ARGS}
            VERIFY_SSL True
        )
    endif()

    if(DEFINED ENV{MZ_CONAN_ALLOW_ANY_REMOTE})
        set(MZ_CONAN_ALLOW_ANY_REMOTE TRUE)
    endif()
    if(NOT MZ_CONAN_ALLOW_ANY_REMOTE)
        mz_conan_message("Forcing use of remote '${MZ_CONAN_REMOTE_NAME}'")
        set(_MZ_CONAN_INSTALL_ARGS ${_MZ_CONAN_INSTALL_ARGS}
            REMOTE ${MZ_CONAN_REMOTE_NAME}
        )
    else()
        mz_conan_message("Will use packages from any remote")
    endif()

    mz_conan_message("Processing profile '${_MZ_CONAN_PROFILE}'")
    list(APPEND MZ_CONAN_ENV CFLAGS="${MZ_3RDPARTY_C_FLAGS}")
    list(APPEND MZ_CONAN_ENV CXXFLAGS="${MZ_3RDPARTY_CXX_FLAGS}")
    list(JOIN MZ_CONAN_ENV "\n" MZ_CONAN_ENV_ITEMS)
    configure_file(${_MZ_CONAN_PROFILE} ${CMAKE_BINARY_DIR}/profile.conan)
    if(_MZ_CONAN_BUILD_PROFILE)
        configure_file(${_MZ_CONAN_BUILD_PROFILE} ${CMAKE_BINARY_DIR}/build_profile.conan)
        set(_MZ_CONAN_INSTALL_ARGS ${_MZ_CONAN_INSTALL_ARGS}
            PROFILE_HOST ${CMAKE_BINARY_DIR}/profile.conan
            PROFILE_BUILD ${CMAKE_BINARY_DIR}/build_profile.conan
        )
    else()
        set(_MZ_CONAN_INSTALL_ARGS ${_MZ_CONAN_INSTALL_ARGS}
            PROFILE ${CMAKE_BINARY_DIR}/profile.conan
        )
    endif()

    option(CONAN_BUILD_MISSING "Automatically build package binaries not on the remote" OFF)
    if(CONAN_BUILD_MISSING)
        mz_conan_message("Will build missing binary packages")
        set(_MZ_CONAN_BUILD missing)
    elseif(CONAN_BUILD_MISSING_RECIPES)
        mz_conan_message("Will build missing binary packages for ${CONAN_BUILD_MISSING_RECIPES}")
        set(_MZ_CONAN_BUILD ${CONAN_BUILD_MISSING_RECIPES})
    else()
        set(_MZ_CONAN_BUILD never OUTPUT_QUIET)
    endif()

    set(MZ_CONAN_INSTALL_DIR ${CMAKE_BINARY_DIR}/conan)

    conan_cmake_install(
        PATH_OR_REFERENCE ${_MZ_CONAN_FILE}
        INSTALL_FOLDER ${MZ_CONAN_INSTALL_DIR}
        BUILD ${_MZ_CONAN_BUILD}
        ${_MZ_CONAN_INSTALL_ARGS}
    )

else()
    if(NOT MZ_CONAN_INSTALL_DIR)
        set(MZ_CONAN_INSTALL_DIR ${CMAKE_BINARY_DIR})
    endif()
    mz_conan_message("Using existing conan environment below '${MZ_CONAN_INSTALL_DIR}'")
endif()

# reduce the verbosity when finding packages
set(CONAN_CMAKE_SILENT_OUTPUT ON)

# when 'cmake' generator is used, automatically import it
if(EXISTS ${MZ_CONAN_INSTALL_DIR}/conanbuildinfo.cmake)
    include(${MZ_CONAN_INSTALL_DIR}/conanbuildinfo.cmake)
    conan_basic_setup(TARGETS NO_OUTPUT_DIRS)
    mz_conan_debug("Imported Targets: ${CONAN_TARGETS}")
endif()
# when 'cmake_paths' generator is used, automatically import it
if(EXISTS ${MZ_CONAN_INSTALL_DIR}/conan_paths.cmake)
    include(${MZ_CONAN_INSTALL_DIR}/conan_paths.cmake)
# elsewise add the module path to support the 'cmake_find_package' generator
else()
    set(CMAKE_MODULE_PATH ${MZ_CONAN_INSTALL_DIR} ${CMAKE_MODULE_PATH})
endif()
# fixup the env to parse reliably
if(MZ_WINDOWS)
    string(REPLACE "\\" "/" _MZ_PATH "$ENV{PATH}")
endif()
# also make sure to import any binaries from packages to the path
# by parsing the JSON info available
set(MZ_CONAN_BUILD_INFO ${MZ_CONAN_INSTALL_DIR}/conanbuildinfo.json)
if(NOT EXISTS ${MZ_CONAN_BUILD_INFO})
    set(MZ_CONAN_BUILD_INFO ${CMAKE_BINARY_DIR}/conanbuildinfo.json)
endif()
if(EXISTS ${MZ_CONAN_BUILD_INFO})
    if(MZ_WINDOWS)
        set(_MZ_PATH_SEP ";")
    else()
        set(_MZ_PATH_SEP ":")
    endif()
    file(READ ${MZ_CONAN_BUILD_INFO} _MZ_CONAN_BUILD_INFO_JSON)
    # pull deps_env_info/PATH
    string(JSON _MZ_CONAN_DEPS_COUNT LENGTH "${_MZ_CONAN_BUILD_INFO_JSON}" deps_env_info PATH)
    if(_MZ_CONAN_DEPS_COUNT GREATER 0)
        foreach(_MZ_PATH_INDEX RANGE 1 ${_MZ_CONAN_DEPS_COUNT})
            math(EXPR _MZ_PATH_INDEX "${_MZ_PATH_INDEX} - 1")
            string(JSON _MZ_CONAN_PATH_ENTRY GET "${_MZ_CONAN_BUILD_INFO_JSON}" deps_env_info PATH ${_MZ_PATH_INDEX})
            list(APPEND _MZ_CONAN_PATH "${_MZ_CONAN_PATH_ENTRY}")
        endforeach()
    endif()
    # pull the contents of all dependencies/*/bin_paths as well because consuming only
    # deps_env_info/PATHS is not transitive for subdependencies
    string(JSON _MZ_CONAN_DEPS_COUNT LENGTH "${_MZ_CONAN_BUILD_INFO_JSON}" dependencies)
    if(_MZ_CONAN_DEPS_COUNT GREATER 0)
        foreach(_MZ_DEP_INDEX RANGE 1 ${_MZ_CONAN_DEPS_COUNT})
            math(EXPR _MZ_DEP_INDEX "${_MZ_DEP_INDEX} - 1")
            string(JSON _MZ_CONAN_PATH_COUNT LENGTH "${_MZ_CONAN_BUILD_INFO_JSON}" dependencies ${_MZ_DEP_INDEX} bin_paths)
            if(_MZ_CONAN_PATH_COUNT GREATER 0)
                foreach(_MZ_PATH_INDEX RANGE 1 ${_MZ_CONAN_PATH_COUNT})
                    math(EXPR _MZ_PATH_INDEX "${_MZ_PATH_INDEX} - 1")
                    string(JSON _MZ_CONAN_PATH_ENTRY GET "${_MZ_CONAN_BUILD_INFO_JSON}" dependencies ${_MZ_DEP_INDEX} bin_paths ${_MZ_PATH_INDEX})
                    list(APPEND _MZ_CONAN_PATH "${_MZ_CONAN_PATH_ENTRY}")
                endforeach()
            endif()
        endforeach()
    endif()
    # convert backslashes to all forward slashes
    list(REMOVE_DUPLICATES _MZ_CONAN_PATH)
    list(TRANSFORM _MZ_CONAN_PATH REPLACE "\\\\" "/")
    # join using path sep
    list(JOIN _MZ_CONAN_PATH "${_MZ_PATH_SEP}" _MZ_CONAN_PATH)
    # update env
    set(ENV{PATH} "${_MZ_CONAN_PATH}${_MZ_PATH_SEP}$ENV{PATH}")
else()
    mz_conan_warning("Please enable the 'json' generator")
    if(MZ_WINDOWS)
        set(ENV{PATH} "${EXECUTABLE_OUTPUT_PATH};$ENV{PATH}")
    endif()
endif()

include(${MZ_TOOLS_PATH}/presets.cmake)
