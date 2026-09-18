// This file was generated using the following command and may be overwritten.
// dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Session.xml

import 'dart:io';
import 'package:dbus/dbus.dart';

class SecretSession extends DBusRemoteObject {
  SecretSession(DBusClient client, String destination, DBusObjectPath path)
    : super(client, name: destination, path: path);

  /// Invokes org.freedesktop.Secret.Session.Close()
  Future<void> callClose({bool noAutoStart = false, bool allowInteractiveAuthorization = false}) async {
    await callMethod(
      'org.freedesktop.Secret.Session',
      'Close',
      [],
      replySignature: DBusSignature(''),
      noAutoStart: noAutoStart,
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
  }
}
