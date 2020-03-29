let imports = ../imports.dhall

let Prelude = imports.Prelude

let JSON = Prelude.JSON

let UtilityLibrary = imports.UtilityLibrary

let Duration = UtilityLibrary.golang.Duration

let hcl-render = UtilityLibrary.hcl.render

let StorageBackend = ./StorageBackend.dhall

let Listener = ./Listener.dhall

let Seal = ./Seal.dhall

let Telemetry = ./Telemetry.dhall

let LogFormat =
    {- Vault allows you to configure whether it logs to JSON or not.
    -- `LogFormat` exposes these two options.
    -}
      let LogFormat = < Standard | JSON >

      in  { Type = LogFormat
          , Standard = LogFormat.Standard
          , JSON = LogFormat.JSON
          , render =
              let text =
                      λ(value : LogFormat)
                    → merge { Standard = "standard", JSON = "json" } value

              in  { text = text
                  , json = λ(value : LogFormat) → JSON.string (text value)
                  }
          }

let VaultConfig =
      let VaultConfig =
            { Type =
                { storage : StorageBackend.All.Type
                , ha_storage : Optional StorageBackend.HighAvailability.Type
                , listener : Listener.Type
                , seal : Optional Seal.Type
                , cluster_name : Optional Text
                , cache_size : Optional Natural
                , disable_cache : Optional Bool
                , disable_mlock : Optional Bool
                , plugin_directory : Optional Text
                , telemetry : Optional Telemetry.Type
                , log_level : Optional Text
                , log_format : Optional LogFormat.Type
                , default_lease_ttl : Optional Duration.Type
                , max_lease_ttl : Optional Duration.Type
                , default_max_request_duration : Optional Duration.Type
                , raw_storage_endpoint : Optional Bool
                , ui : Optional Bool
                , pid_file : Optional Text
                , api_addr : Optional Text
                , cluster_addr : Optional Text
                , disable_clustering : Optional Bool
                , disable_sealwrap : Optional Bool
                , disable_performance_standby : Optional Bool
                }
            , default =
              { ha_storage = None StorageBackend.HighAvailability.Type
              , seal = None Seal.Type
              , cluster_name = None Text
              , cache_size = None Natural
              , disable_cache = None Bool
              , disable_mlock = None Bool
              , plugin_directory = None Text
              , telemetry = None Telemetry.Type
              , log_level = None Text
              , log_format = None LogFormat.Type
              , default_lease_ttl = None Duration.Type
              , max_lease_ttl = None Duration.Type
              , default_max_request_duration = None Duration.Type
              , raw_storage_endpoint = None Bool
              , ui = None Bool
              , pid_file = None Text
              , api_addr = None Text
              , cluster_addr = None Text
              , disable_clustering = None Bool
              , disable_sealwrap = None Bool
              , disable_performance_standby = None Bool
              }
            }

      in    VaultConfig
          ∧ { render.json =
                  λ(config : VaultConfig.Type)
                → let render-optional-bool =
                          λ(optional-bool : Optional Bool)
                        → merge
                            { Some = λ(value : Bool) → JSON.bool value
                            , None = JSON.null
                            }
                            optional-bool

                  in  JSON.object
                        ( toMap
                            { storage =
                                StorageBackend.All.render.json config.storage
                            , ha_storage =
                                hcl-render.helpers.json.optional.generic
                                  StorageBackend.HighAvailability.Type
                                  StorageBackend.HighAvailability.render.json
                                  config.ha_storage
                            , listener = Listener.render.json config.listener
                            , seal =
                                hcl-render.helpers.json.optional.generic
                                  Seal.Type
                                  Seal.render.json
                                  config.seal
                            , cluster_name =
                                hcl-render.helpers.json.optional.text
                                  config.cluster_name
                            , cache_size =
                                hcl-render.helpers.json.optional.natural
                                  config.cache_size
                            , disable_cache =
                                render-optional-bool config.disable_cache
                            , disable_mlock =
                                render-optional-bool config.disable_mlock
                            , plugin_directory =
                                hcl-render.helpers.json.optional.text
                                  config.plugin_directory
                            , telemetry =
                                hcl-render.helpers.json.optional.generic
                                  Telemetry.Type
                                  Telemetry.render.json
                                  config.telemetry
                            , log_level =
                                hcl-render.helpers.json.optional.text
                                  config.log_level
                            , log_format =
                                hcl-render.helpers.json.optional.generic
                                  LogFormat.Type
                                  LogFormat.render.json
                                  config.log_format
                            , default_lease_ttl =
                                hcl-render.helpers.json.optional.duration
                                  config.default_lease_ttl
                            , max_lease_ttl =
                                hcl-render.helpers.json.optional.duration
                                  config.max_lease_ttl
                            , default_max_request_duration =
                                hcl-render.helpers.json.optional.duration
                                  config.default_max_request_duration
                            , raw_storage_endpoint =
                                render-optional-bool config.raw_storage_endpoint
                            , ui = render-optional-bool config.ui
                            , pid_file =
                                hcl-render.helpers.json.optional.text
                                  config.pid_file
                            , api_addr =
                                hcl-render.helpers.json.optional.text
                                  config.api_addr
                            , cluster_addr =
                                hcl-render.helpers.json.optional.text
                                  config.cluster_addr
                            , disable_clustering =
                                render-optional-bool config.disable_clustering
                            , disable_sealwrap =
                                render-optional-bool config.disable_sealwrap
                            , disable_performance_standby =
                                render-optional-bool
                                  config.disable_performance_standby
                            }
                        )
            }

let tests =
      { minimal =
            assert
          :   JSON.render
                ( JSON.omitNullFields
                    ( VaultConfig.render.json
                        VaultConfig::{
                        , listener = Listener.TCP Listener.Options.TCP::{=}
                        , storage =
                            StorageBackend.All.InMemory
                              StorageBackend.Options.InMemory::{=}
                        }
                    )
                )
            ≡ ''
              {
                "listener": { "tcp": { "tls_disable": "true" } },
                "storage": { "inmem": {} }
              }
              ''
      }

let exports = VaultConfig ∧ { LogFormat = LogFormat }

in  exports
