#
# UseDebugSymbols.cmake
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

# - Generate debug symbols in a separate file
#
# (1) Include this file in your CMakeLists.txt; it will setup everything
#     to compile WITH debug symbols in any case.
#
# (2) Run the strip_debug_symbols function on every target that you want
#     to strip.

# only debugging using the GNU toolchain is supported for now
if(MZ_IS_GCC)
  # extracting the debug info is done by a separate utility in the GNU
  # toolchain. check that this is actually installed.
  if(MZ_MACOS OR MZ_IOS)
    # MacOS X has a duo of utilities; we need both
    message(STATUS "Looking for strip utility")
    find_host_program(DSYMUTIL dsymutil)
    mark_as_advanced(DSYMUTIL)
    if(DSYMUTIL)
      message(STATUS "Looking for dsymutil - found")
    else()
      message(WARNING "Looking for dsymutil - not found")
    endif()
    find_host_program(STRIP strip)
    mark_as_advanced(STRIP)
    if(NOT DSYMUTIL)
      set(STRIP strip-NOTFOUND)
    endif()
    if(STRIP)
        message(STATUS "Looking for strip - found")
    else()
        message(WARNING "Looking for strip - not found")
    endif()
  else()
    find_program(OBJCOPY objcopy)
    mark_as_advanced(OBJCOPY)
    if(OBJCOPY)
        message(STATUS "Looking for objcopy - found")
    else()
        message(WARNING "Looking for objcopy - not found")
    endif()
    find_program(STRIP strip)
    mark_as_advanced(STRIP)
    if(NOT OBJCOPY)
      set(STRIP strip-NOTFOUND)
    endif()
    if(STRIP)
        message(STATUS "Looking for strip - found")
    else()
        message(WARNING "Looking for strip - not found")
    endif()
  endif()
endif ()

# command to separate the debug information from the executable into
# its own file; this must be called for each target; optionally takes
# the name of a variable to receive the list of .debug files
function(strip_debug_symbols targets)
  if(MZ_IS_GCC AND STRIP)
    foreach(target IN LISTS targets)
      # libraries must retain the symbols in order to link to them, but
      # everything can be stripped in an executable
      get_target_property(MZ_KIND ${target} TYPE)

      # don't strip static libraries
      if("${MZ_KIND}" STREQUAL "STATIC_LIBRARY")
        return ()
      endif ()

      if(MZ_MACOS OR MZ_IOS)
        get_target_property(MZ_IS_BUNDLE ${target} MACOSX_BUNDLE_INFO_PLIST )
        get_target_property(MZ_IS_FRAMEWORK ${target} FRAMEWORK )
        if( MZ_IS_FRAMEWORK OR MZ_IS_BUNDLE )
          add_custom_command(TARGET ${target}
            POST_BUILD
            WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
            COMMAND ${DSYMUTIL} ARGS --out=$<TARGET_BUNDLE_DIR:${target}>.dSYM $<TARGET_FILE:${target}>
            COMMAND ${STRIP} ARGS -S $<TARGET_FILE:${target}>
            VERBATIM
          )
        else()
          add_custom_command(TARGET ${target}
            POST_BUILD
            WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
            COMMAND ${DSYMUTIL} ARGS --out=${EXECUTABLE_OUTPUT_PATH}/$<TARGET_FILE_NAME:${target}>.dSYM $<TARGET_FILE:${target}>
            COMMAND ${STRIP} ARGS -S $<TARGET_FILE:${target}>
            VERBATIM
          )
        endif()
      else()
          add_custom_command (TARGET ${target}
            POST_BUILD
            WORKING_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
            COMMAND ${OBJCOPY} ARGS --only-keep-debug $<TARGET_FILE:${target}> ${EXECUTABLE_OUTPUT_PATH}/$<TARGET_FILE_NAME:${target}>.debug
            COMMAND ${STRIP} ARGS --strip-debug --strip-unneeded $<TARGET_FILE:${target}>
            COMMAND ${OBJCOPY} ARGS --add-gnu-debuglink=${EXECUTABLE_OUTPUT_PATH}/$<TARGET_FILE_NAME:${target}>.debug $<TARGET_FILE:${target}>
            VERBATIM
          )
      endif()
    endforeach()
  endif()
endfunction()
