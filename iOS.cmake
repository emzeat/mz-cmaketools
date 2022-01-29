#
# iOS.cmake
#
# Copyright (c) 2014 , Bogdan Cristea and LTE Engineering Software,
# Copyright (c) 2016 Bogdan Cristea <cristeab@gmail.com>
# Copyright (c) 2022 Marius Zwicker
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

# This file is part of the ios-cmake project. It was retrieved from
# https://github.com/cristeab/ios-cmake.git, which is a fork of
# https://code.google.com/p/ios-cmake/. Which in turn is based off of
# the Platform/Darwin.cmake and Platform/UnixPaths.cmake files which
# are included with CMake 2.8.4
#
# The ios-cmake project is licensed under the new BSD license.
#
# Copyright (c) 2014, Bogdan Cristea and LTE Engineering Software,
# Kitware, Inc., Insight Software Consortium.  All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# This file is based off of the Platform/Darwin.cmake and
# Platform/UnixPaths.cmake files which are included with CMake 2.8.4
# It has been altered for iOS development.
#
# Updated by Alex Stewart (alexs.mac@gmail.com)
#
# *****************************************************************************
#      Now maintained by Alexander Widerberg (widerbergaren [at] gmail.com)
#                      under the BSD-3-Clause license
#                   https://github.com/leetal/ios-cmake
# *****************************************************************************
#
#                           INFORMATION / HELP
#
# The following variables control the behaviour of this toolchain:
#
# IOS_PLATFORM: OS (default) or SIMULATOR or SIMULATOR64 or TVOS or SIMULATOR_TVOS or WATCHOS or SIMULATOR_WATCHOS
#    OS = Build for iPhoneOS.
#    OS64 = Build for arm64 arm64e iPhoneOS.
#    SIMULATOR = Build for x86 i386 iPhone Simulator.
#    SIMULATOR64 = Build for x86_64 iPhone Simulator.
#    TVOS = Build for AppleTVOS.
#    SIMULATOR_TVOS = Build for x86_64 AppleTV Simulator.
#    WATCHOS = Build for armv7k arm64_32 for WatchOS.
#    SIMULATOR_WATCHOS = Build for x86_64 for Watch Simulator.
# CMAKE_OSX_SYSROOT: Path to the iOS SDK to use.  By default this is
#    automatically determined from IOS_PLATFORM and xcodebuild, but
#    can also be manually specified (although this should not be required).
# CMAKE_IOS_DEVELOPER_ROOT: Path to the Developer directory for the iOS platform
#    being compiled for.  By default this is automatically determined from
#    CMAKE_OSX_SYSROOT, but can also be manually specified (although this should
#    not be required).
# ENABLE_BITCODE: (1|0) Enables or disables bitcode support. Default 1 (true)
# ENABLE_ARC: (1|0) Enables or disables ARC support. Default 1 (true, ARC enabled by default)
# ENABLE_VISIBILITY: (1|0) Enables or disables symbol visibility support. Default 0 (false, visibility hidden by default)
# IOS_ARCH: (armv7 armv7s armv7k arm64 arm64e arm64_32 i386 x86_64) If specified, will override the default architectures for the given IOS_PLATFORM
#    OS = armv7 armv7s arm64 arm64e (if applicable)
#    OS64 = arm64 arm64e (if applicable)
#    SIMULATOR = i386
#    SIMULATOR64 = x86_64
#    TVOS = arm64
#    SIMULATOR_TVOS = x86_64 (i386 has since long been deprecated)
#    WATCHOS = armv7k arm64_32 (if applicable)
#    SIMULATOR_WATCHOS = x86_64 (i386 has since long been deprecated)
#
# This toolchain defines the following variables for use externally:
#
# XCODE_VERSION: Version number (not including Build version) of Xcode detected.
# IOS_SDK_VERSION: Version of iOS SDK being used.
# CMAKE_OSX_ARCHITECTURES: Architectures being compiled for (generated from
#    IOS_PLATFORM).
# CMAKE_RUNTIME_ARGS: Arguments to pass to cmake invoked through ExternalProject
#                     in order to get the same toolchain settings
#
# This toolchain defines the following macros for use externally:
#
# set_xcode_property (TARGET XCODE_PROPERTY XCODE_VALUE XCODE_VARIANT)
#   A convenience macro for setting xcode specific properties on targets.
#   Available variants are: All, Release, RelWithDebInfo, Debug, MinSizeRel
#   example: set_xcode_property (myioslib IPHONEOS_DEPLOYMENT_TARGET "3.1" "all").
#
# find_host_package (PROGRAM ARGS)
#   A macro used to find executable programs on the host system, not within the
#   iOS environment.  Thanks to the android-cmake project for providing the
#   command.

# Fix for PThread library not in path
set(CMAKE_THREAD_LIBS_INIT "-lpthread")
set(CMAKE_HAVE_THREADS_LIBRARY 1)
set(CMAKE_USE_WIN32_THREADS_INIT 0)
set(CMAKE_USE_PTHREADS_INIT 1)

# Cache what generator is used
set(USED_CMAKE_GENERATOR "${CMAKE_GENERATOR}" CACHE STRING "Expose CMAKE_GENERATOR" FORCE)

# Get the Xcode version being used.
execute_process(COMMAND xcodebuild -version
  OUTPUT_VARIABLE XCODE_VERSION
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)
string(REGEX MATCH "Xcode [0-9\\.]+" XCODE_VERSION "${XCODE_VERSION}")
string(REGEX REPLACE "Xcode ([0-9\\.]+)" "\\1" XCODE_VERSION "${XCODE_VERSION}")
message(STATUS "Building with Xcode version: ${XCODE_VERSION}")
# Default to building for iPhoneOS if not specified otherwise, and we cannot
# determine the platform from the CMAKE_OSX_ARCHITECTURES variable. The use
# of CMAKE_OSX_ARCHITECTURES is such that try_compile() projects can correctly
# determine the value of IOS_PLATFORM from the root project, as
# CMAKE_OSX_ARCHITECTURES is propagated to them by CMake.
if (NOT DEFINED IOS_PLATFORM)
  if (CMAKE_OSX_ARCHITECTURES)
    if (CMAKE_OSX_ARCHITECTURES MATCHES ".*arm.*" AND CMAKE_OSX_SYSROOT MATCHES ".*iphoneos.*")
      set(IOS_PLATFORM "OS")
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES "i386" AND CMAKE_OSX_SYSROOT MATCHES ".*iphonesimulator.*")
      set(IOS_PLATFORM "SIMULATOR")
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES "x86_64" AND CMAKE_OSX_SYSROOT MATCHES ".*iphonesimulator.*")
      set(IOS_PLATFORM "SIMULATOR64")
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES "arm64" AND CMAKE_OSX_SYSROOT MATCHES ".*appletvos.*")
      set(IOS_PLATFORM "TVOS")
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES "x86_64" AND CMAKE_OSX_SYSROOT MATCHES ".*appletvsimulator.*")
      set(IOS_PLATFORM "SIMULATOR_TVOS")
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES ".*armv7k.*" AND CMAKE_OSX_SYSROOT MATCHES ".*watchos.*")
      set(IOS_PLATFORM "WATCHOS")
    elseif (CMAKE_OSX_ARCHITECTURES MATCHES "i386" AND CMAKE_OSX_SYSROOT MATCHES ".*watchsimulator.*")
      set(IOS_PLATFORM "SIMULATOR_WATCHOS")
    endif()
  endif()
  if (NOT IOS_PLATFORM)
    set(IOS_PLATFORM "OS")
  endif()
endif()
set(IOS_PLATFORM ${IOS_PLATFORM} CACHE STRING
  "Type of iOS platform for which to build.")

# Handle the case where we are targeting iOS and a version above 10.3.4 (32-bit support dropped officially)
if (IOS_PLATFORM STREQUAL "OS" AND IOS_DEPLOYMENT_TARGET VERSION_GREATER_EQUAL 10.3.4)
  set(IOS_PLATFORM "OS64")
  message(STATUS "Targeting minimum SDK version ${IOS_DEPLOYMENT_TARGET}. Dropping 32-bit support.")
elseif (IOS_PLATFORM STREQUAL "SIMULATOR" AND IOS_DEPLOYMENT_TARGET VERSION_GREATER_EQUAL 10.3.4)
  set(IOS_PLATFORM "SIMULATOR64")
  message(STATUS "Targeting minimum SDK version ${IOS_DEPLOYMENT_TARGET}. Dropping 32-bit support.")
endif()

# Determine the platform name and architectures for use in xcodebuild commands
# from the specified IOS_PLATFORM name.
if (IOS_PLATFORM STREQUAL "OS")
  set(XCODE_IOS_PLATFORM iphoneos)
  if (NOT IOS_ARCH)
    set(IOS_ARCH armv7 armv7s arm64)
  endif()
elseif (IOS_PLATFORM STREQUAL "OS64")
  set(XCODE_IOS_PLATFORM iphoneos)
  if (NOT IOS_ARCH)
    if (XCODE_VERSION VERSION_GREATER 10.0)
      set(IOS_ARCH arm64) # Add arm64e when Apple have fixed the integration issues with it, libarclite_iphoneos.a is currently missung bitcode markers for example
    else()
      set(IOS_ARCH arm64)
    endif()
  endif()
elseif (IOS_PLATFORM STREQUAL "SIMULATOR")
  set(XCODE_IOS_PLATFORM iphonesimulator)
  if (NOT IOS_ARCH)
    set(IOS_ARCH i386)
  endif()
  message(DEPRECATION "SIMULATOR IS DEPRECATED. Consider using SIMULATOR64 instead.")
elseif (IOS_PLATFORM STREQUAL "SIMULATOR64")
  set(XCODE_IOS_PLATFORM iphonesimulator)
  if (NOT IOS_ARCH)
    set(IOS_ARCH x86_64)
  endif()
elseif (IOS_PLATFORM STREQUAL "TVOS")
  set(XCODE_IOS_PLATFORM appletvos)
  if (NOT IOS_ARCH)
    set(IOS_ARCH arm64)
  endif()
elseif (IOS_PLATFORM STREQUAL "TVOSCOMBINED")
  set(XCODE_IOS_PLATFORM appletvos)
  if (MODERN_CMAKE)
    if (NOT IOS_ARCH)
      set(IOS_ARCH arm64 x86_64)
    endif()
  else()
    message(FATAL_ERROR "Please make sure that you are running CMake 3.14+ to make the TVOSCOMBINED setting work")
  endif()
elseif (IOS_PLATFORM STREQUAL "SIMULATOR_TVOS")
  set(XCODE_IOS_PLATFORM appletvsimulator)
  if (NOT IOS_ARCH)
    set(IOS_ARCH x86_64)
  endif()
elseif (IOS_PLATFORM STREQUAL "WATCHOS")
  set(XCODE_IOS_PLATFORM watchos)
  if (NOT IOS_ARCH)
    if (XCODE_VERSION VERSION_GREATER 10.0)
      set(IOS_ARCH armv7k arm64_32)
    else()
      set(IOS_ARCH armv7k)
    endif()
  endif()
elseif (IOS_PLATFORM STREQUAL "SIMULATOR_WATCHOS")
  set(XCODE_IOS_PLATFORM watchsimulator)
  if (NOT IOS_ARCH)
    set(IOS_ARCH i386)
  endif()
else()
  message(FATAL_ERROR "Invalid IOS_PLATFORM: ${IOS_PLATFORM}")
endif()
message(STATUS "Configuring ${XCODE_IOS_PLATFORM} build for IOS_PLATFORM: ${IOS_PLATFORM}, architecture(s): ${IOS_ARCH}")

# If user did not specify the SDK root to use, then query xcodebuild for it.
execute_process(COMMAND xcodebuild -version -sdk ${XCODE_IOS_PLATFORM} Path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT_INT
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
if (NOT DEFINED CMAKE_OSX_SYSROOT_INT AND NOT DEFINED CMAKE_OSX_SYSROOT)
  message(SEND_ERROR "Please make sure that Xcode is installed and that the toolchain"
  "is pointing to the correct path. Please run:"
  "sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  "and see if that fixes the problem for you.")
  message(FATAL_ERROR "Invalid CMAKE_OSX_SYSROOT: ${CMAKE_OSX_SYSROOT} "
  "does not exist.")
elseif (DEFINED CMAKE_OSX_SYSROOT)
  message(STATUS "Using SDK: ${CMAKE_OSX_SYSROOT} for IOS_PLATFORM: ${IOS_PLATFORM} when checking compatibility")
elseif (DEFINED CMAKE_OSX_SYSROOT_INT)
   message(STATUS "Using SDK: ${CMAKE_OSX_SYSROOT_INT} for IOS_PLATFORM: ${IOS_PLATFORM}")
   set(CMAKE_OSX_SYSROOT "${CMAKE_OSX_SYSROOT_INT}" CACHE INTERNAL "")
endif()

# Set Xcode property for SDKROOT as well if Xcode generator is used
if (USED_CMAKE_GENERATOR MATCHES "Xcode")
  set(CMAKE_OSX_SYSROOT "${XCODE_IOS_PLATFORM}" CACHE INTERNAL "")
  if (NOT DEFINED CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM)
    set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM 123456789A CACHE INTERNAL "")
  endif()
endif()

# Specify minimum version of deployment target.
if (NOT DEFINED IOS_DEPLOYMENT_TARGET)
  if (IOS_PLATFORM STREQUAL "WATCHOS" OR IOS_PLATFORM STREQUAL "SIMULATOR_WATCHOS")
    # Unless specified, SDK version 2.0 is used by default as minimum target version (watchOS).
    set(IOS_DEPLOYMENT_TARGET "2.0"
            CACHE STRING "Minimum SDK version to build for." )
  else()
    # Unless specified, SDK version 9.0 is used by default as minimum target version (iOS, tvOS).
    set(IOS_DEPLOYMENT_TARGET "9.0"
            CACHE STRING "Minimum SDK version to build for." )
  endif()
  message(STATUS "Using the default min-version since IOS_DEPLOYMENT_TARGET not provided!")
endif()
# Use bitcode or not
if (NOT DEFINED ENABLE_BITCODE AND NOT IOS_ARCH MATCHES "((^|;|, )(i386|x86_64))+")
  # Unless specified, enable bitcode support by default
  message(STATUS "Enabling bitcode support by default. ENABLE_BITCODE not provided!")
  set(ENABLE_BITCODE TRUE)
elseif (NOT DEFINED ENABLE_BITCODE)
  message(STATUS "Disabling bitcode support by default on simulators. ENABLE_BITCODE not provided for override!")
  set(ENABLE_BITCODE FALSE)
endif()
set(ENABLE_BITCODE_INT ${ENABLE_BITCODE} CACHE BOOL "Whether or not to enable bitcode" ${FORCE_CACHE})
# Use ARC or not
if (NOT DEFINED ENABLE_ARC)
  # Unless specified, enable ARC support by default
  set(ENABLE_ARC TRUE)
  message(STATUS "Enabling ARC support by default. ENABLE_ARC not provided!")
endif()
set(ENABLE_ARC_INT ${ENABLE_ARC} CACHE BOOL "Whether or not to enable ARC" ${FORCE_CACHE})
# Use hidden visibility or not
if (NOT DEFINED ENABLE_VISIBILITY)
  # Unless specified, disable symbols visibility by default
  set(ENABLE_VISIBILITY FALSE)
  message(STATUS "Hiding symbols visibility by default. ENABLE_VISIBILITY not provided!")
endif()
set(ENABLE_VISIBILITY_INT ${ENABLE_VISIBILITY} CACHE BOOL "Whether or not to hide symbols (-fvisibility=hidden)" ${FORCE_CACHE})
# Set strict compiler checks or not
if (NOT DEFINED ENABLE_STRICT_TRY_COMPILE)
  # Unless specified, disable strict try_compile()
  set(ENABLE_STRICT_TRY_COMPILE FALSE)
  message(STATUS "Using NON-strict compiler checks by default. ENABLE_STRICT_TRY_COMPILE not provided!")
endif()
set(ENABLE_STRICT_TRY_COMPILE_INT ${ENABLE_STRICT_TRY_COMPILE} CACHE BOOL "Whether or not to use strict compiler checks" ${FORCE_CACHE})
# Get the SDK version information.
execute_process(COMMAND xcodebuild -sdk ${CMAKE_OSX_SYSROOT} -version SDKVersion
  OUTPUT_VARIABLE IOS_SDK_VERSION
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)

# Find the Developer root for the specific iOS platform being compiled for
# from CMAKE_OSX_SYSROOT.  Should be ../../ from SDK specified in
# CMAKE_OSX_SYSROOT. There does not appear to be a direct way to obtain
# this information from xcrun or xcodebuild.
if (NOT DEFINED CMAKE_IOS_DEVELOPER_ROOT AND NOT USED_CMAKE_GENERATOR MATCHES "Xcode")
  get_filename_component(PLATFORM_SDK_DIR ${CMAKE_OSX_SYSROOT} PATH)
  get_filename_component(CMAKE_IOS_DEVELOPER_ROOT ${PLATFORM_SDK_DIR} PATH)

  if (NOT DEFINED CMAKE_IOS_DEVELOPER_ROOT)
    message(FATAL_ERROR "Invalid CMAKE_IOS_DEVELOPER_ROOT: "
      "${CMAKE_IOS_DEVELOPER_ROOT} does not exist.")
  endif()
endif()
# Find the C & C++ compilers for the specified SDK.
if (NOT CMAKE_C_COMPILER)
  execute_process(COMMAND xcrun -sdk ${CMAKE_OSX_SYSROOT} -find clang
    OUTPUT_VARIABLE CMAKE_C_COMPILER
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  message(STATUS "Using C compiler: ${CMAKE_C_COMPILER}")
endif()
if (NOT CMAKE_CXX_COMPILER)
  execute_process(COMMAND xcrun -sdk ${CMAKE_OSX_SYSROOT} -find clang++
    OUTPUT_VARIABLE CMAKE_CXX_COMPILER
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  message(STATUS "Using CXX compiler: ${CMAKE_CXX_COMPILER}")
endif()
# Find (Apple's) libtool.
execute_process(COMMAND xcrun -sdk ${CMAKE_OSX_SYSROOT} -find libtool
  OUTPUT_VARIABLE BUILD_LIBTOOL
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)
message(STATUS "Using libtool: ${BUILD_LIBTOOL}")
# Configure libtool to be used instead of ar + ranlib to build static libraries.
# This is required on Xcode 7+, but should also work on previous versions of
# Xcode.
set(CMAKE_C_CREATE_STATIC_LIBRARY
  "${BUILD_LIBTOOL} -static -o <TARGET> <LINK_FLAGS> <OBJECTS> ")
set(CMAKE_CXX_CREATE_STATIC_LIBRARY
  "${BUILD_LIBTOOL} -static -o <TARGET> <LINK_FLAGS> <OBJECTS> ")
# Find the toolchain's provided install_name_tool if none is found on the host
if (NOT CMAKE_INSTALL_NAME_TOOL)
  execute_process(COMMAND xcrun -sdk ${CMAKE_OSX_SYSROOT} -find install_name_tool
      OUTPUT_VARIABLE CMAKE_INSTALL_NAME_TOOL_INT
      ERROR_QUIET
      OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(CMAKE_INSTALL_NAME_TOOL ${CMAKE_INSTALL_NAME_TOOL_INT} CACHE STRING "" ${FORCE_CACHE})
  message(STATUS "Using install_name_tool: ${CMAKE_INSTALL_NAME_TOOL}")
endif()
# Get the version of Darwin (OS X) of the host.
execute_process(COMMAND uname -r
  OUTPUT_VARIABLE CMAKE_HOST_SYSTEM_VERSION
  ERROR_QUIET
  OUTPUT_STRIP_TRAILING_WHITESPACE)
# Standard settings.
set(CMAKE_SYSTEM_NAME Darwin CACHE INTERNAL "")
set(CMAKE_SYSTEM_VERSION ${IOS_SDK_VERSION} CACHE INTERNAL "")
set(UNIX TRUE CACHE BOOL "")
set(APPLE TRUE CACHE BOOL "")
set(IOS TRUE CACHE BOOL "")
set(CMAKE_AR ar CACHE FILEPATH "" FORCE)
set(CMAKE_RANLIB ranlib CACHE FILEPATH "" FORCE)
set(CMAKE_STRIP strip CACHE FILEPATH "" FORCE)
# Set the architectures for which to build.
set(CMAKE_OSX_ARCHITECTURES ${IOS_ARCH} CACHE STRING "Build architecture for iOS")
# Change the type of target generated for try_compile() so it'll work when cross-compiling, weak compiler checks
if (ENABLE_STRICT_TRY_COMPILE_INT)
  message(STATUS "Using strict compiler checks (default in CMake).")
else()
  set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
endif()
# All iOS/Darwin specific settings - some may be redundant.
set(CMAKE_SHARED_LIBRARY_PREFIX "lib")
set(CMAKE_SHARED_LIBRARY_SUFFIX ".dylib")
set(CMAKE_SHARED_MODULE_PREFIX "lib")
set(CMAKE_SHARED_MODULE_SUFFIX ".so")
set(CMAKE_C_COMPILER_ABI ELF)
set(CMAKE_CXX_COMPILER_ABI ELF)
set(CMAKE_C_HAS_ISYSROOT 1)
set(CMAKE_CXX_HAS_ISYSROOT 1)
set(CMAKE_MODULE_EXISTS 1)
set(CMAKE_DL_LIBS "")
set(CMAKE_C_OSX_COMPATIBILITY_VERSION_FLAG "-compatibility_version ")
set(CMAKE_C_OSX_CURRENT_VERSION_FLAG "-current_version ")
set(CMAKE_CXX_OSX_COMPATIBILITY_VERSION_FLAG "${CMAKE_C_OSX_COMPATIBILITY_VERSION_FLAG}")
set(CMAKE_CXX_OSX_CURRENT_VERSION_FLAG "${CMAKE_C_OSX_CURRENT_VERSION_FLAG}")

if (IOS_ARCH MATCHES "((^|;|, )(arm64|arm64e|x86_64))+")
  set(CMAKE_C_SIZEOF_DATA_PTR 8)
  set(CMAKE_CXX_SIZEOF_DATA_PTR 8)
  if (IOS_ARCH MATCHES "((^|;|, )(arm64|arm64e))+")
    set(CMAKE_SYSTEM_PROCESSOR "aarch64")
  else()
    set(CMAKE_SYSTEM_PROCESSOR "x86_64")
  endif()
  message(STATUS "Using a data_ptr size of 8")
else()
  set(CMAKE_C_SIZEOF_DATA_PTR 4)
  set(CMAKE_CXX_SIZEOF_DATA_PTR 4)
  set(CMAKE_SYSTEM_PROCESSOR "arm")
  message(STATUS "Using a data_ptr size of 4")
endif()

message(STATUS "Building for minimum ${XCODE_IOS_PLATFORM} version: ${IOS_DEPLOYMENT_TARGET}"
               " (SDK version: ${IOS_SDK_VERSION})")
# Note that only Xcode 7+ supports the newer more specific:
# -m${XCODE_IOS_PLATFORM}-version-min flags, older versions of Xcode use:
# -m(ios/ios-simulator)-version-min instead.
if (IOS_PLATFORM STREQUAL "OS" OR IOS_PLATFORM STREQUAL "OS64")
  if (XCODE_VERSION VERSION_LESS 7.0)
    set(XCODE_IOS_PLATFORM_VERSION_FLAGS
      "-mios-version-min=${IOS_DEPLOYMENT_TARGET}")
  else()
    # Xcode 7.0+ uses flags we can build directly from XCODE_IOS_PLATFORM.
    set(XCODE_IOS_PLATFORM_VERSION_FLAGS
      "-m${XCODE_IOS_PLATFORM}-version-min=${IOS_DEPLOYMENT_TARGET}")
  endif()
elseif (IOS_PLATFORM STREQUAL "TVOS")
  set(XCODE_IOS_PLATFORM_VERSION_FLAGS
    "-mtvos-version-min=${IOS_DEPLOYMENT_TARGET}")
elseif (IOS_PLATFORM STREQUAL "SIMULATOR_TVOS")
  set(XCODE_IOS_PLATFORM_VERSION_FLAGS
    "-mtvos-simulator-version-min=${IOS_DEPLOYMENT_TARGET}")
elseif (IOS_PLATFORM STREQUAL "WATCHOS")
  set(XCODE_IOS_PLATFORM_VERSION_FLAGS
    "-mwatchos-version-min=${IOS_DEPLOYMENT_TARGET}")
elseif (IOS_PLATFORM STREQUAL "SIMULATOR_WATCHOS")
  set(XCODE_IOS_PLATFORM_VERSION_FLAGS
    "-mwatchos-simulator-version-min=${IOS_DEPLOYMENT_TARGET}")
else()
  # SIMULATOR or SIMULATOR64 both use -mios-simulator-version-min.
  set(XCODE_IOS_PLATFORM_VERSION_FLAGS
    "-mios-simulator-version-min=${IOS_DEPLOYMENT_TARGET}")
endif()
message(STATUS "Version flags set to: ${XCODE_IOS_PLATFORM_VERSION_FLAGS}")
set(CMAKE_OSX_DEPLOYMENT_TARGET ${IOS_DEPLOYMENT_TARGET} CACHE STRING
    "Set CMake deployment target" ${FORCE_CACHE})

if (ENABLE_BITCODE_INT)
  set(BITCODE "-fembed-bitcode")
  set(CMAKE_XCODE_ATTRIBUTE_BITCODE_GENERATION_MODE bitcode CACHE INTERNAL "")
  message(STATUS "Enabling bitcode support.")
else()
  set(BITCODE "")
  set(CMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE NO CACHE INTERNAL "")
  message(STATUS "Disabling bitcode support.")
endif()

if (ENABLE_ARC_INT)
  set(FOBJC_ARC "-fobjc-arc")
  set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES CACHE INTERNAL "")
  message(STATUS "Enabling ARC support.")
else()
  set(FOBJC_ARC "-fno-objc-arc")
  set(CMAKE_XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC NO CACHE INTERNAL "")
  message(STATUS "Disabling ARC support.")
endif()

if (NOT ENABLE_VISIBILITY_INT)
  set(VISIBILITY "-fvisibility=hidden")
  set(CMAKE_XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN YES CACHE INTERNAL "")
  message(STATUS "Hiding symbols (-fvisibility=hidden).")
else()
  set(VISIBILITY "")
  set(CMAKE_XCODE_ATTRIBUTE_GCC_SYMBOLS_PRIVATE_EXTERN NO CACHE INTERNAL "")
endif()

#Check if Xcode generator is used, since that will handle these flags automagically
if (USED_CMAKE_GENERATOR MATCHES "Xcode")
  message(STATUS "Not setting any manual command-line buildflags, since Xcode is selected as generator.")
else()
  foreach(ARCH ${IOS_ARCH})
    set(ARCH_FLAGS "${ARCH_FLAGS} -arch ${ARCH}")
  endforeach()

  set(CMAKE_C_FLAGS
  "${XCODE_IOS_PLATFORM_VERSION_FLAGS} ${ARCH_FLAGS} ${BITCODE} -fobjc-abi-version=2 ${FOBJC_ARC} ${CMAKE_C_FLAGS}")
  # Hidden visibilty is required for C++ on iOS.
  set(CMAKE_CXX_FLAGS
  "${XCODE_IOS_PLATFORM_VERSION_FLAGS} ${ARCH_FLAGS} ${BITCODE} ${VISIBILITY} -fvisibility-inlines-hidden -fobjc-abi-version=2 ${FOBJC_ARC} ${CMAKE_CXX_FLAGS}")
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS} -O0 -g ${CMAKE_CXX_FLAGS_DEBUG}")
  set(CMAKE_CXX_FLAGS_MINSIZEREL "${CMAKE_CXX_FLAGS} -DNDEBUG -Os -ffast-math ${CMAKE_CXX_FLAGS_MINSIZEREL}")
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS} -DNDEBUG -O2 -g -ffast-math ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS} -DNDEBUG -O3 -ffast-math ${CMAKE_CXX_FLAGS_RELEASE}")
  set(CMAKE_C_LINK_FLAGS "${XCODE_IOS_PLATFORM_VERSION_FLAGS} -Wl,-search_paths_first ${CMAKE_C_LINK_FLAGS}")
  set(CMAKE_CXX_LINK_FLAGS "${XCODE_IOS_PLATFORM_VERSION_FLAGS}  -Wl,-search_paths_first ${CMAKE_CXX_LINK_FLAGS}")

  # In order to ensure that the updated compiler flags are used in try_compile()
  # tests, we have to forcibly set them in the CMake cache, not merely set them
  # in the local scope.
  list(APPEND VARS_TO_FORCE_IN_CACHE
    CMAKE_C_FLAGS
    CMAKE_CXX_FLAGS
    CMAKE_CXX_FLAGS_DEBUG
    CMAKE_CXX_FLAGS_RELWITHDEBINFO
    CMAKE_CXX_FLAGS_MINSIZEREL
    CMAKE_CXX_FLAGS_RELEASE
    CMAKE_C_LINK_FLAGS
    CMAKE_CXX_LINK_FLAGS)
  foreach(VAR_TO_FORCE ${VARS_TO_FORCE_IN_CACHE})
    set(${VAR_TO_FORCE} "${${VAR_TO_FORCE}}" CACHE STRING "")
  endforeach()
endif()

set(CMAKE_PLATFORM_HAS_INSTALLNAME 1)
set(CMAKE_SHARED_LINKER_FLAGS "-rpath @executable_path/Frameworks -rpath @loader_path/Frameworks")
set(CMAKE_SHARED_LIBRARY_CREATE_C_FLAGS "-dynamiclib -Wl,-headerpad_max_install_names")
set(CMAKE_SHARED_MODULE_CREATE_C_FLAGS "-bundle -Wl,-headerpad_max_install_names")
set(CMAKE_SHARED_MODULE_LOADER_C_FLAG "-Wl,-bundle_loader,")
set(CMAKE_SHARED_MODULE_LOADER_CXX_FLAG "-Wl,-bundle_loader,")
set(CMAKE_FIND_LIBRARY_SUFFIXES ".tbd" ".dylib" ".so" ".a")
set(CMAKE_SHARED_LIBRARY_SONAME_C_FLAG "-install_name")

# Set the find root to the iOS developer roots and to user defined paths.
set(CMAKE_FIND_ROOT_PATH ${CMAKE_IOS_DEVELOPER_ROOT} ${CMAKE_OSX_SYSROOT} ${CMAKE_PREFIX_PATH} CACHE STRING "Root path that will be prepended
 to all search paths")
# Default to searching for frameworks first.
set(CMAKE_FIND_FRAMEWORK FIRST)
# Set up the default search directories for frameworks.
set(CMAKE_FRAMEWORK_PATH
  ${CMAKE_IOS_DEVELOPER_ROOT}/Library/PrivateFrameworks
  ${CMAKE_OSX_SYSROOT_INT}/System/Library/Frameworks
  ${CMAKE_FRAMEWORK_PATH} CACHE STRING "Frameworks search paths" ${FORCE_CACHE})

# By default, search both the specified iOS SDK and the remainder of the host filesystem.
if (NOT CMAKE_FIND_ROOT_PATH_MODE_PROGRAM)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH CACHE STRING "" ${FORCE_CACHE})
endif()
if (NOT CMAKE_FIND_ROOT_PATH_MODE_LIBRARY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY CACHE STRING "" ${FORCE_CACHE})
endif()
if (NOT CMAKE_FIND_ROOT_PATH_MODE_INCLUDE)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY CACHE STRING "" ${FORCE_CACHE})
endif()
if (NOT CMAKE_FIND_ROOT_PATH_MODE_PACKAGE)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY CACHE STRING "" ${FORCE_CACHE})
endif()

#
# Some helper-macros below to simplify and beautify the CMakeFile
#

# This little macro lets you set any Xcode specific property.
macro(set_xcode_property TARGET XCODE_PROPERTY XCODE_VALUE XCODE_RELVERSION)
  set(XCODE_RELVERSION_I "${XCODE_RELVERSION}")
  if (XCODE_RELVERSION_I STREQUAL "All")
    set_property(TARGET ${TARGET} PROPERTY
    XCODE_ATTRIBUTE_${XCODE_PROPERTY} "${XCODE_VALUE}")
  else()
    set_property(TARGET ${TARGET} PROPERTY
    XCODE_ATTRIBUTE_${XCODE_PROPERTY}[variant=${XCODE_RELVERSION_I}] "${XCODE_VALUE}")
  endif()
endmacro(set_xcode_property)
# This macro lets you find executable programs on the host system.
macro(find_host_package)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE NEVER)
  set(IOS FALSE)
  find_package(${ARGN})
  set(IOS TRUE)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
endmacro(find_host_package)
macro(find_host_program)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE NEVER)
  set(IOS FALSE)
  find_program(${ARGN})
  set(IOS TRUE)
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM BOTH)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
endmacro(find_host_program)

list(JOIN CMAKE_OSX_ARCHITECTURES "$<SEMICOLON>" IOS_ARCH_STR)
set(CMAKE_RUNTIME_ARGS
  -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
  -DIOS_PLATFORM=${IOS_PLATFORM}
  -DENABLE_ARC=${ENABLE_ARC}
  -DENABLE_VISIBILITY=${ENABLE_VISIBILITY}
  -DENABLE_BITCODE=${ENABLE_BITCODE}
  -DIOS_DEPLOYMENT_TARGET=${IOS_DEPLOYMENT_TARGET}
  -DIOS_ARCH=${IOS_ARCH_STR}
)
