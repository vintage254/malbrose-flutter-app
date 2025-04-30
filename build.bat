@echo off
echo Building Malbrose POS with enhanced security...
echo.

REM Clean build files first
flutter clean

REM Run the build with obfuscation and split debug info
flutter build windows --release --obfuscate --split-debug-info=symbols

echo.
echo Build complete! 
echo The obfuscated application is located in build\windows\x64\runner\Release
echo. 