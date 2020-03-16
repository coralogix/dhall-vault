let imports = ../imports.dhall

let JSON = imports.Prelude.JSON

let Kubernetes = imports.Kubernetes

let Settings = ../settings.dhall

let Config = ../config/package.dhall

in    λ(settings : Settings.Type)
    → Kubernetes.ConfigMap::{
      , metadata = Kubernetes.ObjectMeta::{
        , name = Settings.common.kubernetes.metadata.name
        , namespace = settings.namespace
        , labels = Some
            (Settings.common.kubernetes.metadata.labels.package settings)
        }
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
