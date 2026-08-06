#!/usr/bin/env bash
set -euo pipefail

deploy_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_file="${deploy_dir}/secrets-cluster.env"
output_file="${deploy_dir}/base/sealed-secret-runtime.yaml"
namespace="hkh"
secret_name="hkh-runtime"
shared_cert="${deploy_dir}/../../robberts-infrastructure/manifests/cluster-bootstrap/cluster-cert.pem"

command -v kubeseal >/dev/null 2>&1 || {
  echo "kubeseal ontbreekt; installeer het bijvoorbeeld met: brew install kubeseal" >&2
  exit 1
}

[[ -f "${source_file}" ]] || {
  echo "Maak eerst ${source_file} op basis van secrets-cluster.env.example." >&2
  exit 1
}

temporary_secret="$(mktemp)"
temporary_cert=""
trap 'rm -f "${temporary_secret}" ${temporary_cert:+"${temporary_cert}"}' EXIT

kubectl create secret generic "${secret_name}" \
  --namespace "${namespace}" \
  --from-env-file "${source_file}" \
  --dry-run=client \
  --output yaml > "${temporary_secret}"

if [[ -f "${shared_cert}" ]]; then
  cert="${shared_cert}"
else
  temporary_cert="$(mktemp)"
  kubeseal --fetch-cert > "${temporary_cert}"
  cert="${temporary_cert}"
fi

kubeseal --cert "${cert}" --format yaml < "${temporary_secret}" > "${output_file}"
echo "Versleuteld secret geschreven naar ${output_file}."
