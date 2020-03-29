let imports = ./imports.dhall

let Prelude = imports.Prelude

let Kubernetes = imports.Kubernetes

let UtilityLibrary = imports.UtilityLibrary

let Image = UtilityLibrary.kubernetes.Image

let Config = ./config/package.dhall

let name = "vault"

let metadata = ./metadata.dhall

let ConfigTemplate =
      let Options =
            { AWS-Simple =
              { Type =
                  { credentials : { access-key : Text, secret-key : Text }
                  , s3 : { bucket : Text }
                  , kms : { key-id : Text }
                  }
              , default = {=}
              }
            }

      let ConfigTemplate =
          {- Generally this is populated by the owning context, in config.template.
          -- All user configuration should be defined elsewhere and then populated in
          -- the Settings object at config.override by the owning context.
          -}
            < AWS-Simple : Options.AWS-Simple.Type >

      let exports =
          {- the AWS-Simple export is provided as a helper.
          -- Instead of needing to write:
          --    ConfigTemplate.Type.AWS-Simple ConfigTemplate.Options.AWS-Simple::{...}
          -- the user can instead write:
          --    ConfigTemplate.AWS-Simple ConfigTemplate.Options.AWS-Simple::{...}
          -}
            { Type = ConfigTemplate
            , AWS-Simple =
                  λ(options : Options.AWS-Simple.Type)
                → ConfigTemplate.AWS-Simple options
            , Options = Options
            }

      in  exports

let Port = { Type = { name : Text, number : Natural }, default = {=} }

let ServiceMonitor =
      let Options =
            { Enabled =
              { Type = { scrape-identifier : Prelude.Map.Type Text Text }
              , default = {=}
              }
            }

      let ServiceMonitor = < Enabled : Options.Enabled.Type | Disabled >

      in  { Type = ServiceMonitor
          , Enabled =
              λ(enabled : Options.Enabled.Type) → ServiceMonitor.Enabled enabled
          , Disabled = ServiceMonitor.Disabled
          , Options = Options
          }

let Settings =
      let Settings =
            { Type =
                { config :
                    { template : ConfigTemplate.Type
                    , override :
                        Config.VaultConfig.Type → Config.VaultConfig.Type
                    }
                , namespace : Optional Text
                , additional-labels : Prelude.Map.Type Text Text
                , image : Image.Type
                , ports : { api : Port.Type, cluster-coordination : Port.Type }
                , service-monitor : ServiceMonitor.Type
                }
            , default =
              { config.override =
                  Prelude.Function.identity Config.VaultConfig.Type
              , namespace = None Text
              , additional-labels = Prelude.Map.empty Text Text
              , image =
                  Image.Tag
                    { registry = "registry.hub.docker.com"
                    , name = "library/vault"
                    , tag = metadata.version.vault
                    }
              , ports =
                { api = Port::{ name = "api", number = 8200 }
                , cluster-coordination = Port::{
                  , name = "cluster-coordination"
                  , number = 8201
                  }
                }
              , service-monitor = ServiceMonitor.Disabled
              }
            }

      let common =
            let config
                {- the Vault configuration is generated on-the-fly.
                -- There is an issue - if the configuration has required fields,
                -- but these fields are supposed to be provided upstream in the build
                -- and not at the moment of writing the configuration, how best to
                -- represent these fields when writing the configuration?
                -- Ergo the Vault configuration is split into two -
                --  1. the fields that are required from upstream (in this case,
                --     AWS details). This yields a basic, possibly incomplete, but
                --     type-full configuration.
                --  2. any override that the user wishes to do, above and beyond
                --     what is in the basic type-full configuration. To represent
                --     this override, the user provides a function which takes the
                --     "generated" type-full configuration from step 1, makes the
                --     changes, and returns the type-safe result. By default, the
                --     override function is the identity function, which makes no
                --     changes.
                -}
                : ∀(settings : Settings.Type) → Config.VaultConfig.Type
                =   λ(settings : Settings.Type)
                  → let template =
                          merge
                            { AWS-Simple =
                                  λ ( options
                                    : ConfigTemplate.Options.AWS-Simple.Type
                                    )
                                → let template = Config.templates.aws.simple

                                  in  template.build
                                        template.Parameters::options.{ s3, kms }
                            }
                            settings.config.template

                    let adjust-tcp-listener =
                        {- Two things:
                        -- 1. Set the ports in the Vault configuration to be equal to the ones provided by the
                        --    user in the settings record.
                        --    Do note - this presumes that the listener port is listening on 127.0.0.1, which
                        --    is the Vault default.
                        -- 2. Set the cipher suites to the recommended secure defaults.
                        --
                        -- If either of these are not desirable, it is the user's responsibility to override
                        -- the relevant settings in the config.override function.
                        -}
                              template
                            ⫽ { listener =
                                  merge
                                    { TCP =
                                          λ ( tcp
                                            : Config.Listener.Options.TCP.Type
                                            )
                                        → Config.Listener.TCP
                                            (   tcp
                                              ⫽ { address = Some
                                                    "127.0.0.1:${Natural/show
                                                                   settings.ports.api.number}"
                                                , cluster_address = Some
                                                    "127.0.0.1:${Natural/show
                                                                   settings.ports.cluster-coordination.number}"
                                                , tls_cipher_suites =
                                                    Config.Listener.Options.TCP.TLSCipherSuite.recommended-secure-defaults
                                                }
                                            )
                                    }
                                    template.listener
                              }
                          : Config.VaultConfig.Type

                    in  settings.config.override adjust-tcp-listener

            let kubernetes =
                  { metadata =
                      let labels =
                            let kubernetes-standard =
                                  { component =
                                      Prelude.Map.keyText
                                        "app.kubernetes.io/component"
                                        "vault"
                                  , managed-by =
                                      Prelude.Map.keyText
                                        "app.kubernetes.io/managed-by"
                                        "dhall"
                                  , name =
                                      Prelude.Map.keyText
                                        "app.kubernetes.io/name"
                                        name
                                  , version =
                                      Prelude.Map.keyText
                                        "app.kubernetes.io/version"
                                        "${metadata.version.vault}-${metadata.version.package}"
                                  }

                            let selector =
                                    λ(settings : Settings.Type)
                                  →   [ kubernetes-standard.name ]
                                    # settings.additional-labels

                            let package =
                                    λ(settings : Settings.Type)
                                  →   selector settings
                                    # [ kubernetes-standard.component
                                      , kubernetes-standard.managed-by
                                      , kubernetes-standard.version
                                      ]

                            in  { kubernetes-standard = kubernetes-standard
                                , selector = selector
                                , package = package
                                }

                      let object-meta =
                              λ(settings : Settings.Type)
                            → Kubernetes.ObjectMeta::{
                              , name = name
                              , namespace = settings.namespace
                              , labels = Some (labels.package settings)
                              }

                      in  { name = name
                          , labels = labels
                          , object-meta = object-meta
                          }
                  }

            in  { config = config, kubernetes = kubernetes }

      let tests =
            { config =
                let settings =
                      Settings::{
                      , config =
                        { template =
                            ConfigTemplate.AWS-Simple
                              ConfigTemplate.Options.AWS-Simple::{
                              , credentials =
                                    { access-key = "access" }
                                  ∧ { secret-key = "secret" }
                              , s3.bucket = "foo-bucket"
                              , kms.key-id = "bar-key"
                              }
                        , override =
                              λ(config : Config.VaultConfig.Type)
                            → config ⫽ { ui = Some True }
                        }
                      , ports =
                        { api = { name = "api", number = 8300 }
                        , cluster-coordination =
                          { name = "cluster-coordination", number = 8301 }
                        }
                      }

                let built-config =
                      Config.VaultConfig::{
                      , storage =
                          Config.StorageBackend.All.S3
                            Config.StorageBackend.Options.S3::{
                            , bucket = "foo-bucket"
                            }
                      , listener =
                          Config.Listener.TCP
                            Config.Listener.Options.TCP::{
                            , address = Some "127.0.0.1:8300"
                            , cluster_address = Some "127.0.0.1:8301"
                            , tls_cipher_suites =
                                Config.Listener.Options.TCP.TLSCipherSuite.recommended-secure-defaults
                            }
                      , seal = Some
                          ( Config.Seal.AWS-KMS
                              Config.Seal.Options.AWS-KMS::{
                              , kms_key_id = "bar-key"
                              }
                          )
                      , log_level = Some "info"
                      , ui = Some True
                      }

                in  assert : common.config settings ≡ built-config
            }

      in  Settings ∧ { common = common }

let exports =
        Settings
      ∧ { ConfigTemplate = ConfigTemplate
        , Port = Port
        , ServiceMonitor = ServiceMonitor
        }

in  exports
