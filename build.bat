@echo off
if not exist build mkdir build


set game_path=src\game


pushd build

robocopy ..\assets .\assets /s > nul
robocopy ..\lib . /s > nul

set exeName=DanMofu

set flags=""
rem set flags=%flags% -max-error-count:5

if "%1" == "release" (
    echo "RELEASE"
    set flags=%flags% -o:speed -subsystem:windows 
) else (
    set flags=%flags% -o:none -debug
)

set justGame=F
if "%1" == "justGame" set justGame=T
if "%2" == "justGame" set justGame=T

if "%justGame%"=="F" (
    echo "Building Platform"
    del %exeName%.exe
    odin build ..\src\platform_win32 %flags% -out:%exeName%.exe 
)

rem odin build ..\%game_path% %flags% -build-mode=dll -out="Game.dll" && ^%exeName%.exe
odin build ..\%game_path% %flags% -build-mode=dll -out="Game.dll"

popd