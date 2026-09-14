#!/usr/bin/env bash
# Draait één Flutter-commando (analyze/test) voor het factory-vangnet in de huidige app-map.
#
# Waarom niet gewoon `flutter analyze`: de Agent Runtime draait elk verificatiecommando in een
# verse container zonder de pub-cache van de agentcontainer. Een door de agent achtergelaten
# `.dart_tool/package_config.json` verwijst dan naar packages die niet bestaan, en Flutter haalt
# ze niet opnieuw op zolang dat bestand nieuwer is dan `pubspec.lock`. Daarom eerst expliciet
# `flutter pub get`. Het execution-image draait een andere Flutter-versie dan CI, waardoor
# `pub get` de lockfile kan herschrijven; die wijziging mag niet in de factory-commit belanden,
# dus `pubspec.lock` wordt na afloop altijd teruggezet.
set -uo pipefail

if (( $# == 0 )); then
  echo "Gebruik: $0 <flutter-subcommando> [argumenten...]" >&2
  exit 2
fi

backup="$(mktemp)"
cp pubspec.lock "$backup" || exit 1
restore_lockfile() {
  cp "$backup" pubspec.lock
  rm -f "$backup"
}
trap restore_lockfile EXIT

flutter pub get && flutter "$@"
