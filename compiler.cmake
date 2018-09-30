#
# compiler.cmake
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
#   BUILD/COMPILER.CMAKE
#
#   This file runs some tests for detecting
#   the compiler environment and provides a
#   crossplatform set of functions for setting
#   compiler variables. If available features
#   for c++0x will be enabled automatically
#
# PROVIDED CMAKE VARIABLES
# -----------------------
# MZ_IS_VS true when the platform is MS Visual Studio
# MZ_IS_GCC true when the compiler is gcc or compatible
# MZ_IS_CLANG true when the compiler is clang
# MZ_IS_XCODE true when configuring for the XCode IDE
# MZ_IS_RELEASE true when building with CMAKE_BUILD_TYPE = "Release"
# MZ_64BIT true when building for a 64bit system
# MZ_32BIT true when building for a 32bit system
# MZ_HAS_CXX0X see MZ_HAS_CXX11
# MZ_HAS_CXX11 true when the compiler supports at least a
#              (subset) of the upcoming C++11 standard
# MZ_MACOS true when building on macOS
# MZ_IOS true when building for iOS
# MZ_WINDOWS true when building on Windows
# MZ_LINUX true when building on Linux
# MZ_DATE_STRING a string containing day, date and time of the
#                moment cmake was executed
#                e.g. Mo, 27 Feb 2012 19:47:23 +0100
# MZ_YEAR_STRING a string containing the year of the moment
#                cmake was executed
# MZ_USER_STRING a string containing the current username
# MZ_COMPILER_VERSION a string denoting the compiler version,
#                e.g. with gcc 4.5.1 this is "45"
#
# PROVIDED MACROS
# -----------------------
# mz_add_definition <definition1> ...
#       add the definition <definition> (and following)
#       to the list of definitions passed to the compiler.
#       Automatically switches between the syntax of msvc
#       and gcc/clang
#       Example: mz_add_definition(NO_DEBUG)
#
# mz_add_cxx_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the C++ compiler when
#       the compiler matches the given platform
#
# mz_add_c_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the C compiler when
#       the compiler matches the given platform
#
# mz_add_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the compiler, no matter
#       wether compiling C or C++ files. The selected platform
#       is still respected
#
# mz_add_cxx_debug_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the C++ compiler when
#       the compiler matches the given platform
#
# mz_add_c_debug_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the C compiler when
#       the compiler matches the given platform
#
# mz_add_debug_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the compiler, no matter
#       wether compiling C or C++ files. The selected platform
#       is still respected
#
# mz_add_cxx_release_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the C++ compiler when
#       the compiler matches the given platform
#
# mz_add_c_release_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the C compiler when
#       the compiler matches the given platform
#
# mz_add_release_flag GCC|CLANG|VS|ALL <flag1> <flag2> ...
#       pass the given flag to the compiler, no matter
#       wether compiling C or C++ files. The selected platform
#       is still respected
#
# mz_use_default_compiler_settings
#       resets all configured compiler flags back to the
#       cmake default. This is especially useful when adding
#       external libraries which might still have compiler warnings
#
# ENABLED COMPILER DEFINITIONS/OPTIONS
# -----------------------
# On all compilers supporting it, the option to treat warnings
# will be set. Additionally the warn level of the compiler will
# be decreased. See mz_use_default_compiler_settings whenever some
# warnings have to be accepted
#
# Provided defines (defined to 1)
#  MZ_WINDOWS on Windows
#  MZ_LINUX on Linux
#  MZ_MACOS on macOS
#  MZ_IOS on iOS
#  WIN32_VS on MSVC - note this is deprecated, it is recommended to use _MSC_VER
#  MZ_WIN32_MINGW when using the mingw toolchain
#  MZ_WIN32_MINGW64 when using the mingw-w64 toolchain
#  MZ_HAS_CXX11 / MZ_HAS_CXX0X when subset of C++11 is available
#
########################################################################


########################################################################
## no need to change anything beyond here
########################################################################

macro(mz_message MSG)
    message("-- ${MSG}")
endmacro()

#set(MZ_MSG_DEBUG TRUE)

macro(mz_debug_message MSG)
    if(MZ_MSG_DEBUG)
        mz_message(${MSG})
    endif()
endmacro()

macro(mz_warning_message MSG)
    message(WARNING "!! ${MSG}")
endmacro()

macro(mz_error_message MSG)
    message(SEND_ERROR "!! ${MSG}")
    return()
endmacro()

macro(mz_fatal_message MSG)
    message(FATAL_ERROR "!! ${MSG}")
    return()
endmacro()

macro(mz_add_definition)
    foreach(DEF ${ARGN})
        if(MZ_IS_GCC)
            mz_add_flag(ALL "-D${DEF}")
        elseif(MZ_IS_VS)
            mz_add_flag(ALL "/D${DEF}")
        endif()
    endforeach()
endmacro()

macro(__mz_add_compiler_flag COMPILER_FLAGS PLATFORM)
    if( NOT "${PLATFORM}" MATCHES "(GCC)|(CLANG)|(VS)|(ALL)" )
        mz_error_message("Please provide a valid platform when adding a compiler flag: GCC|CLANG|VS|ALL")
    endif()

    if(  ("${PLATFORM}" STREQUAL "ALL")
            OR ("${PLATFORM}" STREQUAL "GCC" AND MZ_IS_GCC)
            OR ("${PLATFORM}" STREQUAL "VS" AND MZ_IS_VS)
            OR ("${PLATFORM}" STREQUAL "CLANG" AND MZ_IS_CLANG) )

        foreach(_current ${ARGN})
            set(${COMPILER_FLAGS} "${${COMPILER_FLAGS}} ${_current}")
            mz_debug_message("Adding flag ${_current} to ${COMPILER_FLAGS}")
        endforeach()
        mz_debug_message("${COMPILER_FLAGS}=${${COMPILER_FLAGS}}")
    else()
        mz_debug_message("Skipping flag ${FLAG}, needs platform ${PLATFORM}")
    endif()
endmacro()

macro(mz_add_cxx_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_c_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_C_FLAGS ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS ${PLATFORM} ${ARGN})
    __mz_add_compiler_flag(CMAKE_C_FLAGS ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_cxx_release_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS_RELEASE ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_c_release_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_C_FLAGS_RELEASE ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_release_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS_RELEASE ${PLATFORM} ${ARGN})
    __mz_add_compiler_flag(CMAKE_C_FLAGS_RELEASE ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_cxx_debug_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS_DEBUG ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_c_debug_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_C_FLAGS_DEBUG ${PLATFORM} ${ARGN})
endmacro()

macro(mz_add_debug_flag PLATFORM)
    __mz_add_compiler_flag(CMAKE_CXX_FLAGS_DEBUG ${PLATFORM} ${ARGN})
    __mz_add_compiler_flag(CMAKE_C_FLAGS_DEBUG ${PLATFORM} ${ARGN})
endmacro()

macro(mz_use_default_compiler_settings)
    set(CMAKE_C_FLAGS "${MZ_C_DEFAULT}")
    set(CMAKE_CXX_FLAGS "${MZ_CXX_DEFAULT}")
    set(CMAKE_C_FLAGS_DEBUG "${MZ_C_DEFAULT_DEBUG}")
    set(CMAKE_CXX_FLAGS_DEBUG "${MZ_CXX_DEFAULT_DEBUG}")
    set(CMAKE_C_FLAGS_RELEASE "${MZ_C_DEFAULT_RELEASE}")
    set(CMAKE_CXX_FLAGS_RELEASE "${MZ_CXX_DEFAULT_RELEASE}")
endmacro()


# borrowed from find_boost
#
# Runs compiler with "-dumpversion" and parses major/minor
# version with a regex.
#
function(__Boost_MZ_COMPILER_DUMPVERSION _OUTPUT_VERSION)

  exec_program(${CMAKE_CXX_COMPILER}
    ARGS ${CMAKE_CXX_COMPILER_ARG1} -dumpversion
    OUTPUT_VARIABLE _boost_COMPILER_VERSION
  )
  string(
    REGEX REPLACE "([0-9])\\.([0-9])(\\.[0-9])?" "\\1\\2"
    _boost_COMPILER_VERSION ${_boost_COMPILER_VERSION}
  )

  set(${_OUTPUT_VERSION} ${_boost_COMPILER_VERSION} PARENT_SCOPE)
endfunction()

# runs compiler with "--version" and searches for clang
#
function(__MZ_COMPILER_IS_CLANG _OUTPUT _OUTPUT_VERSION)
  exec_program(${CMAKE_CXX_COMPILER}
    ARGS ${CMAKE_CXX_COMPILER_ARG1} --version
    OUTPUT_VARIABLE _MZ_CLANG_VERSION
  )

  if("${_MZ_CLANG_VERSION}" MATCHES ".*clang.*")
    set(${_OUTPUT} TRUE PARENT_SCOPE)
  else()
    set(${_OUTPUT} FALSE PARENT_SCOPE)
  endif()

  string(
    REGEX MATCH "[0-9]+\\.[0-9](\\.[0-9])?(\\-[0-9])?"
    _MZ_CLANG_VERSION ${_MZ_CLANG_VERSION}
  )
  string(
    REPLACE "." "" _MZ_CLANG_VERSION ${_MZ_CLANG_VERSION}
  )

  set(${_OUTPUT_VERSION} ${_MZ_CLANG_VERSION} PARENT_SCOPE)
  mz_debug_message("Possible clang version ${_MZ_CLANG_VERSION}")
endfunction()

# we only run the very first time
if(NOT MZ_COMPILER_TEST_HAS_RUN)

    message("-- running mz compiler detection tools")

    # cache the default compiler settings
    set(MZ_C_DEFAULT "${CMAKE_C_FLAGS}" CACHE INTERNAL MZ_C_DEFAULT)
    set(MZ_CXX_DEFAULT "${CMAKE_CXX_FLAGS}" CACHE INTERNAL MZ_CXX_DEFAULT)
    set(MZ_C_DEFAULT_DEBUG "${CMAKE_C_FLAGS_DEBUG}" CACHE INTERNAL MZ_C_DEFAULT_DEBUG)
    set(MZ_CXX_DEFAULT_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}" CACHE INTERNAL MZ_CXX_DEFAULT_DEBUG)
    set(MZ_C_DEFAULT_RELEASE "${CMAKE_C_FLAGS_RELEASE}" CACHE INTERNAL MZ_C_DEFAULT_RELEASE)
    set(MZ_CXX_DEFAULT_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}" CACHE INTERNAL MZ_CXX_DEFAULT_RELEASE)

    # compiler settings and defines depending on platform
    if(IOS_PLATFORM)
        set(MZ_IOS TRUE CACHE INTERNAL MZ_IOS)
        mz_message("dectected toolchain for iOS")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
        set(MZ_MACOS TRUE CACHE INTERNAL MZ_MACOS )
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(MZ_LINUX TRUE CACHE INTERNAL MZ_LINUX )
    else()
        set(MZ_WINDOWS TRUE CACHE INTERNAL MZ_WINDOWS )
    endif()

    # clang is gcc compatible but still different
    __MZ_COMPILER_IS_CLANG( _MZ_TEST_CLANG COMPILER_VERSION )
    if( _MZ_TEST_CLANG )
        mz_message("compiler is clang")
        set(MZ_IS_CLANG TRUE CACHE INTERNAL MZ_IS_CLANG)
    endif()

    # gnu compiler
    #message("IS_GCC ${CMAKE_COMPILER_IS_GNU_CC}")
    if(UNIX OR MINGW)
        mz_message("GCC compatible compiler found")

        set(MZ_IS_GCC TRUE CACHE INTERNAL MZ_IS_GCC)

        # xcode?
        if(CMAKE_GENERATOR STREQUAL "Xcode")
            mz_message("Found active XCode generator")
            set(MZ_IS_XCODE TRUE CACHE INTERNAL MZ_IS_XCODE)
        endif()

        # detect compiler version
        if(NOT MZ_IS_CLANG)
            __Boost_MZ_COMPILER_DUMPVERSION(COMPILER_VERSION)
        endif()
        mz_message("compiler version ${COMPILER_VERSION}")

        if(NOT MZ_IS_CLANG AND COMPILER_VERSION STRGREATER "45")
            mz_message("C++11 support detected")
            set(MZ_HAS_CXX0X TRUE CACHE INTERNAL MZ_HAS_CXX0X)
            set(MZ_HAS_CXX11 TRUE CACHE INTERNAL MZ_HAS_CXX11)
        elseif(NOT MZ_IS_CLANG AND COMPILER_VERSION STRGREATER "44")
            mz_message("experimental C++0x support detected")
            set(MZ_HAS_EXPERIMENTAL_CXX0X TRUE CACHE BOOL MZ_HAS_EXPERIMENTAL_CXX0X)
            set(MZ_HAS_CXX0X TRUE CACHE BOOL MZ_HAS_CXX0X)
            set(MZ_HAS_CXX11 TRUE CACHE BOOL MZ_HAS_CXX11)
        elseif(MZ_IS_CLANG AND COMPILER_VERSION GREATER "29")
            mz_message("clang 3.1+ with C++11 support detected")
            set(MZ_HAS_CXX0X TRUE CACHE INTERNAL MZ_HAS_CXX0X)
            set(MZ_HAS_CXX11 TRUE CACHE INTERNAL MZ_HAS_CXX11)
        endif()

        set(MZ_COMPILER_VERSION ${COMPILER_VERSION} CACHE INTERNAL MZ_COMPILER_VERSION)
        set(MZ_COMPILER_TEST_HAS_RUN TRUE CACHE INTERNAL MZ_COMPILER_TEST_HAS_RUN)

    # ms visual studio
    elseif(MSVC OR MSVC_IDE)
        mz_message("Microsoft Visual Studio Compiler found")

        set(MZ_IS_VS TRUE CACHE INTERNAL MZ_IS_VS)

        if(MSVC10)
            mz_message("C++11 support detected")
            set(MZ_HAS_CXX0X TRUE CACHE INTERNAL MZ_HAS_CXX0X )
            set(MZ_HAS_CXX11 TRUE CACHE INTERNAL MZ_HAS_CXX11 )
        endif()

        set(MZ_COMPILER_TEST_HAS_RUN TRUE CACHE INTERNAL MZ_COMPILER_TEST_HAS_RUN)

    # currently unsupported
    else()
        mz_error_message("compiler platform currently unsupported by mz tools !!")
    endif()

    # platform (32bit / 64bit)
    if(CMAKE_SIZEOF_VOID_P MATCHES "8")
        mz_message("64bit platform")
        set(MZ_64BIT ON CACHE INTERNAL MZ_64BIT)
    else()
        mz_message("32bit platform")
        set(MZ_32BIT ON CACHE INTERNAL MZ_32BIT)
    endif()

    # configured build type
    # NOTE: This can be overriden e.g. on Visual Studio
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        set(MZ_IS_RELEASE TRUE CACHE INTERNAL MZ_IS_RELEASE)
        mz_debug_message("CMake run in release mode")
    else()
        set(MZ_IS_RELEASE FALSE CACHE INTERNAL MZ_IS_RELEASE)
        mz_debug_message("CMake run in debug mode")
    endif()

endif() #MZ_COMPILER_TEST_HAS_RUN

# determine current date and time
if(WINDOWS)
    execute_process(COMMAND "date" "/T" OUTPUT_VARIABLE MZ_DATE_STRING)
    set(MZ_USER_STRING $ENV{USERNAME})
else() # Sun, 11 Dec 2011 12:07:00 +0200
    execute_process(COMMAND "date" "+%Y-%m-%dT%H:%M:%SZ" OUTPUT_VARIABLE MZ_DATE_STRING)
    string(REPLACE "\n" "" MZ_DATE_STRING "${MZ_DATE_STRING}")
    execute_process(COMMAND "date" "+%Y" OUTPUT_VARIABLE MZ_YEAR_STRING)
    string(REPLACE "\n" "" MZ_YEAR_STRING "${MZ_YEAR_STRING}")
    set(MZ_USER_STRING $ENV{USER})
endif()
mz_message("Today is: ${MZ_DATE_STRING} (Year ${MZ_YEAR_STRING})")
mz_message("User is: ${MZ_USER_STRING}")
mz_message("Compiler version is: ${MZ_COMPILER_VERSION}")

# define the DEBUG macro
if(NOT MZ_IS_RELEASE)
    mz_add_definition(DEBUG=1)
endif()

# optional C++0x/c++11 features on gcc (on vs2010 this is enabled by default)
if(MZ_IS_GCC AND MZ_HAS_CXX0X) # AND NOT DARWIN)
    mz_add_cxx_flag(GCC -std=c++11 -fgnu-keywords)
    mz_message("forcing C++11 support on this platform")
endif()

# compiler flags
mz_add_flag(GCC -Wall -Werror -Wno-unused-function)
if(MZ_WINDOWS)
    mz_add_definition(MZ_WINDOWS=1)
elseif(MZ_IOS)
    mz_add_definition(MZ_IOS=1)
elseif(MZ_MACOS)
    mz_add_definition(MZ_MACOS=1)
elseif(MZ_LINUX)
    mz_add_definition(MZ_LINUX=1)
endif()

# work around an issue with Qt5 and clang 6.1
if( MZ_IS_CLANG AND MZ_COMPILER_VERSION STRGREATER 6.0.3 )
    mz_add_cxx_flag(GCC -Wno-unknown-pragmas)
endif()


if(MZ_IS_GCC)
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -DDEBUG")
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O2 -g1")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -DDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O2 -g1")

    if(APPLE AND MZ_IS_CLANG)
        set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -ggdb -O0 -fno-inline")
        set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -ggdb -O0 -fno-inline")
    endif()

    if(MZ_WINDOWS)
        if(MZ_64BIT)
            mz_add_definition("WIN32_MINGW64=1")
        else()
            mz_add_definition("WIN32_MINGW=1")
        endif()
    endif()

elseif(MZ_IS_VS)
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} /MP /MDd /D DEBUG /D WIN32_VS=1")
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /MP /MD /D WIN32_VS=1 /O2")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MP /MDd /D DEBUG /D WIN32_VS=1")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MP /MD /D WIN32_VS=1 /O2")
endif()

if(MZ_HAS_CXX11)
    mz_add_definition(MZ_HAS_CXX11=1)
    mz_add_definition(MZ_HAS_CXX0X=1)
endif()

# On Windows, MS Visual Studio will ignore the
# environment variables INCLUDE and LIB by default. This forces
# them to be used
if(MZ_WINDOWS)
    foreach(_inc $ENV{INCLUDE})
        file(TO_CMAKE_PATH ${_inc} _inc)
        include_directories(SYSTEM "${_inc}")
        mz_debug_message("Including ${_inc} for headers")
    endforeach(_inc)
    foreach(_lib $ENV{LIB})
        file(TO_CMAKE_PATH ${_lib} _lib)
        link_directories("${_lib}")
        mz_debug_message("Including ${_lib} for libs")
    endforeach(_lib)
endif()
