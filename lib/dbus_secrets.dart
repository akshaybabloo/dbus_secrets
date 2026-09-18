import 'dart:async';

import 'package:dbus/dbus.dart';

import 'interfaces/secret_collection.dart';
import 'interfaces/secret_item.dart';
import 'interfaces/secret_prompt.dart';
import 'interfaces/secret_service.dart';
import 'interfaces/secret_session.dart';

/// A simplified class for interacting with the Linux Keyring via D-Bus
class DBusSecrets {
  // Basic D-Bus constants
  static const String _destination = 'org.freedesktop.secrets';
  static const String _defaultCollection = '/org/freedesktop/secrets/aliases/default';

  // Instance variables
  late DBusClient _client;
  late SecretService _service;
  late SecretCollection _collection;
  late SecretSession _session;
  final String _appName;
  bool _isUnlocked = false;

  // Constructor
  DBusSecrets({String appName = 'my_app'}) : _appName = appName;

  // Initialize connection
  Future<bool> initialize() async {
    try {
      _client = DBusClient.session();
      _service = SecretService(_client, _destination);
      _collection = SecretCollection(_client, _destination, DBusObjectPath(_defaultCollection));

      // Open a session, the secrets are exchanged in plain text over the session bus
      final (_, sessionPath) = await _service.callOpenSession('plain', DBusString(''));
      _session = SecretSession(_client, _destination, sessionPath);

      return true;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  // Unlock the keyring
  Future<bool> unlock() async {
    try {
      final (_, promptPath) = await _service.callUnlock([_collection.path]);

      // A prompt path of "/" means no prompt is needed, the collection is already unlocked
      if (promptPath.value == '/') {
        _isUnlocked = true;
        return true;
      }

      // Subscribe to the completed signal before the prompt is shown
      final prompt = SecretPrompt(_client, _destination, promptPath);
      final completed = prompt.completed.first;

      // Wait a little bit to prevent a race condition between the subscription and the sending of the prompt call
      Timer(Duration(milliseconds: 500), () => prompt.callPrompt(''));

      // Wait for the completed signal
      final result = await completed;
      if (result.dismissed) {
        return false;
      }

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
      final properties = <String, DBusValue>{
        'org.freedesktop.Secret.Item.Label': DBusString(key),
        'org.freedesktop.Secret.Item.Attributes': _attributesValue(key),
      };

      // Create secret
      final secret = <DBusValue>[
        _session.path,
        DBusArray.byte([]),
        DBusArray.byte(value.codeUnits),
        DBusString('text/plain; charset=utf8'),
      ];

      // Save the secret
      await _collection.callCreateItem(properties, secret, replace);

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
      final itemPath = await _findItem(key);
      if (itemPath == null) return null;

      // Get the secret value
      final item = SecretItem(_client, _destination, itemPath);
      final secret = await item.callGetSecret(_session.path);

      // Extract the value, the struct is (session, parameters, value, content type)
      return String.fromCharCodes(secret[2].asByteArray());
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
      final itemPath = await _findItem(key);
      if (itemPath == null) return false;

      // Delete the item
      await SecretItem(_client, _destination, itemPath).callDelete();

      return true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }

  // Whether the default collection is currently locked
  Future<bool> isLocked() => _collection.getLocked();

  // The label of the default collection, for example "Login"
  Future<String> collectionLabel() => _collection.getLabel();

  // Close the connection
  Future<void> close() async {
    try {
      await _session.callClose();
    } finally {
      await _client.close();
    }
  }

  // Helper: Find an item by key
  Future<DBusObjectPath?> _findItem(String key) async {
    final items = await _collection.callSearchItems(_attributes(key));

    return items.isEmpty ? null : items.first;
  }

  // Helper: Create the attributes an item is stored and searched with
  Map<String, String> _attributes(String key) => {'Application': _appName, 'Id': key};

  // Helper: The same attributes as a D-Bus dictionary, for the item properties
  DBusDict _attributesValue(String key) {
    final map = _attributes(key).map((k, v) => MapEntry(DBusString(k), DBusString(v)));

    return DBusDict(DBusSignature('s'), DBusSignature('s'), map);
  }
}
