import 'dart:async';
import 'package:dbus/dbus.dart';

/// A simplified class for interacting with the Linux Keyring via D-Bus
class DBusSecrets {
  // Basic D-Bus constants
  static const String _service = 'org.freedesktop.secrets';
  static const String _path = '/org/freedesktop/secrets';
  static const String _defaultCollection = '/org/freedesktop/secrets/aliases/default';

  // Instance variables
  late DBusClient _client;
  late DBusObjectPath _session;
  late DBusObjectPath _collection;
  final String _appName;
  bool _isUnlocked = false;

  // Constructor
  DBusSecrets({String appName = 'my_app'}) : _appName = appName {
    _collection = DBusObjectPath(_defaultCollection);
  }

  // Initialize connection
  Future<bool> initialize() async {
    try {
      _client = DBusClient.session();
      _session = await _openSession();
      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  // Unlock the keyring
  Future<bool> unlock() async {
    try {
      var response = await _client.callMethod(
        destination: _service,
        path: DBusObjectPath(_path),
        interface: 'org.freedesktop.Secret.Service',
        name: 'Unlock',
        values: [
          DBusArray.objectPath([_collection]),
        ],
      );

      // Check if the unlocking was successful
      final objectPath = response.returnValues[1] as DBusObjectPath;
      if (objectPath.value == "/") {
        _isUnlocked = true;
        return true;
      }

      // Create the listener to subscribe to the completed signal on the prompt
      var promptRemote = DBusRemoteObject(_client, name: _service, path: objectPath);
      var completedStream = DBusRemoteObjectSignalStream(
        object: promptRemote,
        interface: 'org.freedesktop.Secret.Prompt',
        name: 'Completed',
      );

      // Wait a little bit to prevent a race condition between the subscription and the sending of the prompt call
      Timer(Duration(milliseconds: 500), () {
        _client.callMethod(
          destination: _service,
          path: objectPath,
          interface: "org.freedesktop.Secret.Prompt",
          name: "Prompt",
          values: [DBusString('')],
        );
      });

      // Wait for the completed signal
      final signal = await completedStream.first;
      final dismissed = (signal.values[0] as DBusBoolean).value;
      if (dismissed) {
        print("Unlock error: Prompt was dismissed by user.");
        return false;
      }
      print("Unlock successful: Prompt was accepted by user.");

      _isUnlocked = true;
      return true;
    } catch (e) {
      print('Unlock error: $e');
      return false;
    }
  }

  // Store a secret
  Future<bool> set(String key, String value) async {
    if (!_isUnlocked) return false;

    try {
      // Check if item exists
      final existingItem = await _findItem(key);
      final replace = existingItem != null;

      // Create properties
      final properties = {
        'org.freedesktop.Secret.Item.Label': DBusString(key),
        'org.freedesktop.Secret.Item.Attributes': _createAttributes(key),
      };

      // Create secret
      final secret = DBusStruct([
        _session,
        DBusArray.byte([]),
        DBusArray.byte(value.codeUnits),
        DBusString('text/plain; charset=utf8'),
      ]);

      // Save the secret
      await _client.callMethod(
        destination: _service,
        path: _collection,
        interface: 'org.freedesktop.Secret.Collection',
        name: 'CreateItem',
        values: [DBusDict.stringVariant(properties), secret, DBusBoolean(replace)],
      );

      return true;
    } catch (e) {
      print('Set error: $e');
      return false;
    }
  }

  // Get a secret
  Future<String?> get(String key) async {
    if (!_isUnlocked) return null;

    try {
      // Find the item
      final item = await _findItem(key);
      if (item == null) return null;

      // Get the secret value
      final result = await _client.callMethod(
        destination: _service,
        path: item,
        interface: 'org.freedesktop.Secret.Item',
        name: 'GetSecret',
        values: [_session],
      );

      // Extract the value
      final secret = result.values[0] as DBusStruct;
      final value = (secret.children[2] as DBusArray).children.map((c) => (c as DBusByte).value).toList();

      return String.fromCharCodes(value);
    } catch (e) {
      print('Get error: $e');
      return null;
    }
  }

  // Delete a secret
  Future<bool> delete(String key) async {
    if (!_isUnlocked) return false;

    try {
      // Find the item
      final item = await _findItem(key);
      if (item == null) return false;

      // Delete the item
      await _client.callMethod(
        destination: _service,
        path: item,
        interface: 'org.freedesktop.Secret.Item',
        name: 'Delete',
        values: [],
      );

      return true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }

  // Close the connection
  Future<void> close() async {
    try {
      await _client.callMethod(
        destination: _service,
        path: _session,
        interface: 'org.freedesktop.Secret.Session',
        name: 'Close',
        values: [],
      );
    } finally {
      _client.close();
    }
  }

  // Helper: Open a session
  Future<DBusObjectPath> _openSession() async {
    final result = await _client.callMethod(
      destination: _service,
      path: DBusObjectPath(_path),
      interface: 'org.freedesktop.Secret.Service',
      name: 'OpenSession',
      values: [DBusString('plain'), DBusVariant(DBusString(''))],
    );

    return result.values[1] as DBusObjectPath;
  }

  // Helper: Find an item by key
  Future<DBusObjectPath?> _findItem(String key) async {
    final result = await _client.callMethod(
      destination: _service,
      path: _collection,
      interface: 'org.freedesktop.Secret.Collection',
      name: 'SearchItems',
      values: [_createAttributes(key)],
    );

    final items = (result.values[0] as DBusArray).children.map((c) => c as DBusObjectPath).toList();

    return items.isEmpty ? null : items[0];
  }

  // Helper: Create attributes dictionary
  DBusDict _createAttributes(String key) {
    final attributes = {'Application': _appName, 'Id': key};

    final map = <DBusValue, DBusValue>{};
    attributes.forEach((k, v) => map[DBusString(k)] = DBusString(v));

    return DBusDict(DBusSignature('s'), DBusSignature('s'), map);
  }
}
