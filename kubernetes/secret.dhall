let imports = ../imports.dhall

let Kubernetes = imports.Kubernetes

let Settings = ../settings.dhall

in    λ(settings : Settings.Type)
    → Kubernetes.Secret::{
      , metadata = Kubernetes.ObjectMeta::{
        , name = Settings.common.kubernetes.metadata.name
        , namespace = settings.namespace
        , labels = Some
            (Settings.common.kubernetes.metadata.labels.package settings)
        }
      , type = Some "Opaque"
      , stringData = Some
          ( merge
              { AWS-Simple =
                    λ(options : Settings.ConfigTemplate.Options.AWS-Simple.Type)
                  → toMap
                      { AWS_ACCESS_KEY_ID = options.credentials.access-key
                      , AWS_SECRET_ACCESS_KEY = options.credentials.secret-key
                      }
              }
              settings.config.template
          )
      }
