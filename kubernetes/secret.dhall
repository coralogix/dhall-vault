let imports = ../imports.dhall

let Kubernetes = imports.Kubernetes

let Settings = ../Settings.dhall

in    λ(settings : Settings.Type)
    → Kubernetes.Secret::{
      , metadata = Settings.common.kubernetes.metadata.object-meta settings
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
