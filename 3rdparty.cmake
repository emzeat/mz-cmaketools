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
#   When you have minio's mc in your path, specify
#       MZ_S3_ALIAS for one of mc's aliases
#       MZ_3RDPARTY_S3_BUCKET with a bucket name
#   to enable caching of build artifacts on the s3 server
#
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
# mz_3rdparty_add_flag PLATFORM FLAG ..
#       adds a compler flag for the upcoming 3rdparty target
#
# mz_3rdparty_add_c_flag PLATFORM FLAG ..
#       adds a C compler flag for the upcoming 3rdparty target
#
# mz_3rdparty_add_cxx_flag PLATFORM FLAG ..
#       adds a CXX compler flag for the upcoming 3rdparty target
#
# mz_3rdparty_add_definition DEFINE ..
#       adds a compler definition for the upcoming 3rdparty target
#
# mz_3rdparty_import_library TARGET LOCATION INCLUDES
#       imports an externally buitl library at LOCATION requiring
#       the given INCLUDES to be used as include path
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
    mz_message("  3rdparty: ${MSG}")
endmacro()
macro(mz_3rdparty_warning MSG)
    mz_warning_message("  3rdparty: ${MSG}")
endmacro()

# BOF: 3rdparty.cmake
if(NOT HAS_MZ_3RDPARTY)
    set(HAS_MZ_3RDPARTY true)
    set(CMAKE_IGNORE_PATH /opt/local/include;/opt/local/lib)

    if(MZ_3RDPARTY_S3_BUCKET)
        include(${CMAKE_CURRENT_LIST_DIR}/s3storage.cmake)
    endif()

    include(ExternalProject)
    find_package(Git REQUIRED)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} log --pretty=format:%h -n 1 .
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        OUTPUT_VARIABLE MZ_3RDPARTY_VERSION
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    mz_3rdparty_message("Version '${MZ_3RDPARTY_VERSION}'")

    if( DEFINED ENV{MZ_3RDPARTY_MANUAL_BASE} )
        set(MZ_3RDPARTY_BASE $ENV{MZ_3RDPARTY_MANUAL_BASE})
    else()
        set(MZ_3RDPARTY_BASE $ENV{HOME}/.mz-3rdparty)
    endif()
    string(REPLACE "\\" "/" MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE})
    set(MZ_3RDPARTY_ROOT ${MZ_3RDPARTY_BASE})

    if( IOS_PLATFORM )
        set(MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE}/${IOS_PLATFORM}-${CMAKE_SYSTEM_PROCESSOR})
    else()
        set(MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE}/${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR})
    endif()

    # builds default to release so this can be safely shared
    set(MZ_3RDPARTY_BASE ${MZ_3RDPARTY_BASE}-Rel)

    mz_3rdparty_message("Caching artifacts below ${MZ_3RDPARTY_BASE}")
    file(MAKE_DIRECTORY ${MZ_3RDPARTY_BASE})

    # aggregate the license information
    set(MZ_3RDPARTY_VERSION_TXT ${EXECUTABLE_OUTPUT_PATH}/3rdparty.txt)
    file(WRITE ${MZ_3RDPARTY_VERSION_TXT}
        "3rdparty dependencies used in this program\n"
        "==========================================\n\n"
    )

    # add a helper script to force bump the stamp version
    set(MZ_3RDPARTY_BUMP_STAMP_SH ${CMAKE_BINARY_DIR}/mz_3rdparty_bump_stamp.sh)
    file(WRITE ${MZ_3RDPARTY_BUMP_STAMP_SH}
        "#!/usr/bin/env bash\n"
        "#\n"
        "# Use this script to silence warnings about 3rdparty cache entries\n"
        "# using an outdated version of the build macros.\n"
        "#\n"
        "# WARNING: Only do this when you are sure no incompatibilities\n\n"
    )

    # add a helper script to remove unused builds
    set(MZ_3RDPARTY_GC_SH ${CMAKE_BINARY_DIR}/mz_3rdparty_gc.sh)
    file(WRITE ${MZ_3RDPARTY_GC_SH}
        "#!/usr/bin/env bash\n"
        "#\n"
        "# Use this script to remove stale 3rdparty cache entries.\n\n"
        "echo \"3rdparty CACHE Garbage Collection\"\n"
    )

    # add a helper script to upload binaries
    set(MZ_3RDPARTY_UPLOAD_SH ${CMAKE_BINARY_DIR}/mz_3rdparty_upload.sh)
    file(WRITE ${MZ_3RDPARTY_UPLOAD_SH}
        "#!/usr/bin/env bash\n"
        "#\n"
        "# Use this script to re-upload binaries to the 3rdparty cache for sharing.\n\n"
        "echo \"3rdparty CACHE Reuploading binaries\"\n"
    )

# EOF: 3rdparty.cmake
endif()

macro(mz_3rdparty_add TARGET FILE)

    # see https://cmake.org/cmake/help/v3.18/command/cmake_parse_arguments.html#command:cmake_parse_arguments
    set(_mz3_options
        BUILD_ALWAYS
    )
    set(_mz3_oneValueArgs
        PREFIX
        SOURCE_DIR
        BINARY_DIR
        INSTALL_DIR
        TEST_COMMAND
    )
    set(_mz3_multiValueArgs
    )
    cmake_parse_arguments( _mz3
        "${_mz3_options}"
        "${_mz3_oneValueArgs}"
        "${_mz3_multiValueArgs}"
        ${ARGN}
    )

    if( _mz3_BINARY_DIR )
        set( MZ_3RDPARTY_BINARY_DIR ${_mz3_BINARY_DIR} )
    endif()
    if( _mz3_SOURCE_DIR )
        set( MZ_3RDPARTY_SOURCE_DIR ${_mz3_SOURCE_DIR} )
    endif()

    if(MZ_3RDPARTY_REBUILD)
        mz_download_lfs( ${FILE} )

        ExternalProject_Add(
            ${TARGET}

            PREFIX "${MZ_3RDPARTY_PREFIX_DIR}"
            SOURCE_DIR "${MZ_3RDPARTY_SOURCE_DIR}"
            BINARY_DIR "${MZ_3RDPARTY_BINARY_DIR}"
            INSTALL_DIR "${MZ_3RDPARTY_INSTALL_DIR}"

            TEST_COMMAND ${MZ_3RDPARTY_TEST_COMMAND}

            BUILD_ALWAYS true

            ${_mz3_UNPARSED_ARGUMENTS}
        )
    else()
        file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/deploy-${TARGET}.cmake
            "file(GLOB 3rdparty_install_lib_shared"
            "   ${MZ_3RDPARTY_INSTALL_DIR}/lib/*${CMAKE_SHARED_LIBRARY_SUFFIX}"
            ")\n"
            "if( 3rdparty_install_lib_shared )\n"
            "   file(INSTALL \${3rdparty_install_lib_shared} DESTINATION ${LIBRARY_OUTPUT_PATH})\n"
            "endif()\n"
            "file(GLOB 3rdparty_install_bin_shared"
            "   ${MZ_3RDPARTY_INSTALL_DIR}/bin/*${CMAKE_SHARED_LIBRARY_SUFFIX}"
            ")\n"
            "if( 3rdparty_install_bin_shared )\n"
            "   file(INSTALL \${3rdparty_install_bin_shared} DESTINATION ${EXECUTABLE_OUTPUT_PATH})\n"
            "endif()\n"
        )
        add_custom_target(${TARGET}
            COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/deploy-${TARGET}.cmake
            WORKING_DIRECTORY ${MZ_3RDPARTY_INSTALL_DIR}
        )
    endif()

endmacro()

macro(mz_3rdparty_cache NAME TARGET)

    project(${NAME})

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
    string(REPLACE ${MZ_3RDPARTY_ROOT}/ "" MZ_3RDPARTY_OBJECT_PATH ${MZ_3RDPARTY_PREFIX_DIR})

    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/stamp-${TARGET}.cmake
        "file(WRITE ${MZ_3RDPARTY_PREFIX_DIR}/stamp \"${MZ_3RDPARTY_VERSION}\")\n"
    )
    if(MZ_3RDPARTY_S3_BUCKET)
        file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/stamp-${TARGET}.cmake
            "set(MZ_S3_ALIAS ${MZ_S3_ALIAS})\n"
            "set(MZ_S3_MC ${MZ_S3_MC})\n"
            "include(${MZ_S3_INCLUDE_PATH})\n"
            "mz_s3_upload(${MZ_3RDPARTY_S3_BUCKET}\n"
            "   DIRECTORY ${MZ_3RDPARTY_PREFIX_DIR}\n"
            "   DESTINATION ${MZ_3RDPARTY_OBJECT_PATH}\n"
            "   PUBLIC\n"
            ")\n"
        )
    endif()
    set(MZ_3RDPARTY_TEST_COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/stamp-${TARGET}.cmake )

    file(GLOB MZ_3RDPARTY_SOURCE_DIR_CONTENTS ${MZ_3RDPARTY_SOURCE_DIR}/*)

    if( NOT EXISTS ${MZ_3RDPARTY_PREFIX_DIR} AND MZ_3RDPARTY_S3_BUCKET )
        mz_3rdparty_message("Trying to fetch binaries from cache")
        mz_s3_download(${MZ_3RDPARTY_S3_BUCKET}
            DIRECTORY ${MZ_3RDPARTY_OBJECT_PATH}
            DESTINATION ${MZ_3RDPARTY_PREFIX_DIR}
            QUIET
        )
    endif()

    if( EXISTS ${MZ_3RDPARTY_PREFIX_DIR}/stamp )
        mz_3rdparty_message("Reusing ${MZ_3RDPARTY_PREFIX_DIR}")
        set(MZ_3RDPARTY_REBUILD false)

        file(STRINGS ${MZ_3RDPARTY_PREFIX_DIR}/stamp MZ_3RDPARTY_CACHED_VERSION LIMIT_COUNT 1)
        if( NOT MZ_3RDPARTY_CACHED_VERSION STREQUAL MZ_3RDPARTY_VERSION )
            mz_3rdparty_warning( "Cache built with outdated version '${MZ_3RDPARTY_CACHED_VERSION}'" )

            # add to the helper script to force bump the stamp version
            file(APPEND ${MZ_3RDPARTY_BUMP_STAMP_SH}
                "echo \"+ Bumping ${TARGET} to ${MZ_3RDPARTY_VERSION}\"\n"
                "\"${CMAKE_COMMAND}\" -E echo \"${MZ_3RDPARTY_VERSION}\" > ${MZ_3RDPARTY_PREFIX_DIR}/stamp\n"
            )
        endif()
    else()
        mz_3rdparty_message("Building below ${MZ_3RDPARTY_PREFIX_DIR}")
        set(MZ_3RDPARTY_REBUILD true)
    endif()

    # collect licensing data
    if(NOT MZ_3RDPARTY_EXCLUDE_LICENSE)
        set(${TARGET}_LICENSE ${CMAKE_CURRENT_LIST_DIR}/LICENSE)
        if( NOT EXISTS "${${TARGET}_LICENSE}" )
            mz_3rdparty_warning("No license for ${TARGET}")
            set(${TARGET}_LICENSE "n/a")
        else()
            file(READ ${${TARGET}_LICENSE} ${TARGET}_LICENSE)
        endif()
        file(APPEND ${MZ_3RDPARTY_VERSION_TXT}
            "${TARGET}\n"
            "------------------------------------------\n"
            "${${TARGET}_LICENSE}\n\n\n"
        )
    endif()

    # add a helper script to remove unused builds
    file(APPEND ${MZ_3RDPARTY_GC_SH}
        "for d in ${MZ_3RDPARTY_BASE}/${NAME}/*;\n"
        "do\n"
        "   if [[ \"$d\" == \"${MZ_3RDPARTY_PREFIX_DIR}\" ]];\n"
        "   then\n"
        "      echo \"+ Keeping $d\"\n"
        "   else\n"
        "      echo \"- Removing $d\"\n"
        "      rm -r $d\n"
        "   fi\n"
        "done\n"
    )

    # add a helper script to upload builds
    if(MZ_3RDPARTY_S3_BUCKET)
        file(APPEND ${MZ_3RDPARTY_UPLOAD_SH}
            "echo \"+ Uploading ${TARGET}\"\n"
            "${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/stamp-${TARGET}.cmake\n"
        )
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
    message(\"3rdparty injected: CMAKE_C_COMPILER=\${CMAKE_C_COMPILER}\")
    message(\"3rdparty injected: CMAKE_CXX_COMPILER=\${CMAKE_CXX_COMPILER}\")
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
    set(MZ_3RDPARTY_C_FLAGS "${MZ_3RDPARTY_C_FLAGS} -Wno-error")
    set(MZ_3RDPARTY_CXX_FLAGS "${MZ_3RDPARTY_CXX_FLAGS} -Wno-error")
endif()

# make sure we can link all our code to shared libs
if(MZ_LINUX)
    set(MZ_3RDPARTY_C_FLAGS "${MZ_3RDPARTY_C_FLAGS} -fPIC")
    set(MZ_3RDPARTY_CXX_FLAGS "${MZ_3RDPARTY_CXX_FLAGS} -fPIC")
endif()

macro(__mz_3rdparty_update_runtime_args)
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
endmacro()

__mz_3rdparty_update_runtime_args()

macro(mz_3rdparty_add_cxx_flag PLATFORM)
    __mz_add_compiler_flag(MZ_3RDPARTY_CXX_FLAGS ${PLATFORM} ${ARGN})
    __mz_3rdparty_update_runtime_args()
endmacro()

macro(mz_3rdparty_add_c_flag PLATFORM)
    __mz_add_compiler_flag(MZ_3RDPARTY_C_FLAGS ${PLATFORM} ${ARGN})
    __mz_3rdparty_update_runtime_args()
endmacro()

macro(mz_3rdparty_add_flag PLATFORM)
    __mz_add_compiler_flag(MZ_3RDPARTY_CXX_FLAGS ${PLATFORM} ${ARGN})
    __mz_add_compiler_flag(MZ_3RDPARTY_C_FLAGS ${PLATFORM} ${ARGN})
    __mz_3rdparty_update_runtime_args()
endmacro()

macro(mz_3rdparty_add_definition)
    foreach(DEF ${ARGN})
        if(MZ_IS_GCC)
            mz_3rdparty_add_flag(ALL "-D${DEF}")
        elseif(MZ_IS_VS)
            mz_3rdparty_add_flag(ALL "/D${DEF}")
        endif()
    endforeach()
endmacro()

macro(mz_3rdparty_import_library TARGET LOCATION INCLUDES)
    foreach(INCLUDE ${INCLUDES})
        file(MAKE_DIRECTORY ${INCLUDE})
    endforeach()

    if(NOT EXISTS "${LOCATION}")
      file(WRITE ${LOCATION} "0")
    endif()

    add_library( ${TARGET} STATIC IMPORTED GLOBAL )
    set_target_properties( ${TARGET} PROPERTIES
        IMPORTED_LOCATION "${LOCATION}"
        INTERFACE_INCLUDE_DIRECTORIES ${INCLUDES}
    )
endmacro()
