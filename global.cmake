#
# global.cmake
#
# Copyright (c) 2008-2018 Marius Zwicker
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
# BUILD/GLOBAL.CMAKE
#
#   This file is for providing a defined environment
# of compiler definitions/macros and cmake functions
# or variables throughout several projects. It can
# be included twice or more without any issues and
#   will automatically included the utility files
#   compiler.cmake and macros.cmake
#
##################################################

### CONFIGURATION SECTION

cmake_minimum_required(VERSION 2.8 FATAL_ERROR)
# CMAKE_CURRENT_LIST_DIR is available after CMake 2.8.3 only
# but we support 2.8.0 as well
if( NOT CMAKE_CURRENT_LIST_DIR )
    string(REPLACE "/global.cmake" "" CMAKE_CURRENT_LIST_DIR "${CMAKE_CURRENT_LIST_FILE}")
endif()

# Set the minimum version to 10.12 on OS X
if(APPLE AND NOT IOS_PLATFORM)
    set( CMAKE_OSX_DEPLOYMENT_TARGET 10.12 )
    message("-- Setting minimum version of OS X to ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

# path to the mz tools files
set(MZ_TOOLS_PATH "${CMAKE_CURRENT_LIST_DIR}")

## We need to ouput everything into the same directory
set(LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR}/bin/ CACHE PATH "Library output path")
set(EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR}/bin/ CACHE PATH "Executable output path")
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
message("-- Setting binary output path: ${CMAKE_BINARY_DIR}/bin/")

### END OF CONFIGURATION SECTION

# BOF: global.cmake
if(NOT HAS_MZ_GLOBAL)
  set(HAS_MZ_GLOBAL true)

  # detect compiler
  include("${MZ_TOOLS_PATH}/compiler.cmake")

  # user info
  message("-- configuring for build type: ${CMAKE_BUILD_TYPE}")

  # macros
  include("${MZ_TOOLS_PATH}/macros.cmake")

  # linter and autoformatting
  include("${MZ_TOOLS_PATH}/linter/autoformat.cmake")

# EOF: global.cmake
endif()
