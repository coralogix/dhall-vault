let imports = ../imports.dhall

let Prelude = imports.Prelude

let JSON = Prelude.JSON

let hcl = ./hcl-util.dhall

let Options =
    {- While Vault supports many storage backends, only a select few have been
    -- written out here; just what we need for now, for brevity's sake.
    -}
      let Filesystem =
            let Filesystem = { Type = { path : Text }, default = {=} }

            let render =
                  let render =
                        { hcl-type = λ(_ : Filesystem.Type) → "file"
                        , json =
                              λ(filesystem : Filesystem.Type)
                            → JSON.object
                                (toMap { path = JSON.string filesystem.path })
                        }

                  let test =
                        { minimal =
                              assert
                            :   JSON.render
                                  ( JSON.omitNullFields
                                      ( render.json
                                          Filesystem::{ path = "example" }
                                      )
                                  )
                              ≡ "{ \"path\": \"example\" }"
                        }

                  in  render

            in  Filesystem ∧ { render = render }

      let InMemory =
            let InMemory = { Type = {}, default = {=} }

            let render =
                  let render =
                        { hcl-type = λ(_ : InMemory.Type) → "inmem"
                        , json =
                              λ(inmemory : InMemory.Type)
                            → JSON.object ([] : Prelude.Map.Type Text JSON.Type)
                        }

                  let test =
                        { minimal =
                              assert
                            :   JSON.render
                                  ( JSON.omitNullFields
                                      (render.json InMemory::{=})
                                  )
                              ≡ "{ }"
                        }

                  in  render

            in  InMemory ∧ { render = render }

      let Raft =
            let Raft = { Type = { path : Text, node_id : Text }, default = {=} }

            let render =
                  let render =
                        { hcl-type = λ(_ : Raft.Type) → "raft"
                        , json =
                              λ(raft : Raft.Type)
                            → JSON.object
                                ( toMap
                                    { path = JSON.string raft.path
                                    , node_id = JSON.string raft.node_id
                                    }
                                )
                        }

                  let test =
                        { minimal =
                              assert
                            :   JSON.render
                                  ( JSON.omitNullFields
                                      ( render.json
                                          Raft::{
                                          , path = "foo"
                                          , node_id = "bar"
                                          }
                                      )
                                  )
                              ≡ "{ \"node_id\": \"bar\", \"path\": \"foo\" }"
                        }

                  in  render

            in  Raft ∧ { render = render }

      let S3 =
            let S3 =
                  { Type =
                      { bucket : Text
                      , endpoint : Optional Text
                      , region : Optional Text
                      , access_key : Optional Text
                      , secret_key : Optional Text
                      , session_token : Optional Text
                      , max_parallel : Optional Natural
                      , s3_force_path_style : Optional Bool
                      , disable_ssl : Optional Bool
                      , kms_key_id : Optional Text
                      , path : Optional Text
                      }
                  , default =
                      { endpoint = None Text
                      , region = None Text
                      , access_key = None Text
                      , secret_key = None Text
                      , session_token = None Text
                      , max_parallel = None Natural
                      , s3_force_path_style = None Bool
                      , disable_ssl = None Bool
                      , kms_key_id = None Text
                      , path = None Text
                      }
                  }

            let test = { create-minimal = S3::{ bucket = "example" } }

            let render =
                  let render =
                        { hcl-type = λ(_ : S3.Type) → "s3"
                        , json =
                              λ(s3 : S3.Type)
                            → JSON.object
                                ( toMap
                                    { bucket = JSON.string s3.bucket
                                    , endpoint =
                                        hcl.render.json.optional.text
                                          s3.endpoint
                                    , region =
                                        hcl.render.json.optional.text s3.region
                                    , access_key =
                                        hcl.render.json.optional.text
                                          s3.access_key
                                    , secret_key =
                                        hcl.render.json.optional.text
                                          s3.secret_key
                                    , session_token =
                                        hcl.render.json.optional.text
                                          s3.session_token
                                    , max_parallel =
                                        hcl.render.json.optional.natural
                                          s3.max_parallel
                                    , s3_force_path_style =
                                        hcl.render.json.optional.bool
                                          s3.s3_force_path_style
                                    , disable_ssl =
                                        hcl.render.json.optional.bool
                                          s3.disable_ssl
                                    , kms_key_id =
                                        hcl.render.json.optional.text
                                          s3.kms_key_id
                                    , path =
                                        hcl.render.json.optional.text s3.path
                                    }
                                )
                        }

                  let test =
                        { minimal =
                              assert
                            :   JSON.render
                                  ( JSON.omitNullFields
                                      (render.json S3::{ bucket = "foo" })
                                  )
                              ≡ "{ \"bucket\": \"foo\" }"
                        }

                  in  render

            in  S3 ∧ { render = render }

      in  { Filesystem = Filesystem, InMemory = InMemory, Raft = Raft, S3 = S3 }

let All =
    {- The parent configuration file requires a `storage` block, which configures where
    -- Vault will store its encrypted secrets.
    -- This `All` type represents the possibilities for that `storage` block, since any
    -- implementation can be used for it.
    -}
      let All =
            < Filesystem : Options.Filesystem.Type
            | InMemory : Options.InMemory.Type
            | Raft : Options.Raft.Type
            | S3 : Options.S3.Type
            >

      let render =
            { json =
                  λ(storage : All)
                → JSON.object
                    [ let key =
                          {- The key is a specific value which Vault understands
                          -- to identify the type of implementation being configured.
                          -- Each configuration has its own unique key, which is
                          -- defined above per implementation.
                          -}
                            merge
                              { Filesystem = Options.Filesystem.render.hcl-type
                              , InMemory = Options.InMemory.render.hcl-type
                              , Raft = Options.Raft.render.hcl-type
                              , S3 = Options.S3.render.hcl-type
                              }
                              storage

                      let value =
                          {- The value is the configuration itself of the storage
                          -- implementation.
                          -}
                            merge
                              { Filesystem = Options.Filesystem.render.json
                              , InMemory = Options.InMemory.render.json
                              , Raft = Options.Raft.render.json
                              , S3 = Options.S3.render.json
                              }
                              storage

                      in  Prelude.Map.keyValue JSON.Type key value
                    ]
            }

      let exports =
            { Type = All
            , Filesystem =
                λ(value : Options.Filesystem.Type) → All.Filesystem value
            , InMemory = λ(value : Options.InMemory.Type) → All.InMemory value
            , Raft = λ(value : Options.Raft.Type) → All.Raft value
            , S3 = λ(value : Options.S3.Type) → All.S3 value
            , render = render
            }

      in  exports

let HighAvailability =
    {- The parent Vault configuration file has an optional block called
    -- `ha_storage`, which can be used to coordinate High Availability for
    -- Vault when the primary storage implementation does not support
    -- High Availability. This `HighAvailability` type describes the potential
    -- options.
    -- The range of options is limited to those storage implementations which
    -- support high availability.
    -}
      let HighAvailability = < Raft : Options.Raft.Type >

      let render =
            { json =
                  λ(storage : HighAvailability)
                → JSON.object
                    [ Prelude.Map.keyValue
                        JSON.Type
                        (merge { Raft = Options.Raft.render.hcl-type } storage)
                        (merge { Raft = Options.Raft.render.json } storage)
                    ]
            }

      in  { Type = HighAvailability
          , Raft = λ(value : Options.Raft.Type) → HighAvailability.Raft value
          , render = render
          }

let exports =
      { All = All, HighAvailability = HighAvailability, Options = Options }

in  exports
