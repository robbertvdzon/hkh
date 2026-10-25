#!/usr/bin/env bash
set -euo pipefail
cd build/web
hash=$(shasum -a 256 main.dart.js | cut -c1-12)
mv main.dart.js "main.$hash.js"
# BSD and GNU sed have different -i syntax; use a temporary file instead.
for file in flutter_bootstrap.js flutter.js; do
  sed "s/main\.dart\.js/main.$hash.js/g" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done
! grep -rl 'main\.dart\.js' .
