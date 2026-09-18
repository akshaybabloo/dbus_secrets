// This file was generated using the following command and may be overwritten.
// dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Prompt.xml

import 'dart:io';
import 'package:dbus/dbus.dart';

/// Signal data for org.freedesktop.Secret.Prompt.Completed.
class SecretPromptCompleted extends DBusSignal {
  bool get dismissed => values[0].asBoolean();
  DBusValue get result => values[1].asVariant();

  SecretPromptCompleted(DBusSignal signal)
    : super(
        sender: signal.sender,
        path: signal.path,
        interface: signal.interface,
        name: signal.name,
        values: signal.values,
      );
}

class SecretPrompt extends DBusRemoteObject {
  /// Stream of org.freedesktop.Secret.Prompt.Completed signals.
  late final Stream<SecretPromptCompleted> completed;

  SecretPrompt(DBusClient client, String destination, DBusObjectPath path)
    : super(client, name: destination, path: path) {
    completed = DBusRemoteObjectSignalStream(
      object: this,
      interface: 'org.freedesktop.Secret.Prompt',
      name: 'Completed',
      signature: DBusSignature('bv'),
    ).asBroadcastStream().map((signal) => SecretPromptCompleted(signal));
  }

  /// Invokes org.freedesktop.Secret.Prompt.Prompt()
  Future<void> callPrompt(
    String windowId, {
    bool noAutoStart = false,
    bool allowInteractiveAuthorization = false,
  }) async {
    await callMethod(
      'org.freedesktop.Secret.Prompt',
      'Prompt',
      [DBusString(windowId)],
      replySignature: DBusSignature(''),
      noAutoStart: noAutoStart,
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
  }

  /// Invokes org.freedesktop.Secret.Prompt.Dismiss()
  Future<void> callDismiss({bool noAutoStart = false, bool allowInteractiveAuthorization = false}) async {
    await callMethod(
      'org.freedesktop.Secret.Prompt',
      'Dismiss',
      [],
      replySignature: DBusSignature(''),
      noAutoStart: noAutoStart,
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
  }
}
