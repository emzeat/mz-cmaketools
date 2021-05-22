#
# s3storage.cmake
#
# Copyright (c) 2019-2021 Marius Zwicker
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
#   BUILD/S3STORAGE.CMAKE
#
#   Provides macros to upload or download files from an s3 compatible storage
#
# PROVIDED FUNCTIONS
# -----------------------
# mz_s3_download BUCKET FILE <object path> DESTINATION <local file path>
#       Download file from the bucket path and store it at destination
#
#       Requires the following variables to be set in the env or as
#       CMake variables:
#           MZ_S3_ALIAS  Alias by which the S3 server was registered with mc
#
# mz_s3_download BUCKET DIRECTORY <object path> DESTINATION <local directory path>
#       Download directory from the bucket path and store it at destination
#
#       Requires the following variables to be set in the env or as
#       CMake variables:
#           MZ_S3_ALIAS  Alias by which the S3 server was registered with mc
#
# mz_s3_upload BUCKET FILE <local file path> DESTINATION <object path> (PUBLIC)
#       Upload file from the source path to bucket path enabling public
#       access when adding the PUBLIC option
#
#       Requires the following variables to be set in the env or as
#       CMake variables:
#           MZ_S3_ALIAS  Alias by which the S3 server was registered with mc
#
# mz_s3_upload BUCKET DIRECTORY <local directory path> DESTINATION <object path>
#       Upload directory from the source path to bucket path
#
#       Requires the following variables to be set in the env or as
#       CMake variables:
#           MZ_S3_ALIAS  Alias by which the S3 server was registered with mc
#
# PROVIDED CMAKE VARIABLES
# -----------------------
# MZ_S3_INCLUDE_PATH Path to the s3storage.cmake
#
########################################################################

macro(mz_s3_message MSG)
    message("--   S3: ${MSG}")
endmacro()
macro(mz_s3_warning MSG)
    message(WARNING "!!   S3: ${MSG}")
endmacro()
macro(mz_s3_error MSG)
    message(SEND_ERROR "!!   S3: ${MSG}")
endmacro()

# BOF: s3storage.cmake
if(NOT HAS_MZ_S3)
    set(HAS_MZ_S3 true)

    if(NOT MZ_S3_MC)
        find_host_program(MZ_S3_MC mc minio-mc minio-mc.exe)
    endif()
    if(NOT MZ_S3_MC)
        mz_s3_error("Missing minio's 'mc', cannot continue")
    endif()

    set(MZ_S3_INCLUDE_PATH ${CMAKE_CURRENT_LIST_FILE})

# EOF: s3storage.cmake
endif()

macro(_mz_s3_env)
    if(NOT MZ_S3_ALIAS)
        set(MZ_S3_ALIAS $ENV{MZ_S3_ALIAS})
    endif()
    if(NOT MZ_S3_ALIAS)
        mz_s3_error("MZ_S3_ALIAS not defined, cannot continue")
    endif()
    execute_process(
        COMMAND ${MZ_S3_MC} alias list ${MZ_S3_ALIAS}
        OUTPUT_VARIABLE _mz_s3_alias_output
        ERROR_QUIET
        RESULT_VARIABLE _mz_s3_result
    )
    if( _mz_s3_result GREATER "0")
        mz_s3_error("'${MZ_S3_ALIAS}' was not registered with mc.\nTo register use\n\t${MZ_S3_MC} alias set ${MZ_S3_ALIAS} <url> <access_key> <secret_key>\n")
    endif()
    string(REGEX MATCH "URL +: ([^\n\r]+)" _mz_s3_url ${_mz_s3_alias_output})
    set(_mz_s3_url ${CMAKE_MATCH_1})
    set(_mz_s3_archive_ext .zip)
endmacro()

function(mz_s3_download BUCKET)
    _mz_s3_env()

    # see https://cmake.org/cmake/help/v3.18/command/cmake_parse_arguments.html#command:cmake_parse_arguments
    set(_mz_s3_options
        QUIET
    )
    set(_mz_s3_oneValueArgs
        FILE
        DIRECTORY
        DESTINATION
    )
    set(_mz_s3_multiValueArgs
    )
    cmake_parse_arguments( _mz_s3
        "${_mz_s3_options}"
        "${_mz_s3_oneValueArgs}"
        "${_mz_s3_multiValueArgs}"
        ${ARGN}
    )
    if(_mz_s3_UNPARSED_ARGUMENTS)
        mz_s3_error("No such option: ${_mz_s3_UNPARSED_ARGUMENTS}")
    endif()

    if(_mz_s3_DIRECTORY)
        set(_mz_s3_source ${_mz_s3_DIRECTORY}${_mz_s3_archive_ext})
        set(_mz_s3_extract_to ${_mz_s3_DESTINATION})
        set(_mz_s3_DESTINATION ${_mz_s3_DESTINATION}${_mz_s3_archive_ext})
        mz_s3_message("Downloading directory from ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_source}")
    else()
        set(_mz_s3_source ${_mz_s3_FILE})
        mz_s3_message("Downloading file from ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_source}")
    endif()

    if(_mz_s3_QUIET)
        set(_mz_s3_quiet OUTPUT_QUIET ERROR_QUIET)
    else()
        set(_mz_s3_quiet)
    endif()

    execute_process(
        COMMAND ${MZ_S3_MC} cp ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_source} ${_mz_s3_DESTINATION}
        RESULT_VARIABLE _mz_s3_result
        ${_mz_s3_quiet}
    )
    if( _mz_s3_result GREATER "0")
        if(NOT _mz_s3_QUIET)
            mz_s3_error("Download failed")
        endif()
        return()
    endif()
    if( _mz_s3_extract_to )
        file(ARCHIVE_EXTRACT INPUT ${_mz_s3_DESTINATION}
            DESTINATION ${_mz_s3_extract_to}
        )
        file(REMOVE ${_mz_s3_DESTINATION})
    endif()
endfunction()

function(mz_s3_upload BUCKET)
    _mz_s3_env()

    # see https://cmake.org/cmake/help/v3.18/command/cmake_parse_arguments.html#command:cmake_parse_arguments
    set(_mz_s3_options
        PUBLIC
        QUIET
    )
    set(_mz_s3_oneValueArgs
        FILE
        DIRECTORY
        DESTINATION
    )
    set(_mz_s3_multiValueArgs
    )
    cmake_parse_arguments( _mz_s3
        "${_mz_s3_options}"
        "${_mz_s3_oneValueArgs}"
        "${_mz_s3_multiValueArgs}"
        ${ARGN}
    )
    if(_mz_s3_UNPARSED_ARGUMENTS)
        mz_s3_error("No such option: ${_mz_s3_UNPARSED_ARGUMENTS}")
    endif()

    if(_mz_s3_DIRECTORY)
        set(_mz_s3_source ${_mz_s3_DIRECTORY}${_mz_s3_archive_ext})
        set(_mz_s3_DESTINATION ${_mz_s3_DESTINATION}${_mz_s3_archive_ext})
        mz_s3_message("Uploading directory to ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_DESTINATION}")

        file(GLOB _mz_s3_ARCHIVE_CONTENTS
            LIST_DIRECTORIES true
            RELATIVE ${_mz_s3_DIRECTORY}
            ${_mz_s3_DIRECTORY}/*
        )
        # ARCHIVE_CREATE does not allow us to specify a working directory
        execute_process(
            COMMAND ${CMAKE_COMMAND} -E tar cf ${_mz_s3_source} --format=zip -- ${_mz_s3_ARCHIVE_CONTENTS}
            WORKING_DIRECTORY ${_mz_s3_DIRECTORY}
        )
    else()
        set(_mz_s3_source ${_mz_s3_FILE})
        mz_s3_message("Uploading file to ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_DESTINATION}")
    endif()

    if(_mz_s3_QUIET)
        set(_mz_s3_quiet OUTPUT_QUIET ERROR_QUIET)
    else()
        set(_mz_s3_quiet)
    endif()

    execute_process(
        COMMAND ${MZ_S3_MC} cp ${_mz_s3_source} ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_DESTINATION}
        COMMAND_ECHO STDOUT
        ${_mz_s3_quiet}
    )
    if(_mz_s3_DIRECTORY)
        file(REMOVE ${_mz_s3_source})
    endif()
    if( _mz_s3_result GREATER "0")
        if(NOT _mz_s3_QUIET)
            mz_s3_error("Upload failed")
        endif()
        return()
    endif()

    if(_mz_s3_PUBLIC)
        mz_s3_message("Public access via ${_mz_s3_url}/${BUCKET}/${_mz_s3_DESTINATION}")
        execute_process(
            COMMAND ${MZ_S3_MC} policy set download ${MZ_S3_ALIAS}/${BUCKET}/${_mz_s3_DESTINATION}
        )
    endif()
endfunction()