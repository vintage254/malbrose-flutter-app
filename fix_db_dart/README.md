# Malbrose Database Fix Utility

A simple command-line tool to fix the UNIQUE constraint issue in the Malbrose app's SQLite database.

## What This Tool Does

This utility fixes an issue with the `creditors` table in the Malbrose app's database that causes unique constraint violations when processing credit sales with the same customer name. Specifically, it:

1. Locates the database file (searches in multiple common locations)
2. Makes sure the file is writable
3. Creates a backup of the original database
4. Removes the UNIQUE constraint from the `name` column in the `creditors` table
5. Preserves all existing data

## Usage

### Option 1: Run the Dart script (requires Dart SDK)

```bash
cd fix_db_dart
dart pub get
dart run
```

### Option 2: Run the PowerShell script (Windows only)

```powershell
.\fix_db.ps1
```

The PowerShell script will attempt to download SQLite tools if needed.

## Requirements

For the Dart script:
- Dart SDK 3.0.0 or higher

For the PowerShell script:
- Windows PowerShell
- SQLite command-line tools (the script can download these for you)

## Troubleshooting

If the fix doesn't work:

1. Make sure your app is not running (close all instances)
2. Check if the database file is read-only
3. Try running the script with administrator privileges
4. Manually copy the backup file (`malbrose_db.db.bak`) to restore if needed

## After Running the Fix

After successfully running this fix:

1. The database should allow multiple creditors with the same name
2. All existing data should be preserved
3. Credit sales should process without the unique constraint error
