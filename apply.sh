#! /usr/bin/env bash

function main {
  set -euo pipefail

  local dhall_vault_dir=$(realpath "${1}")
  local dhall_vault_output=$(realpath "${2}")
  local vault_settings_dhall=$(realpath "${3}")
  local kubectl_context="${4}"

  set --

  echo >&2 "[INFO][dhall-vault][apply.sh] Verifying settings..."

  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: verification] Extracting identifiers..."

  # For brevity's sake, assume AWS-Simple
  local dhall_settings_aws_simple=$(dhall-to-json <<EOF
let Settings = (${dhall_vault_dir})/settings.dhall
in merge { AWS-Simple = \\(options: Settings.ConfigTemplate.Options.AWS-Simple.Type) -> options } (${vault_settings_dhall})
EOF
)

  # verify that the bucket and KMS key exist
  local aws_simple_credentials_access_key=$(jq '.credentials.access-key' <<< "${dhall_settings_aws_simple}")
  local aws_simple_credentials_secret_key=$(jq '.credentials.secret-key' <<< "${dhall_settings_aws_simple}")
  local aws_simple_s3_bucket=$(jq '.s3.bucket' <<< "${dhall_settings_aws_simple}")
  local aws_simple_kms_key_id=$(jq '.kms.key-id' <<< "${dhall_settings_aws_simple}")
  echo >&2 "done!"

  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: verification][bucket: ${aws_simple_s3_bucket}] Verifying bucket..."
  $(export AWS_ACCESS_KEY_ID="${aws_simple_credentials_access_key}"; \
    export AWS_SECRET_ACCESS_KEY="${aws_simple_credentials_secret_key}"; \
    aws s3api head-bucket --bucket "${aws_simple_s3_bucket}" \
   )
  echo >&2 "done!"

  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: verification] Verifying key..."
  # the AWS api call `aws kms describe-key --key-id <key>` allows for ARNs and aliases, but these are not permitted
  # by the Vault configuration, which must take the key ID itself.
  # so, verify that the provided key ID fits the regex of a key ID before calling describe-key.
  if [[ "${aws_simple_kms_key_id}" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    :
  else
    echo >&2 ''
    echo >&2 "[ERROR][dhall-vault][apply.sh][step: verification][key: ${aws_simple_kms_key_id}] The provided AWS KMS key ID does not fit the regular expression of a valid AWS KMS key ID! Exiting..."
    exit 1
  fi

  set +e
  local aws_kms_describe_key_output=
  aws_kms_describe_key_output=$(export AWS_ACCESS_KEY_ID="${aws_simple_credentials_access_key}"; \
                                export AWS_SECRET_ACCESS_KEY="${aws_simple_credentials_secret_key}"; \
                                aws kms describe-key --key-id "${aws_simple_kms_key_id}" \
                               )
  if [[ $? -ne 0 ]]; then
    echo >&2 ''
    echo >&2 "[ERROR][dhall-vault][apply.sh][step: verification][key: ${aws_simple_kms_key_id}] There was an error while trying to describe the key. Please review the output below (exiting afterwards)..."
    echo >&2 "${aws_kms_describe_key_output}"
    exit 1
  fi
  set -e

  echo >&2 "done!"

  echo >&2 "[INFO][dhall-vault][apply.sh] Finished verifying settings!"

  echo >&2 "[INFO][dhall-vault][apply.sh] Installing Vault..."

  local rendered_json="${dhall_vault_output}/kubernetes-rendered.json"
  mkdir -p "${dhall_vault_output}/kubernetes-rendered-objects/"
  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: installation] Rendering kubernetes/package.dhall to ${rendered_json} ... "
  dhall-to-json <<< "${dhall_vault_dir}/kubernetes/package.dhall (${vault_settings_dhall})" > "${rendered_json}"
  echo >&2 "done!"

  for kubernetes_object in $(jq -r '.objects[]' < "${rendered_json}") ; do
    # jq_selector - turn 'a.b.c' into '.["a"]["b"]["c"]'. Necessary to escape ids with dashes in them
    local jq_selector=$(echo "${kubernetes_object}" | sed -e 's/\./"]["/g;s/^/.["/;s/$/"]/')
    jq -c "${jq_selector}" < "${rendered_json}" > "${dhall_vault_output}/kubernetes-rendered-objects/${kubernetes_object}.json"
    echo >&2 "[INFO][dhall-vault][apply.sh][step: installation] Applying ${kubernetes_object}:"
    set +e
    if [[ grep 'secret' <<< "${kubernetes_object}" ]]; then
      echo >&2 "[INFO][dhall-vault][apply.sh][step: installation] Object is a secret - not echoing to console!"
    else
      yq -y . <<< "${dhall_vault_output}/kubernetes-rendered-objects/${kubernetes_object}.json" 1>&2
    fi
    kubectl "--context=${kubectl_context}" apply -f "${dhall_vault_outuput}/kubernetes-rendered-objects/${kubernetes_object}.json" 1>&2
  done

  echo >&2 "[INFO][dhall-vault][apply.sh] Finished installing Vault!"
}

main "$@"
