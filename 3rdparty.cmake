#
# 3rdparty.cmake
#
# Copyright (c) 2019-2020 Marius Zwicker
# All rights reserved.
#
# @LICENSE_HEADER_START@
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
# @LICENSE_HEADER_END@
#

##################################################
#
#   BUILD/3RDPARTY.CMAKE
#
#   Provides a dependency cache for 3rdparty libraries and tools
#   3rdparty deps included into the CMake build tree via the macros
#   defined here will get built outside the tree and cached for later
#   use in other trees using the same deps or persisting beyond full
#   rebuilds so that these go faster.
#
# PROVIDED MACROS
# -----------------------
# mz_3rdparty_cache NAME TARGET
#       establishes a cache for the given target using the given link name
#
#       if the cache exists from a previous inclusion, MZ_3RDPARTY_REBUILD
#       will be set to true else it will be set to false
#
# mz_3rdparty_add TARGET FILE ..
#       adds a new 3rdparty target using the given source file
#
#       Additional arguments are similar to ExternalProject_Add
#
# PROVIDED CMAKE VARIABLES
# -----------------------
# MZ_3RDPARTY_CMAKE_RUNTIME_ARGS runtime variables that should be propagated
#                to a subinstance of cmake invoked from mz_3rdparty_add
# MZ_CMAKE_RUNTIME_ARGS deprecated, use MZ_3RDPARTY_CMAKE_RUNTIME_ARGS
#
########################################################################

# if global.cmake was not included yet, report it
if (NOT HAS_MZ_GLOBAL)
    message(FATAL_ERROR "!! include global.cmake before including this file !!")
endif()

macro(mz_3rdparty_message MSG)
    message("--   3rdparty: ${MSG}")
endmacro()

# BOF: 3rdparty.cmake
if(NOT HAS_MZ_3RDPARTY)
    set(HAS_MZ_3RDPARTY true)
    set(CMAKE_IGNORE_PATH /opt/local/include;/opt/local/lib)

    include(ExternalProject)

    if( DEFINED ENV{MZ_3RDPARTY_MANUAL_BASE} )
        set(MZ_3RDPARTY_BASE $ENV{MZ_3RDPARTY_MANUAL_BASE})
    else()
        set(MZ_3RDPARTY_BASE $ENV{HOME}/.mz-3rdparty)
    endif()
    string(REPLACE "\\" "/" MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE})

    if( IOS_PLATFORM )
        set(MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE}/${IOS_PLATFORM}-${CMAKE_SYSTEM_PROCESSOR})
    else()
        set(MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE}/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR})
    endif()

    # builds default to release so this can be safely shared
    set(MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE}-Rel)

    mz_3rdparty_message("Caching artifacts below ${MZ_3RDPARTY_BASE}")
    file(MAKE_DIRECTORY ${MZ_3RDPARTY_BASE})

# EOF: 3rdparty.cmake
endif()

macro(mz_3rdparty_add TARGET FILE)

    if(MZ_3RDPARTY_REBUILD)
        mz_download_lfs( ${FILE} )

        set(LIST_ARGN "${ARGN}")
        foreach(LOOP_VAR IN LISTS LIST_ARGN)
            if( LOOP_VAR STREQUAL "BINARY_DIR")
                set(HAS_BINARY_DIR)
            endif()
        endforeach()

        # NOTE: CMake started to convert repeated arguments
        #       into a list, so we need to filter arguments specified when invoked
        if( HAS_BINARY_DIR )
            ExternalProject_Add(
                ${TARGET}

                PREFIX "${MZ_3RDPARTY_PREFIX_DIR}"
                SOURCE_DIR "${MZ_3RDPARTY_SOURCE_DIR}"
                BINARY_DIR "${MZ_3RDPARTY_BINARY_DIR}"
                INSTALL_DIR "${MZ_3RDPARTY_INSTALL_DIR}"

                TEST_COMMAND ${MZ_3RDPARTY_TEST_COMMAND}

                BUILD_ALWAYS true

                ${ARGN}
            )
        else()
            ExternalProject_Add(
                ${TARGET}

                PREFIX "${MZ_3RDPARTY_PREFIX_DIR}"
                SOURCE_DIR "${MZ_3RDPARTY_SOURCE_DIR}"
                INSTALL_DIR "${MZ_3RDPARTY_INSTALL_DIR}"

                TEST_COMMAND ${MZ_3RDPARTY_TEST_COMMAND}

                BUILD_ALWAYS true

                ${ARGN}
            )
        endif()
    else()
        add_custom_target(${TARGET}
            COMMAND cmake -E echo "${TARGET} is cached at ${MZ_3RDPARTY_PREFIX_DIR}"
            WORKING_DIRECTORY ${MZ_3RDPARTY_INSTALL_DIR}
        )
    endif()

endmacro()

macro(mz_3rdparty_cache NAME TARGET)

    project(${NAME})

    find_package(Git REQUIRED)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} log --pretty=format:%h -n 1 .
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        OUTPUT_VARIABLE MZ_3RDPARTY_WC_REVISION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    #mz_3rdparty_message("Version #${MZ_3RDPARTY_WC_REVISION} in ${CMAKE_CURRENT_LIST_DIR}")

    set(MZ_3RDPARTY_PREFIX_DIR "${MZ_3RDPARTY_BASE}/${NAME}/${MZ_3RDPARTY_WC_REVISION}")
    set(MZ_3RDPARTY_SOURCE_DIR "${MZ_3RDPARTY_PREFIX_DIR}/source")
    set(MZ_3RDPARTY_BINARY_DIR "${MZ_3RDPARTY_PREFIX_DIR}/src/${TARGET}-build")
    set(MZ_3RDPARTY_INSTALL_DIR "${MZ_3RDPARTY_PREFIX_DIR}")
    set(MZ_3RDPARTY_TEST_COMMAND cmake -E touch ${MZ_3RDPARTY_PREFIX_DIR}/stamp )

    file(GLOB MZ_3RDPARTY_SOURCE_DIR_CONTENTS ${MZ_3RDPARTY_SOURCE_DIR}/*)

    if( EXISTS ${MZ_3RDPARTY_PREFIX_DIR}/stamp )
        mz_3rdparty_message("Reusing ${MZ_3RDPARTY_PREFIX_DIR}")
        set(MZ_3RDPARTY_REBUILD false)
    else()
        mz_3rdparty_message("Building below ${MZ_3RDPARTY_PREFIX_DIR}")
        set(MZ_3RDPARTY_REBUILD true)
    endif()

endmacro()

# having the patch utility is handy
find_host_program(MZ_3RDPARTY_PATCH patch patch.exe
    HINTS "C:/Program Files/Git/usr/bin"
)
if(NOT MZ_3RDPARTY_PATCH)
    mz_error_message("Missing 'patch', cannot continue")
endif()

# automatically switch between nmake and make
if( MZ_WINDOWS )
    set(MZ_3RDPARTY_MAKE nmake)
else()
    set(MZ_3RDPARTY_MAKE make -j8)
endif()

# some properties that need to be set when linking
file(WRITE ${CMAKE_BINARY_DIR}/3rdparty.cmake "
    set_property(GLOBAL PROPERTY MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
    message(\"3rdparty injected: CMAKE_C_FLAGS=\${CMAKE_C_FLAGS}\")
    message(\"3rdparty injected: CMAKE_C_FLAGS_RELEASE=\${CMAKE_C_FLAGS_RELEASE}\")
    message(\"3rdparty injected: CMAKE_C_FLAGS_DEBUG=\${CMAKE_C_FLAGS_DEBUG}\")
    message(\"3rdparty injected: CMAKE_CXX_FLAGS=\${CMAKE_CXX_FLAGS}\")
    message(\"3rdparty injected: CMAKE_CXX_FLAGS_RELEASE=\${CMAKE_CXX_FLAGS_RELEASE}\")
    message(\"3rdparty injected: CMAKE_CXX_FLAGS_RELEASE=\${CMAKE_CXX_FLAGS_RELEASE}\")
    message(\"3rdparty injected: CMAKE_BUILD_TYPE=\${CMAKE_BUILD_TYPE}\")
")

# never use debug flags in a 3rdparty dependency
set(MZ_3RDPARTY_C_FLAGS "${CMAKE_C_FLAGS}")
set(MZ_3RDPARTY_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
string(REPLACE "/DDEBUG=1" " " MZ_3RDPARTY_C_FLAGS ${MZ_3RDPARTY_C_FLAGS})
string(REPLACE "/DDEBUG=1" " " MZ_3RDPARTY_CXX_FLAGS ${MZ_3RDPARTY_CXX_FLAGS})
string(REPLACE "-DDEBUG=1" " " MZ_3RDPARTY_C_FLAGS ${MZ_3RDPARTY_C_FLAGS})
string(REPLACE "-DDEBUG=1" " " MZ_3RDPARTY_CXX_FLAGS ${MZ_3RDPARTY_CXX_FLAGS})

# do never fail due to warnings in a 3rdparty dependency
if( MZ_IS_GCC OR MZ_IS_CLANG )
    set(MZ_3RDPARTY_C_FLAGS "${CMAKE_C_FLAGS} -Wno-error")
    set(MZ_3RDPARTY_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-error")
endif()

set(MZ_3RDPARTY_CMAKE_RUNTIME_ARGS
   # forward all compiler settings
   -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
   -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
   -DCMAKE_C_FLAGS=${MZ_3RDPARTY_C_FLAGS}
   -DCMAKE_C_FLAGS_DEBUG=${CMAKE_C_FLAGS_DEBUG}
   -DCMAKE_C_FLAGS_RELEASE=${CMAKE_C_FLAGS_RELEASE}
   -DCMAKE_CXX_FLAGS=${MZ_3RDPARTY_CXX_FLAGS}
   -DCMAKE_CXX_FLAGS_DEBUG=${CMAKE_CXX_FLAGS_DEBUG}
   -DCMAKE_CXX_FLAGS_RELEASE=${CMAKE_CXX_FLAGS_RELEASE}
   -DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET}
   -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT}
   -DCMAKE_PROJECT_INCLUDE_BEFORE=${CMAKE_BINARY_DIR}/3rdparty.cmake
   # always build 3rdparty deps as Release
   -DCMAKE_BUILD_TYPE=Release
   -DCMAKE_DEBUG_POSTFIX=''
   # forward additional arguments
   ${CMAKE_RUNTIME_ARGS}
)

# deprecated
set(MZ_CMAKE_RUNTIME_ARGS ${MZ_3RDPARTY_CMAKE_RUNTIME_ARGS})