# Malbrose POS - Simple Installation Guide

This guide will help you install the Malbrose POS application on your computer.

## What You Need

- A computer with Windows 10 or Windows 11
- About 500MB of free space on your computer
- Administrator access to your computer

## Step-by-Step Installation

### STEP 1: Prepare Your Computer

1. **Create a folder** for the application:
   - Right-click on your Desktop
   - Select "New" → "Folder"
   - Name it "Malbrose POS"
   - Double-click to open the folder

### STEP 2: Install Required Software

Your computer needs some additional software to run Malbrose POS:

1. **Install Visual C++ Package (64-bit)**:
   - Open the "prerequisites" folder from the ZIP
   - Double-click the file named `VC_redist.x64.exe`
   - Click "Yes" if asked for permission
   - Check the box to agree to the terms
   - Click "Install"
   - Wait for installation to complete
   - Click "Close" when finished

2. **Install Visual C++ Package (32-bit)**:
   - Open the "prerequisites" folder from the ZIP
   - Double-click the file named `VC_redist.x86.exe`
   - Follow the same steps as above

### STEP 3: Install Malbrose POS

1. **Copy the application files**:
   - Open the "app" folder from the ZIP
   - Select all files and folders (press Ctrl+A)
   - Right-click and select "Copy" (or press Ctrl+C)
   - Go to the "Malbrose POS" folder you created on your Desktop
   - Right-click inside the folder and select "Paste" (or press Ctrl+V)
   - Make sure the `sqlite3.dll` file is included in the folder

### STEP 4: Create a Shortcut

1. **Make a Desktop shortcut**:
   - In the "Malbrose POS" folder, find the file named `my_flutter_app.exe`
   - Right-click on this file
   - Select "Create shortcut"
   - Rename the shortcut to "Malbrose POS" if you wish
   - Drag the shortcut to your Desktop

### STEP 5: Start the Application

1. **Run Malbrose POS**:
   - Double-click the "Malbrose POS" shortcut on your Desktop
   - The application should start

### STEP 6: Connect to Your Database

When you first start the application, you'll need to set up the database connection:

1. **Enter connection details**:
   - Type the database server address (given by your administrator)
   - Type the username and password
   - Click "Connect"

2. **Important note about wiring**:
   - Make sure your computer and database server have proper grounding
   - The earth cable (usually green/yellow) should be properly connected
   - This prevents electrical issues and data loss

## Common Problems and Solutions

### If the application doesn't start:

1. **Check if you installed both Visual C++ packages**
   - Go back to Step 2 and make sure you installed both packages

2. **Make sure all files were copied**
   - Open the "Malbrose POS" folder
   - Make sure you see the `my_flutter_app.exe` file and a `data` folder

3. **Try running as administrator**
   - Right-click on the shortcut
   - Select "Run as administrator"
   - Click "Yes" if asked for permission

### If you can't connect to the database:

1. **Check your connection details**
   - Make sure the server address, username, and password are correct
   - Ask your administrator for the correct details

2. **Check your internet/network connection**
   - Make sure your computer is connected to the internet/network
   - Try opening a web browser to see if you have internet access

3. **Check the earth cable connection**
   - Make sure the earth cable is properly connected to both the computer and database server
   - This is important for proper functioning and safety

## Need Help?

If you still have problems, please contact support:
- Phone: +254 748322954
- Email: derricknjuguna414@gmail.com

Please have the following information ready:
- The version of Windows you're using
- Any error messages you see
- What step you were on when the problem occurred
