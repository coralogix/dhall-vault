# dhall-vault
Dhall-packaged Hashicorp Vault

## Implicit Assumptions
This package is being used in an environment where the underlying Kubernetes pods are given access to critical AWS resources (S3 buckets, KMS keys) by way of the instance profiles on the instances on which the Kubernetes pods are being run. While future support is intended to tighten-up AWS IAM permissions to the pod level, currently that work hasn't been done, and installing `dhall-vault` in this way will not work unless the underlying instance profile is also set up appropriately.
