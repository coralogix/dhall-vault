let imports = ../imports.dhall

let Kubernetes = imports.Kubernetes

let Prelude = imports.Prelude

let Settings = ../settings.dhall

in    λ(settings : Settings.Type)
    → Kubernetes.Service::{
      , metadata = Kubernetes.ObjectMeta::{
        , name = Settings.common.kubernetes.metadata.name
        , namespace = settings.namespace
        , labels = Some
            (Settings.common.kubernetes.metadata.labels.package settings)
        }
      , spec = Some Kubernetes.ServiceSpec::{
        , type = Some "ClusterIP"
        , sessionAffinity = Some "None"
        , selector = Some
            (Settings.common.kubernetes.metadata.labels.selector settings)
        , ports = Some
          [ Kubernetes.ServicePort::{
            , name = Some settings.ports.api.name
            , port = settings.ports.api.number
            , protocol = Some "TCP"
            , targetPort = Some
                (Kubernetes.IntOrString.Int settings.ports.api.number)
            }
          ]
        }
      }
