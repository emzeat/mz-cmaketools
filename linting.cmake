#
# linting.cmake
#
# Copyright (c) 2013 - 2023 Marius Zwicker
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
# BUILD/LINTING.CMAKE
#
#   Provides an easy mean to lint and format a file using
#   clang-tidy, clang-format and clazy
#
#   Expects the following variables to be populated in order
#   to pick up the paths of the tools:
#     CLAZY, CLANG_FORMAT, CLANG_TIDY
#
#   Alternatively an attempt will be made to find the
#   package clang-tools-extra
#
#
# PROVIDED MACROS
# -----------------------
# mz_auto_format <target> [<file1> <file2>]...
#   Format and lint the sourcefiles whenever the given target is built.
#   When no explicit sourcefiles are given, all sources the target
#   depends on and ending with (cxx|hpp|cpp|c) will be automatically
#   marked for autoformat
#
########################################################################


########################################################################
## no need to change anything beyond here
########################################################################

mz_include_guard(GLOBAL)
find_package(Git)
find_program(PYTHON3 python3 REQUIRED)

# try to gather the executables first
if( NOT CLANG_TIDY )
    find_package(clang-tools-extra QUIET)
    if(TARGET clang-tools-extra::clang-tidy)
      get_property(CLANG_TIDY TARGET clang-tools-extra::clang-tidy PROPERTY IMPORTED_LOCATION)
    else()
      find_program(CLANG_TIDY clang-tidy QUIET)
    endif()
    if(NOT CLANG_TIDY)
      mz_warning_message("clang-tools-extra package and clang-tidy is unavailable on this platform - linting will be skipped")
    endif()
endif()
if( NOT CLANG_FORMAT )
    find_package(clang-tools-extra QUIET)
    if(TARGET clang-tools-extra::clang-format)
      get_property(CLANG_FORMAT TARGET clang-tools-extra::clang-format PROPERTY IMPORTED_LOCATION)
    else()
      find_program(CLANG_FORMAT clang-format QUIET)
    endif()
    if(NOT CLANG_FORMAT)
      mz_warning_message("clang-tools-extra package and clang-format is unavailable on this platform - formatting will be skipped")
    endif()
endif()
set(RUN_IF ${PYTHON3} ${CMAKE_SOURCE_DIR}/build/run-if.py)

# allow to only lint files changed in the last commit
if( GIT_FOUND )
    set(MZ_DO_CPPLINT_DIFF_DEFAULT ON)
else()
    set(MZ_DO_CPPLINT_DIFF_DEFAULT OFF)
endif()
option(MZ_DO_CPPLINT_DIFF "Run linting on files with changes only" ${MZ_DO_CPPLINT_DIFF_DEFAULT})

# determine the branch or reference to diff against
set(MZ_CPPLINT_DIFF_REFERENCE_DEFAULT origin/master)
if(DEFINED ENV{DRONE_SOURCE_BRANCH} AND DEFINED ENV{DRONE_TARGET_BRANCH})
    # determining what to diff against automatically when on a CI is non trivial
    # as the CI cannot always know the exact number of changes which are new.
    #
    # Compromise is as follows:
    #   - When source and target branches are different, i.e. doing a PR
    #     we diff all changes submitted as part of the PR
    #   - When doing a regular branch build we fall back to testing
    #     the last commit only
    if("$ENV{DRONE_SOURCE_BRANCH}" STREQUAL "$ENV{DRONE_TARGET_BRANCH}")
        set(MZ_CPPLINT_DIFF_REFERENCE_DEFAULT HEAD^)
    elseif("" STREQUAL "$ENV{DRONE_TARGET_BRANCH}")
        # tag event, nothing to diff - we would not be here if there was a failure
        set(MZ_CPPLINT_DIFF_REFERENCE_DEFAULT HEAD)
    else()
        set(MZ_CPPLINT_DIFF_REFERENCE_DEFAULT $ENV{DRONE_TARGET_BRANCH})
    endif()
endif()
set(MZ_DO_CPPLINT_DIFF_REFERENCE ${MZ_CPPLINT_DIFF_REFERENCE_DEFAULT} CACHE STRING "The git reference to compare against for determining changes")

if( CLANG_TIDY )
    option(MZ_DO_CPPLINT "Enable to run clang-tidy on configured targets" ON)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Force enabled by lintin.cmake" FORCE)
endif()
if( CLANG_FORMAT OR CLAZY )
    # default to off in release builds so that we do not alter the code anymore
    if( MZ_IS_RELEASE )
        set(MZ_DO_AUTO_FORMAT_DEFAULT OFF)
    else()
        set(MZ_DO_AUTO_FORMAT_DEFAULT ON)
    endif()
    option(MZ_DO_AUTO_FORMAT "Enable to run clang-format on configured targets" ${MZ_DO_AUTO_FORMAT_DEFAULT})
endif()

if( MZ_DO_CPPLINT_DIFF )
  mz_message("Linting will only consider files changed since '${MZ_DO_CPPLINT_DIFF_REFERENCE}'")
endif()

if( CLANG_TIDY )
  set(RUN_IF_ARGS ${RUN_IF_ARGS} --env CLANG_TIDY=${CLANG_TIDY})
  if( MZ_DO_CPPLINT )
    mz_message("Linting (C++) is enabled")
  else()
    mz_warning_message("Linting (C++) is disabled, this is not recommended")
  endif()

  find_program(CCACHE ccache)
  if(CCACHE)
    set(RUN_IF_ARGS ${RUN_IF_ARGS} --env CCACHE=${CCACHE})
    mz_message("Linting (C++) will be accelerated using ccache")
    set(MZ_CLANG_TIDY
      ${PYTHON3} ${CMAKE_SOURCE_DIR}/build/cache-tidy.py
    )
  else()
    set(MZ_CLANG_TIDY
      ${CLANG_TIDY}
    )
  endif()
endif()

if( Qt5_PREFIX )
  set(QML_LINT ${Qt5_PREFIX}/bin/qmllint)
  if(NOT EXISTS ${QML_LINT})
      set(QML_LINT FALSE)
  endif()
  set(QML_FORMAT ${Qt5_PREFIX}/bin/qmlformat)
  if(NOT EXISTS ${QML_FORMAT})
      set(QML_FORMAT FALSE)
  endif()
endif()

if( QML_LINT )
  if( MZ_DO_CPPLINT )
    mz_message("Linting (QML) is enabled")
  endif()
endif()


macro(mz_auto_format _TARGET)
  set(_sources ${ARGN})
  list(LENGTH _sources arg_count)

  if( NOT arg_count GREATER 0 )
    mz_debug_message("Autoformat was no files given, using the target's sources")
    get_target_property(_sources ${_TARGET} SOURCES)
  endif()

  # filter autogenerated files
  foreach(file ${_sources})
    get_filename_component(abs_file ${file} ABSOLUTE)
    string(REPLACE "${CMAKE_SOURCE_DIR}/" "" rel_file "${abs_file}")
    set(lint_file ${CMAKE_BINARY_DIR}/${rel_file})
    set(RUN_IF_ARGS_file ${RUN_IF_ARGS} --diff "${abs_file}:${MZ_DO_CPPLINT_DIFF_REFERENCE}")

    if( NOT ${file} MATCHES "(ui_|moc_|qrc_|lemon_).+" AND NOT "${file}" MATCHES "${CMAKE_BINARY_DIR}" )

      if( ${file} MATCHES ".+\\.(cpp|cxx)$" )
        if( CLANG_TIDY AND MZ_DO_CPPLINT )
          set(lint_output ${lint_file}.clang-tidy)
          add_custom_command(OUTPUT ${lint_output}
            COMMAND
              ${RUN_IF} ${RUN_IF_ARGS_file} --touch ${lint_output}
              ${MZ_CLANG_TIDY}
              ${CLANG_TIDY_EXTRA_ARGS}
              -p ${CMAKE_BINARY_DIR}
              --checks=-clang-diagnostic-unused-command-line-argument
              --quiet
              ${abs_file}
            DEPENDS ${CMAKE_SOURCE_DIR}/.clang-tidy ${abs_file}
            COMMENT "Linting (C++) ${rel_file}"
            VERBATIM
          )
          target_sources(${_TARGET}
            PRIVATE ${lint_output}
          )
        endif()
      endif()

      if( ${file} MATCHES ".+\\.(qml)$" )
        if( QML_LINT AND MZ_DO_CPPLINT )
          set(lint_output ${lint_file}.qmllint)
          add_custom_command(OUTPUT ${lint_output}
            COMMAND
              ${RUN_IF} ${RUN_IF_ARGS_file} --touch ${lint_output}
              ${QML_LINT}
              ${abs_file}
            DEPENDS ${abs_file}
            COMMENT "Linting (QML) ${rel_file}"
            VERBATIM
          )
          target_sources(${_TARGET}
            PRIVATE ${lint_output}
          )
        endif()
      endif()

      if( ${file} MATCHES ".+\\.(cpp|cxx|hpp|h|c)$" )
        set(format_output ${lint_file}.clang-format)
        if( CLANG_FORMAT AND MZ_DO_AUTO_FORMAT )
          add_custom_command(OUTPUT ${format_output}
            COMMAND
              ${RUN_IF} ${RUN_IF_ARGS_file} --touch ${format_output}
              ${CLANG_FORMAT}
              -i
              ${abs_file}
            DEPENDS ${CMAKE_SOURCE_DIR}/.clang-format ${abs_file}
            COMMENT "Formatting ${rel_file}"
            VERBATIM
          )
          target_sources(${_TARGET}
            PRIVATE ${format_output}
          )
        endif()
      endif()

      if( ${file} MATCHES ".+\\.(qml)$" )
        set(format_output ${lint_file}.qmlformat)
        if( QML_FORMAT AND MZ_DO_AUTO_FORMAT )
          add_custom_command(OUTPUT ${format_output}
            COMMAND
              ${RUN_IF} ${RUN_IF_ARGS_file} --touch ${format_output}
              ${QML_FORMAT}
              -n -i
              ${abs_file}
            DEPENDS ${abs_file}
            COMMENT "Formatting ${rel_file}"
            VERBATIM
          )
          target_sources(${_TARGET}
            PRIVATE ${format_output}
          )
        endif()
      endif()

    endif()
  endforeach()
endmacro()

macro(mz_auto_format_c _TARGET)
   set(__MZ_NO_CPPLINT TRUE)
   mz_auto_format(${_TARGET} ${ARGN})
endmacro()

macro(mz_auto_format_cxx _TARGET)
   set(__MZ_NO_CPPLINT TRUE)
   mz_auto_format(${_TARGET} ${ARGN})
endmacro()
