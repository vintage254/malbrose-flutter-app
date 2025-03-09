@echo off
echo Copying required system DLLs...

REM Create directory for UCRT DLLs
if not exist "%~dp0ucrt" mkdir "%~dp0ucrt"

REM Copy Universal C Runtime DLLs from Windows
xcopy /y "%SystemRoot%\System32\ucrtbase.dll" "%~dp0"
xcopy /y "%SystemRoot%\System32\vcruntime140.dll" "%~dp0"
xcopy /y "%SystemRoot%\System32\msvcp140.dll" "%~dp0"

REM Copy API-MS-WIN DLLs from System32
xcopy /y "%SystemRoot%\System32\api-ms-win-*.dll" "%~dp0ucrt\"

echo DLL copying complete.
exit /b 0
