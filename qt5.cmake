#
# qt5.cmake
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

##################################################
#
#   BUILD/QT5.CMAKE
#
#   Takes care of fixing up some issues found with qt5
#   cmake integration
#
# PROVIDED MACROS
# -----------------------
# mz_qt_auto_moc <variable> <file1> [<file2> ...]
#   Similar to qt5_wrap_cpp but applying a few tweaks to
#   e.g. avoid conflicts with boost signals.
#
# mz_qt_add_resources <variable> <file1> [<file2> ...]
#   Similar to qt5_add_resources but offering a single
#   place to select between using the QtQuickCompiler
#   feature to pregenerate QML bytecode or not.
#
########################################################################

mz_include_guard(GLOBAL)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 Network Positioning Location)
if( MZ_IOS )
    find_library(FOUNDATION Foundation REQUIRED)
    find_library(SECURITY Security REQUIRED)
    find_library(UIKIT UIKit REQUIRED)
    find_library(CORESERVICES CoreServices REQUIRED)
    find_library(CORETEXT CoreText REQUIRED)
    find_library(COREGRAPHICS CoreGraphics REQUIRED)
    find_library(SYSTEMCONFIGURATION SystemConfiguration REQUIRED)
    find_library(METAL Metal REQUIRED)

    target_link_libraries(Qt5::Core INTERFACE
        ${SECURITY} ${FOUNDATION} ${CORESERVICES} ${UIKIT} ${CORETEXT} ${COREGRAPHICS} ${SYSTEMCONFIGURATION}
    )
    target_link_libraries(Qt5::Gui INTERFACE
        ${METAL}
    )
endif()


# Track paths
set(MZ_HAS_QT5 TRUE  CACHE INTERNAL MZ_HAS_QT5 FORCE)
string(REPLACE "/lib" "" _qt5Core_install_prefix ${Qt5_Core_LIB_DIRS})
set(Qt5_PREFIX "${_qt5Core_install_prefix}" CACHE PATH "Directory containing the Qt5 installation" FORCE )
set(QT_QMAKE_EXECUTABLE "${Qt5_PREFIX}/bin/qmake${CMAKE_EXECUTABLE_SUFFIX}" CACHE INTERNAL QT_QMAKE_EXECUTABLE FORCE)
set(QT_MOC_EXECUTABLE "${Qt5_PREFIX}/bin/moc${CMAKE_EXECUTABLE_SUFFIX}" CACHE INTERNAL QT_MOC_EXECUTABLE FORCE)
set(QT_MAC_DEPLOY_QT  "${Qt5_PREFIX}/bin/macdeployqt${CMAKE_EXECUTABLE_SUFFIX}" CACHE INTERNAL QT_MAC_DEPLOY_QT FORCE)
set(QT_RCC_EXECUTABLE "${Qt5_PREFIX}/bin/rcc${CMAKE_EXECUTABLE_SUFFIX}" CACHE INTERNAL QT_RCC_EXECUTABLE FORCE)
set(QT_UIC_EXECUTABLE "${Qt5_PREFIX}/bin/uic${CMAKE_EXECUTABLE_SUFFIX}" CACHE INTERNAL QT_UIC_EXECUTABLE FORCE)
set(QT_QUICK_COMPILER "${Qt5_PREFIX}/bin/qmlcachegen${CMAKE_EXECUTABLE_SUFFIX}" CACHE INTERNAL QT_QUICK_COMPILER FORCE)
if(EXISTS "${Qt5_PREFIX}/bin/archdatadir") # check if this is a conan install
    set(QT_PLUGINS_DIR "${Qt5_PREFIX}/bin/archdatadir/plugins" CACHE INTERNAL QT_PLUGINS_DIR FORCE)
    set(QT_TRANSLATIONS_DIR "${Qt5_PREFIX}/bin/datadir/translations" CACHE INTERNAL QT_TRANSLATIONS_DIR FORCE)
    set(QT_QUICK_DIR "${Qt5_PREFIX}/bin/archdatadir/qml" CACHE INTERNAL QT_QUICK FORCE)
else()
    set(QT_PLUGINS_DIR "${Qt5_PREFIX}/plugins" CACHE INTERNAL QT_PLUGINS_DIR FORCE)
    set(QT_TRANSLATIONS_DIR "${Qt5_PREFIX}/translations" CACHE INTERNAL QT_TRANSLATIONS_DIR FORCE)
    set(QT_QUICK_DIR "${Qt5_PREFIX}/qml" CACHE INTERNAL QT_QUICK FORCE)
endif()

# Workaround as in the conan package the double-conversion and pcre dlls are not in the path by default
if(WIN32)
    if(EXISTS ${CONAN_DOUBLE-CONVERSION_ROOT}/bin/double-conversion.dll)
        file(COPY ${CONAN_DOUBLE-CONVERSION_ROOT}/bin/double-conversion.dll DESTINATION "${Qt5_PREFIX}/bin")
    endif()
    if(EXISTS ${CONAN_DOUBLE-CONVERSION_ROOT}/bin/double-conversion.dll)
        file(COPY ${CONAN_PCRE2_ROOT}/bin/pcre2-16.dll DESTINATION "${Qt5_PREFIX}/bin")
    endif()
endif()

# Support QtQuickCompiler even on the Conan package
if(NOT QTQUICK_COMPILER_ADD_RESOURCES)
    include(build/Conan/Qt5QuickCompilerConfig.cmake)
endif()

# Status reporting
mz_message("Qt5::qmake  '${QT_QMAKE_EXECUTABLE}'")
mz_message("Qt5::moc    '${QT_MOC_EXECUTABLE}'")
mz_message("Qt5::rcc    '${QT_RCC_EXECUTABLE}'")
mz_message("Qt5::uic    '${QT_UIC_EXECUTABLE}'")
mz_message("Qt5::quickc '${QT_QUICK_COMPILER}'")

# Make sure discovery of plugings and the like works
file(COPY ${Qt5_PREFIX}/bin/qt.conf DESTINATION ${EXECUTABLE_OUTPUT_PATH})
file(APPEND ${EXECUTABLE_OUTPUT_PATH}/qt.conf "
Prefix = ${Qt5_PREFIX}
")

# Extra macros
macro(__mz_extract_files _qt_files)
    set(${_qt_files})
    foreach(_current ${ARGN})
        file(STRINGS ${_current} _content LIMIT_COUNT 1 REGEX .*Q_OBJECT.*)
        if("${_content}" MATCHES .*Q_OBJECT.*)
            list(APPEND ${_qt_files} "${_current}")
        endif()
        file(STRINGS ${_current} _content LIMIT_COUNT 1 REGEX .*Q_GADGET.*)
        if("${_content}" MATCHES .*Q_GADGET.*)
            list(APPEND ${_qt_files} "${_current}")
        endif()
    endforeach()
endmacro()

# Wrapper around qt5_wrap_cpp to gain more flexibility
# over global configuration such as additional defines
macro(mz_qt_auto_moc mocced)
    #mz_debug_message("mz_qt_auto_moc input: ${ARGN}")
    cmake_parse_arguments(mz_qt_auto_moc "" "TARGET" "" ${ARGN} )
    #if( CMAKE_AUTOMOC )
    #    mz_warning_message( "cmake automoc is enabled, this can cause issues" )
    #endif()
    set(_mocced "")
    # determine the required files
    __mz_extract_files(to_moc ${mz_qt_auto_moc_UNPARSED_ARGUMENTS})
    mz_debug_message("mz_qt_auto_moc mocced in: ${to_moc}")
    if( mz_qt_auto_moc_TARGET )
        # the definition of -DBOOST_TT_HAS_OPERATOR_HPP_INCLUDED is to bypass a parsing bug within moc
        qt5_wrap_cpp(_mocced ${to_moc} TARGET ${mz_qt_auto_moc_TARGET} OPTIONS -DBOOST_TT_HAS_OPERATOR_HPP_INCLUDED -DBOOST_NO_TEMPLATE_PARTIAL_SPECIALIZATION)
    else()
        # the definition of -DBOOST_TT_HAS_OPERATOR_HPP_INCLUDED is to bypass a parsing bug within moc
        qt5_wrap_cpp(_mocced ${to_moc} OPTIONS -DBOOST_TT_HAS_OPERATOR_HPP_INCLUDED -DBOOST_NO_TEMPLATE_PARTIAL_SPECIALIZATION)
    endif()
    set(${mocced} ${${mocced}} ${_mocced})
endmacro()

# Wrapper around qt5_add_resources to gain more flexibility
# over global configuration such as switching the QtQuick compiler on and off
macro(mz_qt_add_resources)
    if( COMMAND qtquick_compiler_add_resources )
        qtquick_compiler_add_resources(${ARGV})
    else()
        qt5_add_resources(${ARGV})
    endif()
endmacro()
