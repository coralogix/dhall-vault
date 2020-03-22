let imports = ../imports.dhall

let Kubernetes = imports.Kubernetes

let Prelude = imports.Prelude

let Settings = ../settings.dhall

in    λ(settings : Settings.Type)
    → Kubernetes.PodDisruptionBudget::{
      , metadata = Settings.common.kubernetes.metadata.object-meta settings
      , spec = Some Kubernetes.PodDisruptionBudgetSpec::{
        , maxUnavailable = Some (Kubernetes.IntOrString.Int 1)
        , selector = Some Kubernetes.LabelSelector::{
          , matchLabels = Some
              (Settings.common.kubernetes.metadata.labels.selector settings)
          }
        }
      }
