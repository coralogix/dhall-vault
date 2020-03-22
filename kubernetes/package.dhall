let Settings = ../settings.dhall

in    λ(settings : Settings.Type)
    → let poddisruptionbudget = ./poddisruptionbudget.dhall settings

      let configmap = ./configmap.dhall settings

      let secret = ./secret.dhall settings

      let deployment =
            ./deployment.dhall
              settings
              { configmap.name = configmap.metadata.name
              , secret.name = secret.metadata.name
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
                [ "poddisruptionbudget"
                , "configmap"
                , "secret"
                , "deployment"
                , "service"
                ]
              # merge
                  { Enabled =
                        λ(_ : Settings.ServiceMonitor.Options.Enabled.Type)
                      → [ "service-monitor" ]
                  , Disabled = [] : List Text
                  }
                  settings.service-monitor
          }
