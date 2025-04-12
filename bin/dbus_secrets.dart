import 'package:dbus_secrets/dbus_secrets.dart';

// This is an example of using the simplified DBusSecrets class
void main() async {
  print('Starting DBusSecrets API example');

  // Create an instance of DBusSecrets
  final secrets = DBusSecrets(appName: 'example_app');

  // Initialize the connection to the D-Bus Secrets service
  if (await secrets.initialize()) {
    print('Connected to D-Bus Secrets service');

    // Unlock the collection (required before any operations)
    print('\nUnlocking collection...');
    final unlockResult = await secrets.unlock();
    print('Unlock result: ${unlockResult ? 'Success' : 'Failed'}');

    if (unlockResult) {
      // Example key and password
      const exampleKey = 'api_key';
      const examplePassword = 'my_secure_password_123';

      // Set a secret
      print('\nSetting secret...');
      final setResult = await secrets.set(exampleKey, examplePassword);
      print('Set result: ${setResult ? 'Success' : 'Failed'}');

      // Get the secret
      print('\nGetting secret...');
      final retrievedSecret = await secrets.get(exampleKey);
      print('Retrieved secret: $retrievedSecret');

      // Verify the secret matches
      if (retrievedSecret == examplePassword) {
        print('Secret verification: Success');
      } else {
        print('Secret verification: Failed');
      }

      // Delete the secret
      print('\nDeleting secret...');
      final deleteResult = await secrets.delete(exampleKey);
      print('Delete result: ${deleteResult ? 'Success' : 'Failed'}');

      // Verify the secret is deleted
      print('\nVerifying deletion...');
      final afterDeleteSecret = await secrets.get(exampleKey);
      if (afterDeleteSecret == null) {
        print('Secret deletion verification: Success');
      } else {
        print('Secret deletion verification: Failed');
      }
    } else {
      print('Failed to unlock collection, cannot perform operations');
    }

    // Close the connection
    await secrets.close();
    print('\nConnection closed');
  } else {
    print('Failed to connect to D-Bus Secrets service');
  }

  print('\nDBusSecrets API example completed');
}
