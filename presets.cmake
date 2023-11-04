# presets.cmake
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

##################################################
#
# BUILD/PRESETS.CMAKE
#
#   Include in your project or through global.cmake to automatically
#   populate CMakePresets.txt with info on your configured build tree
#
########################################################################

# determine preset id and location
get_filename_component(PRESET_NAME "${CMAKE_BINARY_DIR}" NAME)
set(PRESET_JSON ${CMAKE_BINARY_DIR}/CMakePresets.json)
if(CONAN_EXPORTED)
    mz_message("Presets disabled during Conan export")
    return()
endif()
if(MZ_WINDOWS)
    set(_MZ_PATH_SEP ";")
else()
    set(_MZ_PATH_SEP ":")
endif()

# helper to only write a file when changed
function(mz_write_if_changed FILENAME CONTENT)
    if(EXISTS ${FILENAME})
        file(READ ${FILENAME} _before)
    endif()
    if(_before STREQUAL CONTENT)
        message(DEBUG "No change in ${FILENAME}")
    else()
        file(WRITE ${FILENAME} ${CONTENT})
    endif()
endfunction()

# collect other presets
if(EXISTS ${CMAKE_SOURCE_DIR}/CMakeUserPresets.json)
    file(READ ${CMAKE_SOURCE_DIR}/CMakeUserPresets.json _PRESET_JSON)
    string(JSON _PRESET_INCLUDE_LEN ERROR_VARIABLE _PRESET_DISCARD LENGTH "${_PRESET_JSON}" include)
    if(_PRESET_INCLUDE_LEN GREATER 0)
        foreach(_PRESET_INCLUDE_INDEX RANGE 1 ${_PRESET_INCLUDE_LEN})
            math(EXPR _PRESET_INCLUDE_INDEX "${_PRESET_INCLUDE_INDEX} - 1")
            string(JSON _PRESET_INCLUDE GET "${_PRESET_JSON}" include ${_PRESET_INCLUDE_INDEX})
            if(EXISTS "${_PRESET_INCLUDE}")
                list(APPEND PRESET_INCLUDES "\"${_PRESET_INCLUDE}\"")
            endif()
        endforeach()
    endif()
endif()

# collect any active VS environment
# No smart way to simply iterate the environment in CMake :(
macro(presetEnvAdd VAR)
    if(DEFINED ENV{${VAR}})
        string(REPLACE ";" "$<SEMICOLON>" _TMP "$ENV{${VAR}}" )
        string(REPLACE "\\" "\\\\" _TMP "${_TMP}" )
        list(APPEND PRESET_ENV "\"${VAR}\": \"${_TMP}\"")
    endif()
endmacro()
presetEnvAdd(ExtensionSdkDir)
presetEnvAdd(INCLUDE)
presetEnvAdd(LIB)
presetEnvAdd(LIBPATH)
presetEnvAdd(UCRTVersion)
presetEnvAdd(UniversalCRTSdkDir)
presetEnvAdd(VCIDEInstallDir)
presetEnvAdd(VCINSTALLDIR)
presetEnvAdd(VCToolsInstallDir)
presetEnvAdd(VCToolsRedistDir)
presetEnvAdd(VCToolsVersion)
presetEnvAdd(VisualStudioVersion)
presetEnvAdd(VS160COMNTOOLS)
presetEnvAdd(VSCMD_ARG_app_plat)
presetEnvAdd(VSCMD_ARG_HOST_ARCH)
presetEnvAdd(VSCMD_ARG_TGT_ARCH)
presetEnvAdd(VSCMD_VER)
presetEnvAdd(VSINSTALLDIR)
presetEnvAdd(windir)
presetEnvAdd(WindowsLibPath)
presetEnvAdd(WindowsSdkBinPath)
presetEnvAdd(WindowsSdkDir)
presetEnvAdd(WindowsSDKLibVersion)
presetEnvAdd(WindowsSdkVerBinPath)
presetEnvAdd(WindowsSDKVersion)

# collect env and cmake variables
if(CMAKE_C_COMPILER)
    list(APPEND PRESET_VARIABLES "\"CMAKE_C_COMPILER\": \"${CMAKE_C_COMPILER}\"")
endif()
if(CMAKE_CXX_COMPILER)
    list(APPEND PRESET_VARIABLES "\"CMAKE_CXX_COMPILER\": \"${CMAKE_CXX_COMPILER}\"")
endif()
if(CMAKE_TOOLCHAIN_FILE)
    list(APPEND PRESET_VARIABLES "\"CMAKE_TOOLCHAIN_FILE\": \"${CMAKE_TOOLCHAIN_FILE}\"")
endif()
if(CMAKE_BUILD_TYPE)
    list(APPEND PRESET_VARIABLES "\"CMAKE_BUILD_TYPE\": \"${CMAKE_BUILD_TYPE}\"")
endif()
if(_MZ_CONAN_PATH)
    string(REPLACE ";" "$<SEMICOLON>" _TMP "${_MZ_CONAN_PATH}" )
    list(APPEND PRESET_ENV "\"PATH\": \"${_TMP}$<SEMICOLON>\$penv{PATH}\"")
endif()
list(APPEND PRESET_INCLUDES "\"${PRESET_JSON}\"")
list(REMOVE_DUPLICATES PRESET_VARIABLES)
list(JOIN PRESET_VARIABLES ",\n                " PRESET_VARIABLES)
list(REMOVE_DUPLICATES PRESET_ENV)
list(JOIN PRESET_ENV ",\n                " PRESET_ENV)
string(REPLACE "$<SEMICOLON>" "${_MZ_PATH_SEP}" PRESET_ENV "${PRESET_ENV}" )
list(REMOVE_DUPLICATES PRESET_INCLUDES)
list(JOIN PRESET_INCLUDES ",\n        " PRESET_INCLUDES)

# write the binary dir specific presets
mz_write_if_changed(${PRESET_JSON}
"{
    \"version\": 6,
    \"cmakeMinimumRequired\": {
        \"major\": 3,
        \"minor\": 23,
        \"patch\": 0
    },
    \"configurePresets\": [
        {
            \"name\": \"${PRESET_NAME}\",
            \"displayName\": \"${PRESET_NAME}\",
            \"generator\": \"${CMAKE_GENERATOR}\",
            \"binaryDir\": \"${CMAKE_BINARY_DIR}\",
            \"cacheVariables\": {
                ${PRESET_VARIABLES}
            },
            \"environment\": {
                ${PRESET_ENV}
            }
        }
    ],
    \"buildPresets\": [
        {
            \"name\": \"${PRESET_NAME}\",
            \"configurePreset\": \"${PRESET_NAME}\",
            \"inheritConfigureEnvironment\": true
        }
    ],
    \"testPresets\": [
        {
            \"name\": \"${PRESET_NAME}\",
            \"configurePreset\": \"${PRESET_NAME}\",
            \"output\": {\"outputOnFailure\": true},
            \"execution\": {\"stopOnFailure\": true},
            \"inheritConfigureEnvironment\": true
        }
    ]
}"
)

# make sure the presets get included from the toplevel
file(REMOVE ${CMAKE_SOURCE_DIR}/CMakePresets.json)
mz_write_if_changed(${CMAKE_SOURCE_DIR}/CMakeUserPresets.json
"{
    \"version\": 6,
    \"cmakeMinimumRequired\": {
        \"major\": 3,
        \"minor\": 23,
        \"patch\": 0
    },
    \"include\": [
        ${PRESET_INCLUDES}
    ]
}")
