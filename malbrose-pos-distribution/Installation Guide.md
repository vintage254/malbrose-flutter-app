# Malbrose POS - Manual Installation Guide

This document provides instructions for manually installing the Malbrose POS application without using the installer.

## System Requirements

- Windows 10 or Windows 11 (64-bit)
- At least 4GB of RAM
- At least 500MB of free disk space

## Installation Steps

### 1. Install Prerequisites

Before running the application, you need to install the following prerequisites:

1. **Visual C++ Redistributable Packages**
   - Download and install the Visual C++ Redistributable Packages for Visual Studio 2015-2022:
     - [Visual C++ Redistributable x64](https://aka.ms/vs/17/release/vc_redist.x64.exe)
     - [Visual C++ Redistributable x86](https://aka.ms/vs/17/release/vc_redist.x86.exe)

### 2. Extract the Application Files

1. Create a folder where you want to install the application (e.g., `C:\Program Files\Malbrose POS`)
2. Extract all files from the ZIP archive to this folder
3. Make sure the following files and folders are present:
   - `my_flutter_app.exe` (main application executable)
   - `flutter_windows.dll`
   - `data` folder (contains application assets)
   - Other DLL files that came with the ZIP

### 3. Create Shortcuts (Optional)

1. **Desktop Shortcut**
   - Right-click on `my_flutter_app.exe`
   - Select "Create shortcut"
   - Move the shortcut to your desktop

2. **Start Menu Shortcut**
   - Right-click on `my_flutter_app.exe`
   - Select "Create shortcut"
   - Move the shortcut to `C:\ProgramData\Microsoft\Windows\Start Menu\Programs`

## Running the Application

1. Double-click on `my_flutter_app.exe` or use the shortcuts you created
2. The application should start without any issues

## Troubleshooting

If you encounter any issues running the application:

1. **Missing DLL Error**
   - Make sure you've installed both Visual C++ Redistributable Packages mentioned above
   - Ensure all files from the ZIP archive were extracted to the same folder

2. **Application Crashes on Startup**
   - Check that the `data` folder is in the same directory as the executable
   - Verify that you're using a 64-bit version of Windows

3. **Other Issues**
   - Try running the application as administrator (right-click on `my_flutter_app.exe` and select "Run as administrator")

## Uninstallation

To uninstall the application:

1. Delete the folder where you extracted the application files
2. Remove any shortcuts you created

## Support

If you need assistance with installation or encounter any issues, please contact support at:
- Email: support@example.com
- Phone: (123) 456-7890
