let imports = ../imports.dhall

let Prelude = imports.Prelude

let Kubernetes = imports.Kubernetes

let Prometheus = imports.Prometheus.v1

let Settings = ../Settings.dhall

in    λ(settings : Settings.Type)
    → Prometheus.ServiceMonitor::{
      , metadata =
          let common = Settings.common.kubernetes.metadata.object-meta settings

          let add-scrape-identifier =
              {- If the user has decided to enable the ServiceMonitor, then this
              -- extracts the scrape identifier from the `config.service-monitor`'s
              -- `Enabled` option and adds it to the ServiceMonitor's labels.
              -- This ensures that the ServiceMonitor will be scraped by the
              -- Prometheus which the user has set up elsewhere.
              -}
                  common
                ⫽ { labels =
                      let scrape-identifier =
                            merge
                              { Enabled =
                                    λ ( enabled
                                      : Settings.ServiceMonitor.Options.Enabled.Type
                                      )
                                  → enabled.scrape-identifier
                              , Disabled = Prelude.Map.empty Text Text
                              }
                              settings.service-monitor

                      in  Some
                            ( merge
                                { Some =
                                      λ(labels : Prelude.Map.Type Text Text)
                                    → labels # scrape-identifier
                                , None = scrape-identifier
                                }
                                common.labels
                            )
                  }

          in  add-scrape-identifier
      , spec = Prometheus.ServiceMonitorSpec::{
        , namespaceSelector =
            Prelude.Optional.map
              Text
              Prometheus.NamespaceSelector
              (   λ(namespace : Text)
                → Prometheus.NamespaceSelector.MatchNames
                    { matchNames = [ namespace ] }
              )
              settings.namespace
        , selector = Kubernetes.LabelSelector::{
          , matchLabels = Some
              (Settings.common.kubernetes.metadata.labels.selector settings)
          }
        , endpoints = Some
          [ Prometheus.Endpoint.Union.TargetPort
              Prometheus.Endpoint.TargetPort::{
              , targetPort =
                  Kubernetes.IntOrString.Int settings.ports.api.number
              , path = Some "/v1/sys/metrics"
              , params = Some (toMap { format = "prometheus" })
              , interval = Some "60s"
              , scrapeTimeout = Some "40s"
              }
          ]
        }
      }
