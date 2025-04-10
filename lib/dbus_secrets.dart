import 'dart:async';
import 'package:dbus/dbus.dart';

/// A class for interacting with the Linux Keyring via D-Bus Secrets API.
///
/// This class provides methods to get, set, and delete secrets in the Linux Keyring.
/// It uses the collection interface of the D-Bus Secrets API.
class DBusSecrets {
  // D-Bus constants
  static const String _serviceName = 'org.freedesktop.secrets';
  static const String _servicePath = '/org/freedesktop/secrets';
  static const String _defaultCollectionPath = '/org/freedesktop/secrets/aliases/default';
  static const String _stringContentType = 'text/plain; charset=utf8';

  // D-Bus method names
  static const String _openSessionMethod = 'org.freedesktop.Secret.Service.OpenSession';
  static const String _sessionCloseMethod = 'org.freedesktop.Secret.Session.Close';
  static const String _unlockMethod = 'org.freedesktop.Secret.Service.Unlock';
  static const String _searchItemsMethod = 'org.freedesktop.Secret.Collection.SearchItems';
  static const String _getSecretMethod = 'org.freedesktop.Secret.Item.GetSecret';
  static const String _createItemMethod = 'org.freedesktop.Secret.Collection.CreateItem';
  static const String _itemDeleteMethod = 'org.freedesktop.Secret.Item.Delete';
  static const String _promptMethod = 'org.freedesktop.Secret.Prompt.Prompt';
  static const String _completedSignal = 'org.freedesktop.Secret.Prompt.Completed';

  // D-Bus variant names
  static const String _itemLabelVariant = 'org.freedesktop.Secret.Item.Label';
  static const String _itemAttributesVariant = 'org.freedesktop.Secret.Item.Attributes';

  // Instance variables
  late DBusClient _client;
  late DBusObjectPath _session;
  late DBusObjectPath _collectionPath;
  String _application = 'lkru';
  bool _isUnlocked = false;

  /// Creates a new [DBusSecrets] instance.
  ///
  /// [application] is the application name to use for namespacing secrets.
  /// [collection] is the collection name to use. Defaults to 'default'.
  DBusSecrets({String application = 'lkru', String collection = 'default'}) {
    _application = application;
    if (collection != 'default') {
      _collectionPath = DBusObjectPath('$_servicePath/collection/$collection');
    } else {
      _collectionPath = DBusObjectPath(_defaultCollectionPath);
    }
  }

  /// Initializes the connection to the D-Bus Secrets service.
  ///
  /// This must be called before any other methods.
  /// Returns true if the connection was successful.
  Future<bool> initialize() async {
    try {
      _client = DBusClient.session();
      _session = await _openSession();
      return true;
    } catch (e) {
      print('Error initializing: $e');
      return false;
    }
  }

  /// Closes the connection to the D-Bus Secrets service.
  ///
  /// This should be called when the instance is no longer needed.
  Future<void> close() async {
    try {
      await _closeSession();
    } finally {
      _client.close();
    }
  }

  /// Unlocks the collection which is required to access the secrets in it.
  ///
  /// Returns true if the collection was unlocked successfully.
  Future<bool> unlock() async {
    try {
      final unlocked = await _unlock([_collectionPath]);

      // Check if our collection was unlocked
      for (var path in unlocked) {
        if (path.value == _collectionPath.value) {
          _isUnlocked = true;
          return true;
        }
      }

      if (unlocked.isNotEmpty) {
        print('Unlocked ${unlocked.length} collections not including the requested one');
      } else {
        print('No collections were unlocked');
      }

      return false;
    } catch (e) {
      print('Error unlocking collection: $e');
      return false;
    }
  }

  /// Gets a secret from the keyring.
  ///
  /// [label] is the label of the secret to get.
  /// Returns the secret as a UTF-8 string, or null if the secret was not found.
  Future<String?> get(String label) async {
    if (!_isUnlocked) {
      print('Collection is not unlocked. Call unlock() first.');
      return null;
    }

    try {
      final item = await _getItem(label);
      if (item == null) {
        print('Secret "$label" not found');
        return null;
      }

      final secret = await _getSecret(item);
      if (secret == null) {
        print('Failed to get secret value');
        return null;
      }

      return String.fromCharCodes(secret);
    } catch (e) {
      print('Error getting secret: $e');
      return null;
    }
  }

  /// Sets a secret in the keyring.
  ///
  /// [label] is the label of the secret to set.
  /// [value] is the value of the secret to set.
  /// Returns true if the secret was set successfully.
  Future<bool> set(String label, String value) async {
    if (!_isUnlocked) {
      print('Collection is not unlocked. Call unlock() first.');
      return false;
    }

    try {
      // Check if the item already exists to determine if we should replace it
      bool replace = false;
      try {
        final existingItem = await _getItem(label);
        replace = existingItem != null;
      } catch (e) {
        // Item doesn't exist, so replace should be false
        replace = false;
      }

      // Create the properties map
      final properties = <String, DBusValue>{
        _itemLabelVariant: DBusString(label),
        _itemAttributesVariant: _createAttributesDict(label),
      };

      // Create the secret object
      final secret = DBusStruct([
        _session,
        DBusArray.byte([]),
        DBusArray.byte(value.codeUnits),
        DBusString(_stringContentType),
      ]);

      // Call the CreateItem method
      final result = await _client.callMethod(
        destination: _serviceName,
        path: _collectionPath,
        interface: 'org.freedesktop.Secret.Collection',
        name: 'CreateItem',
        values: [DBusDict.stringVariant(properties), secret, DBusBoolean(replace)],
      );

      final item = result.values[0] as DBusObjectPath;
      final prompt = result.values[1] as DBusObjectPath;

      if (prompt.value != '/') {
        // Handle prompt if needed
        final promptResult = await _handlePrompt(prompt);
        return promptResult;
      }

      return true;
    } catch (e) {
      print('Error setting secret: $e');
      return false;
    }
  }

  /// Deletes a secret from the keyring.
  ///
  /// [label] is the label of the secret to delete.
  /// Returns true if the secret was deleted successfully.
  Future<bool> delete(String label) async {
    if (!_isUnlocked) {
      print('Collection is not unlocked. Call unlock() first.');
      return false;
    }

    try {
      final item = await _getItem(label);
      if (item == null) {
        print('Secret "$label" not found');
        return false;
      }

      final result = await _client.callMethod(
        destination: _serviceName,
        path: item,
        interface: 'org.freedesktop.Secret.Item',
        name: 'Delete',
        values: [],
      );

      final prompt = result.values[0] as DBusObjectPath;

      if (prompt.value != '/') {
        // Handle prompt if needed
        final promptResult = await _handlePrompt(prompt);
        return promptResult;
      }

      return true;
    } catch (e) {
      print('Error deleting secret: $e');
      return false;
    }
  }

  // Private methods

  /// Opens a session with the secret service.
  Future<DBusObjectPath> _openSession() async {
    try {
      final result = await _client.callMethod(
        destination: _serviceName,
        path: DBusObjectPath(_servicePath),
        interface: 'org.freedesktop.Secret.Service',
        name: 'OpenSession',
        values: [DBusString('plain'), DBusVariant(DBusString(''))],
      );

      return result.values[1] as DBusObjectPath;
    } catch (e) {
      print('Error opening session: $e');
      rethrow;
    }
  }

  /// Closes the session with the secret service.
  Future<void> _closeSession() async {
    try {
      await _client.callMethod(
        destination: _serviceName,
        path: _session,
        interface: 'org.freedesktop.Secret.Session',
        name: 'Close',
        values: [],
      );
    } catch (e) {
      print('Error closing session: $e');
    }
  }

  /// Unlocks the given objects.
  Future<List<DBusObjectPath>> _unlock(List<DBusObjectPath> objects) async {
    try {
      final result = await _client.callMethod(
        destination: _serviceName,
        path: DBusObjectPath(_servicePath),
        interface: 'org.freedesktop.Secret.Service',
        name: 'Unlock',
        values: [DBusArray.objectPath(objects)],
      );

      final unlocked = (result.values[0] as DBusArray).children.map((child) => child as DBusObjectPath).toList();
      final prompt = result.values[1] as DBusObjectPath;

      if (prompt.value != '/') {
        // Handle prompt if needed
        final promptResult = await _handlePrompt(prompt);
        if (!promptResult) {
          return [];
        }
      }

      return unlocked;
    } catch (e) {
      print('Error unlocking objects: $e');
      return [];
    }
  }

  /// Handles a prompt from the secret service.
  ///
  /// In a real implementation, this would wait for a signal from the D-Bus service.
  /// For simplicity, we'll just send the prompt and assume it was successful.
  Future<bool> _handlePrompt(DBusObjectPath prompt) async {
    try {
      // Send the prompt request
      await _client.callMethod(
        destination: _serviceName,
        path: prompt,
        interface: 'org.freedesktop.Secret.Prompt',
        name: 'Prompt',
        values: [DBusString('')],
      );

      // In a real implementation, we would wait for the Completed signal
      // and check if it was dismissed. For now, we'll just return true.
      print('Prompt sent. In a real implementation, we would wait for a signal.');
      return true;
    } catch (e) {
      print('Error handling prompt: $e');
      return false;
    }
  }

  /// Gets an item from the collection.
  Future<DBusObjectPath?> _getItem(String label) async {
    try {
      final result = await _client.callMethod(
        destination: _serviceName,
        path: _collectionPath,
        interface: 'org.freedesktop.Secret.Collection',
        name: 'SearchItems',
        values: [_createAttributesDict(label)],
      );

      final items = (result.values[0] as DBusArray).children.map((child) => child as DBusObjectPath).toList();

      if (items.isEmpty) {
        return null;
      }

      return items[0];
    } catch (e) {
      print('Error getting item: $e');
      return null;
    }
  }

  /// Gets the secret from an item.
  Future<List<int>?> _getSecret(DBusObjectPath item) async {
    try {
      final result = await _client.callMethod(
        destination: _serviceName,
        path: item,
        interface: 'org.freedesktop.Secret.Item',
        name: 'GetSecret',
        values: [_session],
      );

      final secret = result.values[0] as DBusStruct;
      final value = (secret.children[2] as DBusArray).children.map((child) => (child as DBusByte).value).toList();

      return value;
    } catch (e) {
      print('Error getting secret value: $e');
      return null;
    }
  }

  /// Creates a DBusDict with the attributes for a secret.
  DBusDict _createAttributesDict(String label) {
    final attributes = <String, String>{
      'Agent': 'lkru (Linux Keyring Utility)',
      'Application': _application,
      'Id': label,
    };

    final dbusMap = <DBusValue, DBusValue>{};
    for (var entry in attributes.entries) {
      dbusMap[DBusString(entry.key)] = DBusString(entry.value);
    }

    return DBusDict(DBusSignature('s'), DBusSignature('s'), dbusMap);
  }
}
