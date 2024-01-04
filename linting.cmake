# linting.cmake
#
# Copyright (c) 2013 - 2024 Marius Zwicker
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

# try to gather the executables first
if( NOT CLANG_TIDY )
    find_package(clang-tools-extra)
    if(TARGET clang-tools-extra::clang-tidy)
      get_property(CLANG_TIDY TARGET clang-tools-extra::clang-tidy PROPERTY IMPORTED_LOCATION)
    else()
      find_program(CLANG_TIDY clang-tidy QUIET)
    endif()
    if(NOT CLANG_TIDY)
      mz_message("clang-tools-extra package and clang-tidy is unavailable on this platform - linting will be skipped")
    endif()
    if(CLANG_TIDY AND "arm64" IN_LIST CMAKE_OSX_ARCHITECTURES AND "x86_64" IN_LIST CMAKE_OSX_ARCHITECTURES)
      mz_message("clang-tidy cannot handle universal builds - linting will be skipped")
      unset(CLANG_TIDY)
    endif()
endif()
if( NOT CLANG_FORMAT )
    find_package(clang-tools-extra)
    if(TARGET clang-tools-extra::clang-format)
      get_property(CLANG_FORMAT TARGET clang-tools-extra::clang-format PROPERTY IMPORTED_LOCATION)
    else()
      find_program(CLANG_FORMAT clang-format QUIET)
    endif()
    if(NOT CLANG_FORMAT)
      mz_warning_message("clang-tools-extra package and clang-format is unavailable on this platform - formatting will be skipped")
    endif()
endif()

if( CLANG_TIDY )
    option(MZ_DO_CPPLINT "Enable to run clang-tidy on configured targets" ON)
    set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Force enabled by linting.cmake" FORCE)
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

if( CLANG_TIDY )
  if( MZ_DO_CPPLINT )
    mz_message("Linting (C++) is enabled")
  else()
    mz_message("!! Linting (C++) is disabled")
  endif()

  find_package(ccache QUIET)
  if(ccache_FOUND)
    # prefer the ccache conan package over system versions
    unset(CCACHE CACHE)
    find_program(CCACHE ccache PATHS ${ccache_PACKAGE_FOLDER_RELEASE}/bin ${ccache_PACKAGE_FOLDER_DEBUG}/bin NO_DEFAULT_PATH)
  else()
    find_program(CCACHE ccache)
  endif()
  find_package(linter-cache QUIET)
  if(linter-cache_FOUND)
    # prefer the ccache conan package over system versions
    unset(LINTER_CACHE CACHE)
    find_program(LINTER_CACHE linter-cache PATHS ${linter-cache_PACKAGE_FOLDER_RELEASE}/bin ${linter-cache_PACKAGE_FOLDER_DEBUG}/bin NO_DEFAULT_PATH)
  else()
    find_program(LINTER_CACHE linter-cache)
  endif()
  if(CCACHE AND LINTER_CACHE)
    if(MZ_DO_CPPLINT)
      mz_message("Linting (C++) will be accelerated using ccache")
    endif()
    list(APPEND MZ_CLANG_TIDY
      ${LINTER_CACHE}
        --ccache=${CCACHE}
        --clang-tidy=${CLANG_TIDY}
    )
  else()
    list(APPEND MZ_CLANG_TIDY
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

  if( CLANG_TIDY AND MZ_DO_CPPLINT )
    foreach(INCL IN LISTS CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES)
        if( MZ_MACOS AND INCL MATCHES ".+c\\+\\+.+" )
            # workaround mixing clang-tidy versions on modern macOS failing
            # to find the C++ system includes by explicitly passing them
            list(APPEND MZ_CLANG_TIDY --extra-arg-before=-isystem${INCL})
        endif()
    endforeach()
    if(CLANG_TIDY_EXTRA_ARGS)
        list(APPEND MZ_CLANG_TIDY ${CLANG_TIDY_EXTRA_ARGS})
    endif()
    # when exclusion is supported make use of the CXX_CLANG_TIDY variable to
    # have CMake handle spawning the linter which has the benefit of running
    # the compiler first and hence catching code errors more quickly
    if(CMAKE_MAJOR_VERSION GREATER_EQUAL 3 AND CMAKE_MINOR_VERSION GREATER_EQUAL 27)
        set_target_properties(${_TARGET} PROPERTIES
            CXX_CLANG_TIDY "${MZ_CLANG_TIDY};-p;${CMAKE_BINARY_DIR};--checks=-clang-diagnostic-unused-command-line-argument;--quiet"
            C_CLANG_TIDY "${MZ_CLANG_TIDY};-p;${CMAKE_BINARY_DIR};--checks=-clang-diagnostic-unused-command-line-argument;--quiet"
        )
        set(MZ_HAVE_SKIP_LINTING TRUE)
    endif()
  endif()

  # filter autogenerated files
  foreach(file ${_sources})
    get_filename_component(abs_file ${file} ABSOLUTE)
    string(REPLACE "${CMAKE_SOURCE_DIR}/" "" rel_file "${abs_file}")
    set(lint_file ${CMAKE_BINARY_DIR}/${rel_file})

    if( file MATCHES "(ui_|moc_|qrc_|lemon_).+" OR file MATCHES "${CMAKE_BINARY_DIR}" )
      if(MZ_HAVE_SKIP_LINTING)
        # skip from linting
        set_source_files_properties(${file} PROPERTIES
            SKIP_LINTING ON
        )
      endif()
    else()

      if( NOT MZ_HAVE_SKIP_LINTING AND ${file} MATCHES ".+\\.(cpp|cxx)$" )
        if( CLANG_TIDY AND MZ_DO_CPPLINT )
          set(lint_output ${lint_file}.clang-tidy)
          add_custom_command(OUTPUT ${lint_output}
            COMMAND
              ${MZ_CLANG_TIDY}
              -p ${CMAKE_BINARY_DIR}
              --checks=-clang-diagnostic-unused-command-line-argument
              --quiet
              ${abs_file}
            COMMAND
              ${CMAKE_COMMAND} -E touch ${lint_output}
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
              ${QML_LINT}
              ${abs_file}
            COMMAND
              ${CMAKE_COMMAND} -E touch ${lint_output}
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
              ${CLANG_FORMAT}
              -i
              ${abs_file}
            COMMAND
              ${CMAKE_COMMAND} -E touch ${format_output}
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
              ${QML_FORMAT}
              -n -i
              ${abs_file}
            COMMAND
              ${CMAKE_COMMAND} -E touch ${format_output}
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
