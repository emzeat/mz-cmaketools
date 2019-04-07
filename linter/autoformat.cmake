#
# autoformat.cmake
#
# Copyright (c) 2013-2018 Marius Zwicker
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
# BUILD/AUTOFORMAT.CMAKE
#
#   Provides an easy mean to lint and format a file using
#   the astyle tool and cpplint.py
#
#
# PROVIDED MACROS
# -----------------------
# mz_auto_format <target> [<file1> <file2>]...
#   Format the sourcefiles whenever the given target is built.
#   When no explicit sourcefiles are given, all sources the target
#   depends on and ending with (cxx|hpp|cpp|c) will be automatically
#   marked for autoformat
#
########################################################################


########################################################################
## no need to change anything beyond here
########################################################################

if( MZ_TOOLS_PATH )
  set(MZ_TOOLS_LINTER_PATH ${MZ_TOOLS_PATH}/linter)
else()
  set(MZ_TOOLS_LINTER_PATH ${CMAKE_CURRENT_LIST_DIR})
endif()

find_host_program(
    MZ_ASTYLE_BIN
    astyle
)
find_host_program(
    MZ_PYTHON_BIN
    python
)

if(NOT WINDOWS AND MZ_PYTHON_BIN)
  set(MZ_CPPLINT_BIN ${MZ_TOOLS_LINTER_PATH}/cpplint.py CACHE PATH "Path to cpplint" FORCE)
endif()

if( MZ_ASTYLE_BIN )
  set(MZ_CPPFORMAT_BIN MZ_ASTYLE_BIN CACHE PATH "Path to astyle" FORCE)
endif()

if( MZ_CPPLINT_BIN )
    if( MZ_IS_RELEASE )
        option(MZ_DO_CPPLINT "Enable to run cpplint on configured targets" OFF)
    else()
        option(MZ_DO_CPPLINT "Enable to run cpplint on configured targets" ON)
    endif()
endif()
if( MZ_ASTYLE_BIN )
    option(MZ_DO_AUTO_FORMAT "Enable to run autoformat on configured targets" OFF)
endif()

macro(mz_auto_format _TARGET)
  set(_sources ${ARGN})
  list(LENGTH _sources arg_count)

  if( NOT arg_count GREATER 0 )
    mz_debug_message("Autoformat was no files given, using the target's sources")
    get_target_property(_sources ${_TARGET} SOURCES)
  endif()

  # remove readability/alt_tokens again when the bug of cpplint detecting "and" within comments is fixed
  set(CPPLINT_FILTERS
    -whitespace,-build/header_guard,-build/include,-build/include_what_you_use,-readability/multiline_comment,-readability/namespace,-readability/streams,-runtime/references,-runtime/threadsafe_fn,-readability/alt_tokens
  )

  set(_cpp_sources "")
  foreach(file ${_sources})
    get_filename_component(abs_file ${file} ABSOLUTE)
    if( ${file} MATCHES ".+\\.(cpp|cxx|hpp|h|c)$" AND NOT ${file} MATCHES "(ui_|moc_|qrc_|lemon_).+" AND NOT "${file}" MATCHES "${CMAKE_BINARY_DIR}" )
        set(_cpp_sources ${_cpp_sources} ${abs_file})
    endif()
  endforeach()

  if( MZ_DO_AUTO_FORMAT )
    add_custom_command(TARGET ${_TARGET} PRE_BUILD
        COMMAND ${MZ_ASTYLE_BIN}
            -n -z2 -Q # --lineend=linux
            -A1 # --style=break
            -s4 # --indent=spaces=4
            -Y  # --indent-col1-comments
            -m0 # --min-conditional-indent=0
            -p  # --pad-oper
            -D  # --pad-paren-in
            -U  # --unpad-paren
            -k1 # --align-pointer=type
            -W1 # --align-reference=type
            -j  # --add-brackets
            -c  # --convert-tabs
            -xW # --indent-preproc-block
            ${_cpp_sources}
        DEPENDS ${_sources}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    )
  endif()
  if( MZ_DO_CPPLINT AND NOT __MZ_NO_CPPLINT )
    add_custom_command(TARGET ${_TARGET} PRE_BUILD
        COMMAND ${MZ_CPPLINT_BIN} --root=${CMAKE_CURRENT_LIST_DIR} --filter=${CPPLINT_FILTERS} --quiet --output=eclipse ${_cpp_sources}
        DEPENDS ${_sources}
        WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    )
  endif()
endmacro()

macro(mz_auto_format_c _TARGET)
   set(__MZ_NO_CPPLINT TRUE)
   mz_auto_format(${_TARGET} ${ARGN})
endmacro()

macro(mz_auto_format_cxx _TARGET)
   set(__MZ_NO_CPPLINT TRUE)
   mz_auto_format(${_TARGET} ${ARGN})
endmacro()
