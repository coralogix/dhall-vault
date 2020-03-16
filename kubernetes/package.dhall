let Settings = ../settings.dhall

in    λ(settings : Settings.Type)
    → let poddisruptionbudget = ./poddisruptionbudget.dhall settings

      let configmap = ./configmap.dhall settings

      let secret = ./secret.dhall settings

      let deployment = ./deployment.dhall settings configmap secret

      let service = ./service.dhall settings

      in  { poddisruptionbudget = poddisruptionbudget
          , configmap = configmap
          , secret = secret
          , deployment = deployment
          , service = service
          , objects =
            [ "poddisruptionbudget"
            , "configmap"
            , "secret"
            , "deployment"
            , "service"
            ]
          }
