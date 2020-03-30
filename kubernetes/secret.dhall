let imports = ../imports.dhall

let Kubernetes = imports.Kubernetes

let Settings = ../Settings.dhall

in    λ(metadata : Kubernetes.ObjectMeta.Type)
    → λ ( credentials
        : Settings.ConfigTemplate.Options.AWS-Simple.Credentials.Type
        )
    → Kubernetes.Secret::{
      , metadata = metadata
      , type = Some "Opaque"
      , stringData = Some
          ( toMap
              { AWS_ACCESS_KEY_ID = credentials.access-key
              , AWS_SECRET_ACCESS_KEY = credentials.secret-key
              }
          )
      }
