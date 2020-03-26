#! /usr/bin/env bash

function main {
  set -euo pipefail

  local dhall_vault_package=$(realpath "${1}")
  local dhall_vault_output=$(realpath "${2}")
  local vault_settings_dhall=$(realpath "${3}")
  local kubectl_context="${4}"

  set --

  echo >&2 "[INFO][dhall-vault][apply.sh][step: verification] Verifying settings..."

  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: verification] Extracting identifiers..."

  # For brevity's sake, assume AWS-Simple
  local dhall_settings_aws_simple=$(dhall-to-json <<EOF
let Settings = (${dhall_vault_package}).Settings
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
  set +e
  local aws_s3api_head_bucket_output=
  local aws_s3api_head_bucket_exitcode=
  aws_s3api_head_bucket_output=$(export AWS_ACCESS_KEY_ID="${aws_simple_credentials_access_key}"; \
                                 export AWS_SECRET_ACCESS_KEY="${aws_simple_credentials_secret_key}"; \
                                 aws s3api head-bucket --bucket "${aws_simple_s3_bucket}" 2>&1 \
                                )
  aws_s3api_head_bucket_exitcode=$?
  if [[ $aws_s3api_head_bucket_exitcode -ne 0 ]]; then
    echo >&2 ''
    echo >&2 "[ERROR][dhall-vault][apply.sh][step:verification][bucket: ${aws_simple_s3_bucket}] There was an error while attempting to verify the bucket. Please review the output below (exiting afterwards):"
    echo >&2 "${aws_s3api_head_bucket_output}"
    exit 1
  fi
  echo >&2 "done!"
  set -e

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
                                aws kms describe-key --key-id "${aws_simple_kms_key_id}" 2>&1 \
                               )
  if [[ $? -ne 0 ]]; then
    echo >&2 ''
    echo >&2 "[ERROR][dhall-vault][apply.sh][step: verification][key: ${aws_simple_kms_key_id}] There was an error while trying to describe the key. Please review the output below (exiting afterwards)..."
    echo >&2 "${aws_kms_describe_key_output}"
    exit 1
  fi
  set -e

  echo >&2 "done!"

  echo >&2 "[INFO][dhall-vault][apply.sh][step: verification] Finished verifying settings!"

  echo >&2 "[INFO][dhall-vault][apply.sh][step: installation] Installing Vault..."

  local rendered_json="${dhall_vault_output}/kubernetes-rendered.json"
  mkdir -p "${dhall_vault_output}/kubernetes-rendered-objects/"
  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: installation] Rendering kubernetes/package.dhall to ${rendered_json} ... "
  dhall-to-json <<< "(${dhall_vault_package}).kubernetes (${vault_settings_dhall})" > "${rendered_json}"
  echo >&2 "done!"

  for kubernetes_object in $(jq -r '.objects[]' < "${rendered_json}") ; do
    # jq_selector - necessary to escape ids with dashes in them.
    # the `kubernetes_object` that we get from the JSON output is of the form:
    #   path.to.kubernetes.object
    # if one of those components contains a dash, i.e.
    #   foo-bar
    # then we could naively run something like
    #   jq '.foo-bar' <<< '{ "foo-bar" : "hi" }'
    # This causes a compile error in jq:
    #   jq: error: bar/0 is not defined at <top-level>, line 1:
    #   .foo-bar
    #   jq: 1 compile error
    # This happens because jq mistakenly thinks that the user is trying to
    # subtract `bar` from `foo`.
    # The fix (below) is to escape the field path segments so that we instead get:
    #   .["path"]["to"]["kubernetes"]["object"]
    # or
    #   .["foo-bar"]
    # which works as expected.
    local jq_selector=$(echo "${kubernetes_object}" | sed -e 's/\./"]["/g;s/^/.["/;s/$/"]/')
    jq -c "${jq_selector}" < "${rendered_json}" > "${dhall_vault_output}/kubernetes-rendered-objects/${kubernetes_object}.json"
    echo >&2 "[INFO][dhall-vault][apply.sh][step: installation] Applying ${kubernetes_object}, which has the following diff:"
    set +e
    if [[ grep 'secret' <<< "${kubernetes_object}" ]]; then
      echo >&2 "[INFO][dhall-vault][apply.sh][step: installation] Object is a secret - not running kubectl diff!"
    else
      kubectl "--context=${kubectl_context}" diff -f "${dhall_vault_output}/kubernetes-rendered-objects/${kubernetes_object}.json" 1>&2
    fi
    kubectl "--context=${kubectl_context}" apply -f "${dhall_vault_outuput}/kubernetes-rendered-objects/${kubernetes_object}.json" 1>&2
  done

  echo >&2 "[INFO][dhall-vault][apply.sh][step: initialization] Checking if the Vault storage has been initialized..."

  echo >&2 -n "[INFO][dhall-vault][apply.sh][step: initialization] Extracting variables... "
  local kubectl_pid=
  local kubectl_namespace=
  local kubectl_name=
  local kubectl_port=
  kubectl_namespace=$(dhall text <<< "merge { Some = \\(it : Text) -> it , None = \"default\" } (${vault_settings_dhall}).namespace")
  kubectl_name='vault' # hardcode for now
  kubectl_port=$(dhall text <<< "Natural/show (${vault_settings_dhall}).ports.api.number")
  echo >&2 'done!'
  echo >&2 "[INFO][dhall-vault][apply.sh][step: initialization] Port-forwarding to Vault..."
  kubectl "--context=${kubectl_context}" \
    port-forward \
    "--namespace=${kubectl_namespace}" \
    "service/${kubectl_name}" \
    "${kubectl_port}" &
  sleep 3
  kubectl_pid=$(ps -ef | grep port-forward | grep -v grep | awk '{print $1}')
  echo >&2 "[INFO][dhall-vault][apply.sh][step: initialization] Setup port-forwarding to Vault."

  set +e
  local vault_operator_init_status=
  local vault_operator_init_status_exitcode=
  vault_operator_init_status=$(vault operator init "-address=http://127.0.0.1:${kubectl_port}" -tls-skip-verify -status)
  vault_operator_init_status_exitcode=$?
  if [[ $vault_operator_init_status_exitcode -eq 0 ]]; then
    echo >&2 "[INFO][dhall-vault][apply.sh][step: initialization] Vault is already initialized."
  elif [[ $vault_operator_init_status_exitcode -eq 1 ]]; then
    echo >&2 "[ERROR][dhall-vault][apply.sh][step: initialization] There was an error while trying to check the status of Vault's storage initialization. Please review the output below (exiting afterwards)..."
    echo >&2 "${vault_operator_init_status}"
    exit 1
  elif [[ $vault_operator_init_status_exitcode -eq 2 ]]; then
    echo >&2 "[INFO][dhall-vault][apply.sh][step: initialization] Vault storage is not yet initialized. Initializing... "
    vault operator init \
      "-address=http://127.0.0.1:${kubectl_port}" \
      -tls-skip-verify \
      -key-shares=1 \
      -key-threshold=1 \
      -recovery-shares=1 \
      -recovery-threshold=1 \
      -format=json  > "${dhall_vault_output}/vault-operator-init-output.json"
    echo >&2 "done! The keys can be found in the output: ${dhall_vault_output}/vault-operator-init-output.json"
    echo >&2 -n "[INFO][dhall-vault][apply.sh][step: initialization] Restarting Vault (to pick up on the newly initialized storage)..."
    kubectl "--context=${kubectl_context}" rollout restart "--namespace=${kubectl_namespace}" "deployment/${kubectl_name}"
    echo >&2 'done!'
  else
    echo >&2 "[ERROR][dhall-vault][apply.sh][step: initialization][exit code: ${vault_operator_init_status_exitcode}] While trying to check the status of Vault's storage initialization, Vault returned an unrecognized exit code. Please review the output below (exiting afterwards)..."
    echo >&2 "${vault_operator_init_status}"
    exit 1
  fi

  echo >&2 "[INFO][dhall-vault][apply.sh] Killing Vault port-forward... "
  kill -9 "${kubectl_pid}"
  echo >&2 'done!'

  echo >&2 "[INFO][dhall-vault][apply.sh] Finished installing Vault!"
}

main "$@"
