# DBusSecrets

A lightweight Dart package for securely storing and retrieving secrets using the Linux Secret Service API via D-Bus.

## Overview

DBusSecrets provides a simple interface to interact with the Linux keyring (GNOME Keyring, KDE Wallet, etc.) for securely storing sensitive information such as passwords, API keys, and tokens. The package uses the D-Bus Secret Service API to communicate with the system's keyring service.

### Key Features

- **Secure Storage**: Store sensitive data in the system's encrypted keyring
- **Persistent**: Secrets remain stored even after logout (encrypted on disk)
- **Simple API**: Easy-to-use methods for storing, retrieving, and deleting secrets
- **Native Integration**: Uses the standard Linux Secret Service API

## Installation

Add DBusSecrets to your `pubspec.yaml` file:

```yaml
dependencies:
  dbus_secrets: ^0.0.1
```

Then run:

```bash
dart pub get
```

## Requirements

- Linux operating system with a Secret Service provider (GNOME Keyring, KDE Wallet, etc.)
- D-Bus system

## Usage

### Basic Example

```dart
import 'package:dbus_secrets/dbus_secrets.dart';

Future<void> main() async {
  // Create an instance with your application name
  final secrets = DBusSecrets(appName: 'my_application');
  
  // Initialize the connection
  await secrets.initialize();
  
  // Unlock the keyring (may prompt for user password)
  await secrets.unlock();
  
  // Store a secret
  await secrets.set('api_key', 'my_secret_api_key_123');
  
  // Retrieve a secret
  final apiKey = await secrets.get('api_key');
  print('Retrieved API key: $apiKey');
  
  // Delete a secret
  await secrets.delete('api_key');
  
  // Close the connection when done
  await secrets.close();
}
```

### Complete Example

See the `bin/dbus_secrets.dart` file for a complete example that demonstrates all features.

## Security Considerations

- Secrets are stored in the system's keyring, which encrypts them on disk
- The keyring must be unlocked before any operations can be performed
- Authentication is typically handled by the system's keyring service
- This package uses the "plain" authentication method with D-Bus, which is suitable for local system communication

## License

This project is licensed under the MIT License - see the LICENSE file for details.
