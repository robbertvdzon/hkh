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

echo "Baselinecontract groen voor ${application_id}."
