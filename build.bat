@echo off
if not exist build mkdir build


set game_path=src\game


pushd build

robocopy ..\assets .\assets /s > nul
robocopy ..\lib . /s > nul

set exeName=DanMofu

set flags=-out:%exeName%.exe 
rem set flags=%flags% -max-error-count:5

if "%1" == "release" (
    echo "RELEASE"
    set flags=%flags% -o:speed -subsystem:windows 
) else (
    set flags=%flags% -o:none -debug
)


del %exeName%.exe

odin build ..\%game_path% -debug -build-mode=dll -out="Game.dll" && ^
odin run ..\src\platform_win32 %flags%

popd