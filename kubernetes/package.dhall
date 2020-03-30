let imports = ../imports.dhall

let Prelude = imports.Prelude

let Kubernetes = imports.Kubernetes

let Settings = ../Settings.dhall

in    λ(settings : Settings.Type)
    → let poddisruptionbudget = ./poddisruptionbudget.dhall settings

      let configmap = ./configmap.dhall settings

      let secret =
            merge
              { AWS-Simple =
                    λ ( aws-simple
                      : Settings.ConfigTemplate.Options.AWS-Simple.Type
                      )
                  → Prelude.Optional.map
                      Settings.ConfigTemplate.Options.AWS-Simple.Credentials.Type
                      Kubernetes.Secret.Type
                      (   λ ( credentials
                            : Settings.ConfigTemplate.Options.AWS-Simple.Credentials.Type
                            )
                        → ./secret.dhall
                            ( Settings.common.kubernetes.metadata.object-meta
                                settings
                            )
                            credentials
                      )
                      aws-simple.credentials
              }
              settings.config.template

      let deployment =
            ./deployment.dhall
              settings
              { configmap.name = configmap.metadata.name
              , secret.name =
                  Prelude.Optional.map
                    Kubernetes.Secret.Type
                    Text
                    (λ(secret : Kubernetes.Secret.Type) → secret.metadata.name)
                    secret
              }

      let service = ./service.dhall settings

      let service-monitor = ./servicemonitor.dhall settings

      in  { poddisruptionbudget = poddisruptionbudget
          , configmap = configmap
          , secret = secret
          , deployment = deployment
          , service = service
          , service-monitor = service-monitor
          , objects =
                [ "poddisruptionbudget", "configmap" ]
              # merge
                  { Some = λ(_ : Kubernetes.Secret.Type) → [ "secret" ]
                  , None = [] : List Text
                  }
                  secret
              # [ "deployment", "service" ]
              # merge
                  { Enabled =
                        λ(_ : Settings.ServiceMonitor.Options.Enabled.Type)
                      → [ "service-monitor" ]
                  , Disabled = [] : List Text
                  }
                  settings.service-monitor
          }
