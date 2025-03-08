# Malbrose POS System

A comprehensive Point of Sale (POS) system for hardware stores and retail businesses, built with Flutter.

## Features

- **User Management**: Multi-level user access with admin and regular user roles
- **Inventory Management**: Track products, stock levels, and pricing
- **Sales Processing**: Create and manage sales orders with customer information
- **Customer Management**: Store customer details and track purchase history
- **Reporting**: Generate sales reports, inventory reports, and customer reports
- **Activity Logging**: Track all system activities for auditing purposes
- **Backup & Restore**: Automated database backup and restore functionality
- **Receipt Printing**: Generate and print receipts for customers
- **Multi-Computer Setup**: Master-Slave configuration for multiple POS terminals
- **Offline Capability**: Works without internet connection

## System Requirements

- **Operating System**: Windows, Linux, or macOS
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 500MB free space
- **Printer**: Compatible with thermal receipt printers (optional)

## Installation

### Windows
1. Download the latest release from the [Releases](https://github.com/yourusername/malbrose-flutter-app/releases) page
2. Extract the ZIP file to your desired location
3. Run `malbrose_pos.exe`

### Linux
1. Download the latest release from the [Releases](https://github.com/yourusername/malbrose-flutter-app/releases) page
2. Extract the tarball: `tar -xzf malbrose_pos_linux.tar.gz`
3. Make the file executable: `chmod +x malbrose_pos`
4. Run the application: `./malbrose_pos`

### macOS
1. Download the latest release from the [Releases](https://github.com/yourusername/malbrose-flutter-app/releases) page
2. Mount the DMG file
3. Drag the application to your Applications folder
4. Run the application from your Applications folder

## First-Time Setup

When you first run the application, you'll be guided through a setup wizard:

1. Choose between Master (Server) or Slave (Client) setup
2. For Master setup:
   - Configure database settings
   - Create an admin user
   - Enter business information
3. For Slave setup:
   - Enter the IP address of the Master computer
   - Configure connection settings

## Development Setup

If you want to build the application from source:

1. Install [Flutter](https://flutter.dev/docs/get-started/install)
2. Clone this repository:
   ```
   git clone https://github.com/yourusername/malbrose-flutter-app.git
   ```
3. Navigate to the project directory:
   ```
   cd malbrose-flutter-app
   ```
4. Get dependencies:
   ```
   flutter pub get
   ```
5. Run the application:
   ```
   flutter run
   ```

## Building for Production

### Windows
```
flutter build windows --release
```

### Linux
```
flutter build linux --release
```

### macOS
```
flutter build macos --release
```

## Database Structure

The application uses SQLite for data storage with the following main tables:

- `users`: User accounts and permissions
- `products`: Inventory items with pricing and stock information
- `orders`: Sales transactions
- `order_items`: Individual items in each order
- `customers`: Customer information
- `activity_logs`: System activity tracking
- `creditors`: Credit management
- `debtors`: Debt management

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please contact [support@malbrose.com](mailto:support@malbrose.com) or open an issue on GitHub.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [SQLite](https://www.sqlite.org/)
- [PDF](https://pub.dev/packages/pdf)
- [Printing](https://pub.dev/packages/printing)
- All contributors who have helped with the development of this project
