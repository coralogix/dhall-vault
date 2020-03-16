let VaultConfig = ./VaultConfig.dhall

let Listener = ./Listener.dhall

let Seal = ./Seal.dhall

let StorageBackend = ./StorageBackend.dhall

let aws =
      { simple =
          let Parameters =
                { Type = { s3 : { bucket : Text }, kms : { key-id : Text } }
                , default = {=}
                }

          in  { Parameters = Parameters
              , build =
                    λ(parameters : Parameters.Type)
                  → VaultConfig::{
                    , listener = Listener.TCP Listener.Options.TCP::{=}
                    , storage =
                        StorageBackend.All.S3
                          StorageBackend.Options.S3::{
                          , bucket = parameters.s3.bucket
                          }
                    , seal = Some
                        ( Seal.AWS-KMS
                            Seal.Options.AWS-KMS::{
                            , kms_key_id = parameters.kms.key-id
                            }
                        )
                    , log_level = Some "info"
                    }
              }
      }

let exports = { aws = aws }

in  exports
