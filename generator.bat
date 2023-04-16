@echo off

REM REM
REM Copyright 2008 - 2022 Marius Zwicker
REM All rights reserved.
REM
REM @LICENSE_HEADER_START:Apache@
REM
REM Licensed under the Apache License, Version 2.0 - the "License";
REM you may not use this file except in compliance with the License.
REM You may obtain a copy of the License at
REM
REM     http://www.apache.org/licenses/LICENSE-2.0
REM
REM Unless required by applicable law or agreed to in writing, software
REM distributed under the License is distributed on an "AS IS" BASIS,
REM WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
REM See the License for the specific language governing permissions and
REM limitations under the License.
REM
REM http://www.mlba-team.de
REM
REM @LICENSE_HEADER_END:Apache@
REM REM

goto MAIN

:help
    echo.
    echo.==============================================
    echo.
    echo.This file generates a project configuration for configuring
    echo.cmake using a predefined directory naming scheme
    echo.
    echo.Usage:
    echo."    generator.bat (release|reldbg|debug) (ninja|vs2019|ninja_64|vs2019_64) (inside|outside) (<other cmake args...>)"
    echo.
GOTO:EOF

:debug_hint
    echo.
    echo.IMPORTANT HINT: When using this script to generate projects with build
    echo.type 'debug', please use the 'Debug' configuration for building
    echo.binaries only. Otherwise dependencies might not be set correctly.
    echo.
    echo.TRICK: To Build a Release Binary, run with first argument 'release' given
GOTO:EOF

:detect_build_mode
    set MY_BUILD_MODE=Release
    if "%BUILD_MODE%" == "debug" (
        set MY_BUILD_MODE=Debug
    )
    if "%MY_BUILD_MODE%" == "reldbg" (
        set MY_BUILD_MODE=RelDbg
    )

    REM set MY_VCINSTALLDIR=%VCINSTALLDIR:"=%
    echo.
    set MY_VCINSTALLDIR=%ProgramFiles(x86)%\Microsoft Visual Studio\2019\Community\VC
    echo.-- Using Visual Studio at %MY_VCINSTALLDIR%

    if "%GENERATOR%" == "vs2019" (
        call "%MY_VCINSTALLDIR%\Auxiliary\Build\vcvarsall.bat" x86
        set MY_GENERATOR="Visual Studio 16 2019" -A x86
    )
    if "%GENERATOR%" == "vs2019_64" (
        call "%MY_VCINSTALLDIR%\Auxiliary\Build\vcvarsall.bat" x64
        set MY_GENERATOR="Visual Studio 16 2019" -A x64
    )
    if "%GENERATOR%" == "ninja" (
        call "%MY_VCINSTALLDIR%\Auxiliary\Build\vcvarsall.bat" x86
        set MY_GENERATOR="Ninja"
    )
    if "%GENERATOR%" == "ninja_64" (
        call "%MY_VCINSTALLDIR%\Auxiliary\Build\vcvarsall.bat" x64
        set MY_GENERATOR=Ninja
    )

GOTO:EOF

:detect_dir
    echo.
    echo.== running global configuration

    REM dirty hack, to detect build root
    cd /d "%~dp0"
    cd ..
    set "BASE_DIR=%CD%"

    set "BUILD_DIR=%BASE_DIR%_win32-%GENERATOR%-%BUILD_MODE%"
    if "%LOCATION%" == "inside" (
        set "BUILD_DIR=%BASE_DIR%\build\win32-%GENERATOR%-%BUILD_MODE%"
    )

    cd build
    echo.-- determining working directory: %BASE_DIR%\build
    echo.-- build root will be: %BASE_DIR%
    echo.-- generating to: %BUILD_DIR%
    echo.
GOTO:EOF

:run_cmake
    if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
    cd %BUILD_DIR%

    echo.== configuring target system '%GENERATOR%/%BUILD_MODE%'
    cmake -D CMAKE_BUILD_TYPE=%MY_BUILD_MODE% %EXTRA_ARGS% -G%MY_GENERATOR% "%BASE_DIR%/"
GOTO:EOF

:MAIN

if "%3" == "" (
    call:help
    goto EXIT
)

REM separate the arguments, all above %3 are optional
set BUILD_MODE=%1
shift
set GENERATOR=%1
shift
set LOCATION=%1
shift
for /f "tokens=3,* delims= " %%a in ("%*") do set EXTRA_ARGS=%%b

call:debug_hint
call:detect_build_mode
call:detect_dir
call:run_cmake
goto END

:END
cd %BASE_DIR%\build
echo.All DONE
:EXIT
