let imports = ../imports.dhall

let Prelude = imports.Prelude

let JSON = Prelude.JSON

let hcl = ./hcl-util.dhall

let Duration = hcl.Duration

let Options =
    {- `Options` here meaning the different types of Listeners that Vault supports.
    -- Currently, Vault only supports one Listener - the TCP listener.
    -}
      let TCP =
            let TCP =
                  let ProxyProtocolBehavior =
                      {- Represents the legal values which may be used for the
                      -- `proxy_protocol_behavior` configuration field, and is also
                      -- used to populate the `proxy_protocol_authorized_addrs`
                      -- configuration field.
                      -}
                        let Options =
                              let Addresses =
                                  {- If either the `allow_authorized` or the
                                  -- `deny_authorized` fields are specified, the user
                                  -- must provide at least one address, which goes in
                                  -- the `first` field below. If the union were to
                                  -- take a `List Text` as a parameter instead of
                                  -- `Addresses`, then it would be possible for the user
                                  -- to provide an empty list, i.e. no addresses,
                                  -- which is illegal.
                                  -}
                                    { Type =
                                        { first : Text, additional : List Text }
                                    , default.additional = [] : List Text
                                    }

                              in  { Addresses = Addresses }

                        let ProxyProtocolBehavior =
                            {- The `proxy_protocol_behavior` field has three
                            -- legal values: `use_always`, `allow_authorized`,
                            -- and `deny_unauthorized`.
                            -}
                              < UseAlways
                              | AllowAuthorized : Options.Addresses.Type
                              | DenyUnauthorized : Options.Addresses.Type
                              >

                        let exports =
                            {- The `UseAlways`, `AllowAuthorized`, and
                            -- `DenyUnauthorized` exports are helper exports
                            -- provided for the user's convenience. Instead
                            -- of writing:
                            --     let ProxyProtocolBehavior = (./Listener.dhall).TCP.ProxyProtocolBehavior
                            --     in ProxyProtocolBehavior.Type.UseAlways
                            -- the user may instead write:
                            --     let ProxyProtocolBehavior = (./Listener.dhall).TCP.ProxyProtocolBehavior
                            --     in ProxyProtocolBehavior.UseAlways
                            -}
                              { Type = ProxyProtocolBehavior
                              , UseAlways = ProxyProtocolBehavior.UseAlways
                              , AllowAuthorized =
                                    λ(addresses : Options.Addresses.Type)
                                  → ProxyProtocolBehavior.AllowAuthorized
                                      addresses
                              , DenyUnauthorized =
                                    λ(addresses : Options.Addresses.Type)
                                  → ProxyProtocolBehavior.DenyUnauthorized
                                      addresses
                              , Options = Options
                              , render.behavior.text =
                                    λ(ppb : ProxyProtocolBehavior)
                                  → merge
                                      { UseAlways = "use_always"
                                      , AllowAuthorized =
                                            λ(_ : Options.Addresses.Type)
                                          → "allow_authorized"
                                      , DenyUnauthorized =
                                            λ(_ : Options.Addresses.Type)
                                          → "deny_unauthorized"
                                      }
                                      ppb
                              }

                        in  exports

                  let TLS =
                      {- If the user decides to enable TLS, then both a
                      -- `cert_file` and a `key_file` must be provided.
                      -}
                        { Type = { cert_file : Text, key_file : Text }
                        , default = {=}
                        }

                  let TLSMinVersion =
                        let TLSMinVersion =
                            {- There are three legal values for
                            -- `tls_min_version`:  1.0, 1.1, and 1.2.
                            -}
                              < `1.0` | `1.1` | `1.2` >

                        in  { Type = TLSMinVersion
                            , `1.0` = TLSMinVersion.`1.0`
                            , `1.1` = TLSMinVersion.`1.1`
                            , `1.2` = TLSMinVersion.`1.2`
                            , render =
                                let render =
                                    {-  the final configuration, however,
                                    -- expects a different format than
                                    -- `1.0`, `1.1`, or `1.2`.
                                    -}
                                        λ(value : TLSMinVersion)
                                      → merge
                                          { `1.0` = "tls10"
                                          , `1.1` = "tls11"
                                          , `1.2` = "tls12"
                                          }
                                          value

                                in  render
                            }

                  let TLSCipherSuite =
                        let TLSCipherSuite =
                            {- Vault accepts cipher suites according to what
                            -- the Go runtime supports.
                            -- This is a union with the options.
                            -- The correct options to choose are a question of
                            -- the user's security policy.
                            -}
                              < TLS_RSA_WITH_3DES_EDE_CBC_SHA
                              | TLS_RSA_WITH_AES_128_CBC_SHA
                              | TLS_RSA_WITH_AES_256_CBC_SHA
                              | TLS_RSA_WITH_AES_128_GCM_SHA256
                              | TLS_RSA_WITH_AES_256_GCM_SHA384
                              | TLS_AES_128_GCM_SHA256
                              | TLS_AES_256_GCM_SHA384
                              | TLS_CHACHA20_POLY1305_SHA256
                              | TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
                              | TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
                              | TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA
                              | TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
                              | TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
                              | TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
                              | TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
                              | TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                              | TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                              | TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
                              | TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                              >

                        let recommended-secure-defaults
                            {- This is a list of reasonably secure defaults
                            -- that can be used by users who otherwise don't know
                            -- which cipher suites to enable for `tls_cipher_suites`.
                            -}
                            : List TLSCipherSuite
                            = [ TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                              , TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
                              , TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                              , TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
                              , TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
                              , TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
                              , TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
                              , TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
                              , TLSCipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256
                              , TLSCipherSuite.TLS_RSA_WITH_AES_256_GCM_SHA384
                              , TLSCipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA
                              , TLSCipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA
                              ]

                        let exports =
                            {- The exports corresponding to the various cipher
                            -- suites are helpers for the user, so that the user
                            -- can refer to:
                            -- `TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256`
                            -- instead of:
                            -- `TLSCipherSuite.Type.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256`
                            -}
                              { Type = TLSCipherSuite
                              , TLS_RSA_WITH_3DES_EDE_CBC_SHA =
                                  TLSCipherSuite.TLS_RSA_WITH_3DES_EDE_CBC_SHA
                              , TLS_RSA_WITH_AES_128_CBC_SHA =
                                  TLSCipherSuite.TLS_RSA_WITH_AES_128_CBC_SHA
                              , TLS_RSA_WITH_AES_256_CBC_SHA =
                                  TLSCipherSuite.TLS_RSA_WITH_AES_256_CBC_SHA
                              , TLS_RSA_WITH_AES_128_GCM_SHA256 =
                                  TLSCipherSuite.TLS_RSA_WITH_AES_128_GCM_SHA256
                              , TLS_RSA_WITH_AES_256_GCM_SHA384 =
                                  TLSCipherSuite.TLS_RSA_WITH_AES_256_GCM_SHA384
                              , TLS_AES_128_GCM_SHA256 =
                                  TLSCipherSuite.TLS_AES_128_GCM_SHA256
                              , TLS_AES_256_GCM_SHA384 =
                                  TLSCipherSuite.TLS_AES_256_GCM_SHA384
                              , TLS_CHACHA20_POLY1305_SHA256 =
                                  TLSCipherSuite.TLS_CHACHA20_POLY1305_SHA256
                              , TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA =
                                  TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA
                              , TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA =
                                  TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA
                              , TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA =
                                  TLSCipherSuite.TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA
                              , TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA =
                                  TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA
                              , TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA =
                                  TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA
                              , TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 =
                                  TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
                              , TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 =
                                  TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
                              , TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 =
                                  TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
                              , TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 =
                                  TLSCipherSuite.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
                              , TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 =
                                  TLSCipherSuite.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
                              , TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 =
                                  TLSCipherSuite.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                              , recommended-secure-defaults =
                                  recommended-secure-defaults
                              , render =
                                    λ(value : TLSCipherSuite)
                                  → merge
                                      { TLS_RSA_WITH_3DES_EDE_CBC_SHA =
                                          "TLS_RSA_WITH_3DES_EDE_CBC_SHA"
                                      , TLS_RSA_WITH_AES_128_CBC_SHA =
                                          "TLS_RSA_WITH_AES_128_CBC_SHA"
                                      , TLS_RSA_WITH_AES_256_CBC_SHA =
                                          "TLS_RSA_WITH_AES_256_CBC_SHA"
                                      , TLS_RSA_WITH_AES_128_GCM_SHA256 =
                                          "TLS_RSA_WITH_AES_128_GCM_SHA256"
                                      , TLS_RSA_WITH_AES_256_GCM_SHA384 =
                                          "TLS_RSA_WITH_AES_256_GCM_SHA384"
                                      , TLS_AES_128_GCM_SHA256 =
                                          "TLS_AES_128_GCM_SHA256"
                                      , TLS_AES_256_GCM_SHA384 =
                                          "TLS_AES_256_GCM_SHA384"
                                      , TLS_CHACHA20_POLY1305_SHA256 =
                                          "TLS_CHACHA20_POLY1305_SHA256"
                                      , TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA =
                                          "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA"
                                      , TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA =
                                          "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA"
                                      , TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA =
                                          "TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA"
                                      , TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA =
                                          "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA"
                                      , TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA =
                                          "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA"
                                      , TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 =
                                          "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
                                      , TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 =
                                          "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384"
                                      , TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 =
                                          "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
                                      , TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384 =
                                          "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
                                      , TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 =
                                          "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
                                      , TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256 =
                                          "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
                                      }
                                      value
                              }

                        in  exports

                  let Telemetry =
                        { Type =
                            { unauthenticated_metrics_access : Optional Bool }
                        , default.unauthenticated_metrics_access = None Bool
                        }

                  in  { Type =
                          { address : Optional Text
                          , cluster_address : Optional Text
                          , http_idle_timeout : Optional Duration.Type
                          , http_read_header_timeout : Optional Duration.Type
                          , http_read_timeout : Optional Duration.Type
                          , http_write_timeout : Optional Duration.Type
                          , max_request_size : Optional Natural
                          , max_request_duration : Optional Duration.Type
                          , proxy_protocol_behavior :
                              Optional ProxyProtocolBehavior.Type
                          , tls : Optional TLS.Type
                          , tls_min_version : Optional TLSMinVersion.Type
                          , tls_cipher_suites : List TLSCipherSuite.Type
                          , tls_prefer_server_cipher_suites : Optional Bool
                          , tls_require_and_verify_client_cert : Optional Bool
                          , tls_client_ca_file : Optional Text
                          , tls_disable_client_certs : Optional Bool
                          , x_forwarded_for_authorized_addrs : List Text
                          , x_forwarded_for_hop_skips : Optional Natural
                          , x_forwarded_for_reject_not_authorized :
                              Optional Bool
                          , x_forwarded_for_reject_not_present : Optional Bool
                          , telemetry : Optional Telemetry.Type
                          }
                      , default =
                          { address = None Text
                          , cluster_address = None Text
                          , http_idle_timeout = None Duration.Type
                          , http_read_header_timeout = None Duration.Type
                          , http_read_timeout = None Duration.Type
                          , http_write_timeout = None Duration.Type
                          , max_request_size = None Natural
                          , max_request_duration = None Duration.Type
                          , proxy_protocol_behavior =
                              None ProxyProtocolBehavior.Type
                          , tls = None TLS.Type
                          , tls_min_version = None TLSMinVersion.Type
                          , tls_cipher_suites = [] : List TLSCipherSuite.Type
                          , tls_prefer_server_cipher_suites = None Bool
                          , tls_require_and_verify_client_cert = None Bool
                          , tls_client_ca_file = None Text
                          , tls_disable_client_certs = None Bool
                          , x_forwarded_for_authorized_addrs = [] : List Text
                          , x_forwarded_for_hop_skips = None Natural
                          , x_forwarded_for_reject_not_authorized = None Bool
                          , x_forwarded_for_reject_not_present = None Bool
                          , telemetry = None Telemetry.Type
                          }
                      , ProxyProtocolBehavior = ProxyProtocolBehavior
                      , TLS = TLS
                      , TLSMinVersion = TLSMinVersion
                      , TLSCipherSuite = TLSCipherSuite
                      , Telemetry = Telemetry
                      }

            in    TCP
                ∧ { render =
                      { hcl-type = λ(_ : TCP.Type) → "tcp"
                      , json =
                            λ(tcp : TCP.Type)
                          → JSON.object
                              ( toMap
                                  { address =
                                      hcl.render.json.optional.text tcp.address
                                  , cluster_address =
                                      hcl.render.json.optional.text
                                        tcp.cluster_address
                                  , http_idle_timeout =
                                      hcl.render.json.optional.duration
                                        tcp.http_idle_timeout
                                  , http_read_header_timeout =
                                      hcl.render.json.optional.duration
                                        tcp.http_read_header_timeout
                                  , http_read_timeout =
                                      hcl.render.json.optional.duration
                                        tcp.http_read_timeout
                                  , http_write_timeout =
                                      hcl.render.json.optional.duration
                                        tcp.http_write_timeout
                                  , max_request_size =
                                      hcl.render.json.optional.natural
                                        tcp.max_request_size
                                  , proxy_protocol_behavior =
                                      hcl.render.json.optional.generic
                                        TCP.ProxyProtocolBehavior.Type
                                        ( Prelude.Function.compose
                                            TCP.ProxyProtocolBehavior.Type
                                            Text
                                            JSON.Type
                                            TCP.ProxyProtocolBehavior.render.behavior.text
                                            JSON.string
                                        )
                                        tcp.proxy_protocol_behavior
                                  , proxy_protocol_authorized_addrs =
                                      merge
                                        { Some =
                                              λ ( ppb
                                                : TCP.ProxyProtocolBehavior.Type
                                                )
                                            → let addresses =
                                                      λ ( addresses
                                                        : TCP.ProxyProtocolBehavior.Options.Addresses.Type
                                                        )
                                                    → JSON.array
                                                        ( Prelude.List.map
                                                            Text
                                                            JSON.Type
                                                            JSON.string
                                                            (   [ addresses.first
                                                                ]
                                                              # addresses.additional
                                                            )
                                                        )

                                              in  merge
                                                    { UseAlways = JSON.null
                                                    , AllowAuthorized =
                                                        addresses
                                                    , DenyUnauthorized =
                                                        addresses
                                                    }
                                                    ppb
                                        , None = JSON.null
                                        }
                                        tcp.proxy_protocol_behavior
                                  , tls_disable =
                                      merge
                                        { Some =
                                              λ(tls : TCP.TLS.Type)
                                            → JSON.string "false"
                                        , None = JSON.string "true"
                                        }
                                        tcp.tls
                                  , tls_cert_file =
                                      hcl.render.json.optional.text
                                        ( Prelude.Optional.map
                                            TCP.TLS.Type
                                            Text
                                            (   λ(tls : TCP.TLS.Type)
                                              → tls.cert_file
                                            )
                                            tcp.tls
                                        )
                                  , tls_key_file =
                                      hcl.render.json.optional.text
                                        ( Prelude.Optional.map
                                            TCP.TLS.Type
                                            Text
                                            (   λ(tls : TCP.TLS.Type)
                                              → tls.key_file
                                            )
                                            tcp.tls
                                        )
                                  , tls_min_version =
                                      hcl.render.json.optional.generic
                                        TCP.TLSMinVersion.Type
                                        ( Prelude.Function.compose
                                            TCP.TLSMinVersion.Type
                                            Text
                                            JSON.Type
                                            TCP.TLSMinVersion.render
                                            JSON.string
                                        )
                                        tcp.tls_min_version
                                  , tls_cipher_suites =
                                            if Prelude.List.null
                                                 TCP.TLSCipherSuite.Type
                                                 tcp.tls_cipher_suites

                                      then  JSON.null

                                      else  JSON.array
                                              ( Prelude.List.map
                                                  TCP.TLSCipherSuite.Type
                                                  JSON.Type
                                                  ( Prelude.Function.compose
                                                      TCP.TLSCipherSuite.Type
                                                      Text
                                                      JSON.Type
                                                      TCP.TLSCipherSuite.render
                                                      JSON.string
                                                  )
                                                  tcp.tls_cipher_suites
                                              )
                                  , tls_prefer_server_cipher_suites =
                                      hcl.render.json.optional.bool
                                        tcp.tls_prefer_server_cipher_suites
                                  , tls_require_and_verify_client_cert =
                                      hcl.render.json.optional.bool
                                        tcp.tls_require_and_verify_client_cert
                                  , tls_client_ca_file =
                                      hcl.render.json.optional.text
                                        tcp.tls_client_ca_file
                                  , tls_disable_client_certs =
                                      hcl.render.json.optional.bool
                                        tcp.tls_disable_client_certs
                                  , x_forwarded_for_authorized_addrs =
                                            if Prelude.List.null
                                                 Text
                                                 tcp.x_forwarded_for_authorized_addrs

                                      then  JSON.null

                                      else  JSON.array
                                              ( Prelude.List.map
                                                  Text
                                                  JSON.Type
                                                  JSON.string
                                                  tcp.x_forwarded_for_authorized_addrs
                                              )
                                  , x_forwarded_for_hop_skips =
                                      hcl.render.json.optional.natural
                                        tcp.x_forwarded_for_hop_skips
                                  , x_forwarded_for_reject_not_authorized =
                                      hcl.render.json.optional.bool
                                        tcp.x_forwarded_for_reject_not_authorized
                                  , x_forwarded_for_reject_not_present =
                                      hcl.render.json.optional.bool
                                        tcp.x_forwarded_for_reject_not_present
                                  , telemetry =
                                      hcl.render.json.optional.generic
                                        TCP.Telemetry.Type
                                        (   λ(telemetry : TCP.Telemetry.Type)
                                          → merge
                                              { Some =
                                                    λ(value : Bool)
                                                  → JSON.object
                                                      ( toMap
                                                          { unauthenticated_metrics_access =
                                                              JSON.string
                                                                (       if value

                                                                  then  "true"

                                                                  else  "false"
                                                                )
                                                          }
                                                      )
                                              , None = JSON.null
                                              }
                                              telemetry.unauthenticated_metrics_access
                                        )
                                        tcp.telemetry
                                  }
                              )
                      }
                  }

      in  { TCP = TCP }

let Listener = < TCP : Options.TCP.Type >

let render =
      { json =
            λ(listener : Listener)
          → JSON.object
              [ Prelude.Map.keyValue
                  JSON.Type
                  (merge { TCP = Options.TCP.render.hcl-type } listener)
                  (merge { TCP = Options.TCP.render.json } listener)
              ]
      }

let tests =
      { minimal =
            assert
          :   JSON.render
                ( JSON.omitNullFields
                    (render.json (Listener.TCP Options.TCP::{=}))
                )
            ≡ "{ \"tcp\": { \"tls_disable\": \"true\" } }"
      , tls =
            assert
          :   JSON.render
                ( JSON.omitNullFields
                    ( render.json
                        ( Listener.TCP
                            Options.TCP::{
                            , tls = Some Options.TCP.TLS::{
                              , cert_file = "/etc/certs/vault.crt"
                              , key_file = "/etc/certs/vault.key"
                              }
                            }
                        )
                    )
                )
            ≡ "{ \"tcp\": { \"tls_cert_file\": \"/etc/certs/vault.crt\", \"tls_disable\": \"false\", \"tls_key_file\": \"/etc/certs/vault.key\" } }"
      , proxy_protocol_behavior =
            assert
          :   JSON.render
                ( JSON.omitNullFields
                    ( render.json
                        ( Listener.TCP
                            Options.TCP::{
                            , proxy_protocol_behavior = Some
                                ( Options.TCP.ProxyProtocolBehavior.AllowAuthorized
                                    Options.TCP.ProxyProtocolBehavior.Options.Addresses::{
                                    , first = "foo"
                                    , additional = [ "bar" ]
                                    }
                                )
                            }
                        )
                    )
                )
            ≡ "{ \"tcp\": { \"proxy_protocol_authorized_addrs\": [ \"foo\", \"bar\" ], \"proxy_protocol_behavior\": \"allow_authorized\", \"tls_disable\": \"true\" } }"
      }

let exports =
      { Type = Listener
      , TCP = λ(tcp : Options.TCP.Type) → Listener.TCP tcp
      , Options = Options
      , render = render
      }

in  exports
