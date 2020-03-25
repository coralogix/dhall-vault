let imports = ../imports.dhall

let JSON = imports.Prelude.JSON

let Kubernetes = imports.Kubernetes

let Settings = ../Settings.dhall

let Config = ../config/package.dhall

in    λ(settings : Settings.Type)
    → Kubernetes.ConfigMap::{
      , metadata = Settings.common.kubernetes.metadata.object-meta settings
      , data = Some
          ( toMap
              { `config.json` =
                  JSON.render
                    ( JSON.omitNullFields
                        ( Config.VaultConfig.render.json
                            (Settings.common.config settings)
                        )
                    )
              }
          )
      }
