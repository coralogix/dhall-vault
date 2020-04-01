{- We use templates to help differentiate between information that can be provided at
-- configuration time, and information which is retrieved at runtime and injected
-- into the Dhall configuration.
-- These templates are intended to hold information which will be provided at run-time
-- by the owning context, and thus cannot be provided by the user at compile-time.
-- All that the user has to do is pick a template option in Settings.
-}
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

          in  { Parameters
              , build =
                    λ(parameters : Parameters.Type)
                  → VaultConfig::{
                    , listener = Listener.TCP Listener.Options.TCP::{=}
                    , storage =
                        StorageBackend.All.S3
                          StorageBackend.Options.S3::{
                          , bucket = Some parameters.s3.bucket
                          }
                    , seal = Some
                        ( Seal.AWS-KMS
                            Seal.Options.AWS-KMS::{
                            , kms_key_id = Some parameters.kms.key-id
                            }
                        )
                    , log_level = Some "info"
                    }
              }
      }

let exports = { aws }

in  exports
