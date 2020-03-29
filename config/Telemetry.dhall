let imports = ../imports.dhall

let Prelude = imports.Prelude

let JSON = Prelude.JSON

let UtilityLibrary = imports.UtilityLibrary

let Duration = UtilityLibrary.golang.Duration

let hcl-render = UtilityLibrary.hcl.render

let Common =
    {- No matter which metrics provider(s) is/are chosen, these
    -- options are shared in common between them.
    -}
      let Common =
            { Type = { disable_hostname : Optional Bool }
            , default.disable_hostname = None Bool
            }

      in    Common
          ∧ { render.map-json-object =
                  λ(common : Common.Type)
                → toMap
                    { disable_hostname =
                        hcl-render.helpers.json.optional.bool
                          common.disable_hostname
                    }
            }

let Providers =
    {- Vault supports a variety of metrics formats and providers.
    -- For the sake of brevity, only Prometheus is supported for now.
    -- Unlike other configuration blocks, the `telemetry` block can be
    -- configured to support a vareity of different metrics providers
    -- simultaneously; hence, why these providers are not represented
    -- in a union (which would force an either/or single choice).
    -}
      let Prometheus =
            let Prometheus =
                  { Type = { retention_time : Optional Duration.Type }
                  , default.retention_time = None Duration.Type
                  }

            in    Prometheus
                ∧ { render.map-json-object =
                        λ(prometheus : Prometheus.Type)
                      → toMap
                          { prometheus_retention_time =
                              hcl-render.helpers.json.optional.duration
                                prometheus.retention_time
                          }
                  }

      in  { Prometheus = Prometheus }

let Telemetry =
      let Telemetry =
            { Type =
                { common : Optional Common.Type
                , prometheus : Optional Providers.Prometheus.Type
                }
            , default =
              { common = None Common.Type
              , prometheus = None Providers.Prometheus.Type
              }
            }

      in    Telemetry
          ∧ { render.json =
                let render =
                        λ(telemetry : Telemetry.Type)
                      → JSON.object
                          (   Prelude.List.default
                                (Prelude.Map.Entry Text JSON.Type)
                                ( Prelude.Optional.map
                                    Common.Type
                                    (Prelude.Map.Type Text JSON.Type)
                                    Common.render.map-json-object
                                    telemetry.common
                                )
                            # Prelude.List.default
                                (Prelude.Map.Entry Text JSON.Type)
                                ( Prelude.Optional.map
                                    Providers.Prometheus.Type
                                    (Prelude.Map.Type Text JSON.Type)
                                    Providers.Prometheus.render.map-json-object
                                    telemetry.prometheus
                                )
                          )

                let test =
                      { prometheus =
                            assert
                          :   JSON.render
                                ( JSON.omitNullFields
                                    ( render
                                        Telemetry::{
                                        , prometheus = Some Providers.Prometheus::{
                                          , retention_time = Some
                                              (Duration.Hours 24)
                                          }
                                        }
                                    )
                                )
                            ≡ ''
                              { "prometheus_retention_time": "24h" }
                              ''
                      }

                in  render
            }

let exports = Telemetry ∧ { Common = Common, Providers = Providers }

in  exports
