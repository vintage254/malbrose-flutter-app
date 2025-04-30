# Malbrose POS System

A comprehensive Point of Sale (POS) system for retail businesses, built with Flutter.

## Features

- **User Management**: Multi-level user access with admin and regular user roles
- **Inventory Management**: Track products, stock levels, and pricing
- **Sales Processing**: Create and manage sales orders with customer information
- **Customer Management**: Store customer details and track purchase history
- **Reporting**: Generate sales reports, inventory reports, and customer reports
- **Activity Logging**: Detailed activity tracking for all system operations
- **Backup & Restore**: Database backup and restore functionality
- **Receipt Printing**: Generate and print receipts with customizable templates
- **Multi-Computer Setup**: Master-Servant configuration for multiple POS terminals
- **Offline Capability**: Works completely offline with no internet requirement
- **License Management**: 14-day trial period with simple license activation system
- **Tax Management**: Configure VAT and tax settings for your business
- **Security Features**: SSL/TLS configuration for secure network communication

## System Requirements

- **Operating System**: Windows 10 or later
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 500MB free space
- **Printer**: Compatible with thermal receipt printers (optional)
- **Network**: Local network for multi-computer setup (optional)

## Installation

### Windows
1. Download the installer file (Malbrose POS.exe, ~49MB)
2. Run the installer and follow the prompts
3. The application will launch automatically after installation

## First-Time Setup

When you first run the application, you'll be guided through a setup wizard:

1. Choose between Master (Server) or Servant (Client) setup
2. For Master setup:
   - Configure database settings
   - Create an admin user
   - Enter business information
   - Setup tax and receipt settings
3. For Servant setup:
   - Discover available Master machines on your network
   - Connect to the selected Master

## License Information

- The application includes a 14-day free trial
- After the trial period, a license key is required to continue using the application
- License key can be entered in the Settings > License tab
- Contact support at malbrosepos@gmail.com to purchase a license key

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
- `settings`: Application configuration

## Development

### Building for Production
```
flutter build windows --release --obfuscate --split-debug-info=symbols
```

### Creating Installer
The application uses Inno Setup to create a Windows installer. The installer script (installer.iss) is included in the project.

## Support

For support, please contact [malbrosepos@gmail.com](mailto:malbrosepos@gmail.com) or call +254 748322954.

## Security

The application implements several security features:
- SSL/TLS configuration for network communication
- Encrypted license keys using SHA-256
- Activity logging for audit trails
- Role-based access control

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [SQLite](https://www.sqlite.org/)
- [PDF](https://pub.dev/packages/pdf)
- [Printing](https://pub.dev/packages/printing)
- All contributors who have helped with the development of this project
