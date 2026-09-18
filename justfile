# use PowerShell instead of sh:
set windows-shell := ["pwsh.exe", "-c"]

default: (help)

# Print this help message
@help:
    echo "run 'just list' to list targets"
    echo "more information can be found at  at http://just.systems/"
    just list

# List the recipes and descriptions
list:
    @just --list

# Generate the D-Bus remote object bindings, one class per Secret Service interface
generate:
    dart pub global activate dbus
    dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Service.xml --class-name SecretService -o lib/interfaces/secret_service.dart
    dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Collection.xml --class-name SecretCollection -o lib/interfaces/secret_collection.dart
    dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Item.xml --class-name SecretItem -o lib/interfaces/secret_item.dart
    dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Session.xml --class-name SecretSession -o lib/interfaces/secret_session.dart
    dart-dbus generate-remote-object ./interfaces/org.freedesktop.Secret.Prompt.xml --class-name SecretPrompt -o lib/interfaces/secret_prompt.dart
    dart format lib/interfaces
