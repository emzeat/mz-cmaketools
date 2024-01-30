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

# collect any active VS environment
# No smart way to simply iterate the environment in CMake :(
macro(presetEnvAdd VAR)
    if(DEFINED ENV{${VAR}})
        string(REPLACE ";" "$<SEMICOLON>" _TMP "$ENV{${VAR}}" )
        string(REPLACE "\\" "\\\\" _TMP "${_TMP}" )
        list(APPEND PRESET_ENV "\"${VAR}\": \"${_TMP}\"")
    endif()
endmacro()
presetEnvAdd(DevEnvDir)
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
presetEnvAdd(__VSCMD_PREINIT_PATH)

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
    string(REPLACE ";" "$<SEMICOLON>" _CONAN_PATH "${_MZ_CONAN_PATH}" )
    execute_process(COMMAND ${PYTHON3} -m site --user-base
        COMMAND_ECHO STDOUT
        OUTPUT_VARIABLE _MZ_PYTHON3_USER_BASE
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    string(REPLACE "\\" "\\\\" _MZ_PYTHON3_USER_BASE "${_MZ_PYTHON3_USER_BASE}")
    list(APPEND PRESET_ENV "\"PATH\": \"${_MZ_PYTHON3_USER_BASE}/bin$<SEMICOLON>${_MZ_PYTHON3_USER_BASE}/Scripts$<SEMICOLON>${_CONAN_PATH}$<SEMICOLON>\$penv{PATH}\"")
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
execute_process(
    COMMAND_ECHO STDOUT
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    COMMAND ${PYTHON3} ${MZ_TOOLS_PATH}/presets.py
        --output ${CMAKE_SOURCE_DIR}/CMakeUserPresets.json
        --add ${PRESET_JSON}
)
