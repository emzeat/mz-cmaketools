#
# macros.cmake
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

########################################################################
#
# This file defines a whole bunch of macros
# to add a subdirectory containing another
# CMakeLists.txt as "Subproject". All these
# Macros are not doing that much but giving
# feedback to tell what kind of component was
# added. In all cases NAME is the name of your
# subproject and FOLDER is a relative path to
# the folder containing a CMakeLists.txt
#
# mz_add_library <NAME> <FOLDER>
#       macro for adding a new library
#
# mz_add_executable <NAME> <FOLDER>
#       macro for adding a new executable
#
# mz_add_control <NAME> <FOLDER>
#       macro for adding a new control
#
# mz_add_testtool <NAME> <FOLDER>
#       macro for adding a folder containing testtools
#
# mz_add_external <NAME> <FOLDER>
#       macro for adding an external library/tool dependancy
#
# mz_target_props <target>
#       automatically add a "D" postfix when compiling in debug
#       mode to the given target
#
# mz_qt_auto_moc <mocced> ...
#       search all passed files in (...) for Q_OBJECT and if found
#       run moc on them via qt4_wrap_cpp. Assign the output files
#       to <mocced>. Improves the version provided by cmake by searching
#       for Q_OBJECT first and thus reducing the needed calls to moc
#
# mz_download_lfs <FILE>
#       Explicitly download the given file using git-lfs
#
########################################################################

# if global.cmake was not included yet, report it
if (NOT HAS_MZ_GLOBAL)
    message(FATAL_ERROR "!! include global.cmake before including this file !!")
endif()

########################################################################
## no need to change anything beyond here
########################################################################

macro(mz_add_library NAME FOLDER)
    mz_message("adding library ${NAME}")
    __mz_add_target(${NAME} ${FOLDER})
endmacro()

macro(mz_add_executable NAME FOLDER)
    mz_message("adding executable ${NAME}")
    __mz_add_target(${NAME} ${FOLDER})
endmacro()

macro(mz_add_control NAME FOLDER)
    mz_message("adding control ${NAME}")
    __mz_add_target(${NAME} ${FOLDER})
endmacro()

macro(mz_add_testtool NAME FOLDER)
    mz_message("adding testtool ${NAME}")
    __mz_add_target(${NAME} ${FOLDER})
endmacro()

macro(mz_add_external NAME FOLDER)
    mz_message("adding external dependancy ${NAME}")
    __mz_add_target(${NAME} ${FOLDER})
endmacro()

macro(__mz_add_target NAME FOLDER)
    get_filename_component(_ABS_FOLDER ${FOLDER} ABSOLUTE)
    file(RELATIVE_PATH _REL_FOLDER ${CMAKE_SOURCE_DIR} ${_ABS_FOLDER})

    add_subdirectory(${FOLDER} ${CMAKE_BINARY_DIR}/${_REL_FOLDER})
endmacro()

include("${CMAKE_CURRENT_LIST_DIR}/Modules/UseDebugSymbols.cmake")

macro(mz_target_props NAME)
    set_target_properties(${NAME} PROPERTIES DEBUG_POSTFIX "D")
    if( MZ_IS_RELEASE )
        strip_debug_symbols(${NAME})
    endif()
endmacro()

find_host_package(Git)

macro(mz_download_lfs FILE)

    # read the first 7 bytes to test if the file is still an lfs pointer
    file(READ ${FILE} FILE_START LIMIT 7 )
    if( "${FILE_START}" MATCHES "version" )
        # not loaded yet, do so now
        if( NOT GIT_FOUND )
            mz_fatal_message("    Missing GIT, cannot load LFS objects")
        endif()
        mz_message("   Downloading ${FILE}...")
        execute_process(
            COMMAND ${GIT_EXECUTABLE} lfs pull -I ${FILE} -X override-ignore-from-config
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )
    endif()

endmacro()

