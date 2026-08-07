#!/usr/bin/env bash
set -euo pipefail

if (( $# != 4 )); then
  echo "Gebruik: $0 <backend-url> <frontend-url> <admin-url> <application-id>" >&2
  exit 2
fi

backend_url="${1%/}"
frontend_url="${2%/}"
admin_url="${3%/}"
application_id="$4"
curl_tls_options=()
if [[ "${CURL_INSECURE:-0}" == "1" ]]; then
  curl_tls_options+=(--insecure)
fi

health="$(curl "${curl_tls_options[@]}" --fail --silent --show-error "${backend_url}/actuator/health")"
[[ "$health" == *'"status":"UP"'* ]] || {
  echo "Backend is niet UP: ${health}" >&2
  exit 1
}

version="$(curl "${curl_tls_options[@]}" --fail --silent --show-error "${backend_url}/api/version")"
[[ "$version" == *"\"application\":\"${application_id}\""* ]] || {
  echo "Onverwachte applicatie-identiteit: ${version}" >&2
  exit 1
}

[[ "$(curl "${curl_tls_options[@]}" --silent --output /dev/null --write-out '%{http_code}' "${frontend_url}/")" == "200" ]]
[[ "$(curl "${curl_tls_options[@]}" --silent --output /dev/null --write-out '%{http_code}' "${admin_url}/")" == "200" ]]

admin_status="$(curl "${curl_tls_options[@]}" --silent --output /dev/null --write-out '%{http_code}' "${backend_url}/api/admin/me")"
[[ "$admin_status" == "401" || "$admin_status" == "503" ]] || {
  echo "Admin-API is zonder Google-token niet afgeschermd (HTTP ${admin_status})." >&2
  exit 1
}

news="$(curl "${curl_tls_options[@]}" --fail --silent --show-error "${backend_url}/api/news")"
NEWS_JSON="$news" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["NEWS_JSON"])
if not isinstance(payload, list):
    raise SystemExit("De publieke nieuws-API retourneert geen lijst.")
PY

if [[ "${PREVIEW_ADMIN:-0}" == "1" ]]; then
  title="Preview contracttest ${application_id} $(date -u +%s)"
  payload="$(python3 - "$title" <<'PY'
import json
import sys

print(json.dumps({"title": sys.argv[1], "message": "Automatisch end-to-end getest previewbericht."}))
PY
)"
  created="$(curl "${curl_tls_options[@]}" --fail --silent --show-error \
    -X POST "${backend_url}/api/admin/news" \
    -H 'Content-Type: application/json' \
    -H 'X-HKH-Preview-Admin: enabled' \
    --data "$payload")"
  CREATED_JSON="$created" EXPECTED_TITLE="$title" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["CREATED_JSON"])
if payload.get("title") != os.environ["EXPECTED_TITLE"]:
    raise SystemExit("Het aangemaakte nieuwsbericht heeft een onverwachte titel.")
PY
  news="$(curl "${curl_tls_options[@]}" --fail --silent --show-error "${backend_url}/api/news")"
  NEWS_JSON="$news" EXPECTED_TITLE="$title" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["NEWS_JSON"])
if not payload or payload[0].get("title") != os.environ["EXPECTED_TITLE"]:
    raise SystemExit("Het nieuwe bericht staat niet bovenaan de publieke nieuwslijst.")
PY
fi

echo "Baselinecontract groen voor ${application_id}."
