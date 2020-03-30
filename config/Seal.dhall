let imports = ../imports.dhall

let Prelude = imports.Prelude

let JSON = Prelude.JSON

let UtilityLibrary = imports.UtilityLibrary

let hcl-render = UtilityLibrary.hcl.render

let Options =
    {- Vault supports a variety of seal management mechanisms.
    -- Currently, we support configuring the AWS Key Management
    -- System (KMS) only.
    -}
      let AWS-KMS =
            let AWS-KMS =
                {- Most of these settings are provided for the sake of
                -- completeness. In general, if they need to be provided,
                -- they should be provided by way of environment variables
                -- exposed to the Vault process.
                -}
                  { Type =
                      { region : Optional Text
                      , access_key : Optional Text
                      , session_token : Optional Text
                      , secret_key : Optional Text
                      , kms_key_id : Optional Text
                      , endpoint : Optional Text
                      }
                  , default =
                    { region = None Text
                    , access_key = None Text
                    , session_token = None Text
                    , secret_key = None Text
                    , endpoint = None Text
                    }
                  }

            in    AWS-KMS
                ∧ { render =
                    { hcl-type = λ(_ : AWS-KMS.Type) → "awskms"
                    , json =
                          λ(aws-kms : AWS-KMS.Type)
                        → JSON.object
                            ( toMap
                                { region =
                                    hcl-render.helpers.json.optional.text
                                      aws-kms.region
                                , access_key =
                                    hcl-render.helpers.json.optional.text
                                      aws-kms.access_key
                                , session_token =
                                    hcl-render.helpers.json.optional.text
                                      aws-kms.session_token
                                , secret_key =
                                    hcl-render.helpers.json.optional.text
                                      aws-kms.secret_key
                                , kms_key_id =
                                    hcl-render.helpers.json.optional.text
                                      aws-kms.kms_key_id
                                , endpoint =
                                    hcl-render.helpers.json.optional.text
                                      aws-kms.endpoint
                                }
                            )
                    }
                  }

      in  { AWS-KMS = AWS-KMS }

let Seal = < AWS-KMS : Options.AWS-KMS.Type >

let render =
      { json =
            λ(seal : Seal)
          → JSON.object
              [ Prelude.Map.keyValue
                  JSON.Type
                  (merge { AWS-KMS = Options.AWS-KMS.render.hcl-type } seal)
                  (merge { AWS-KMS = Options.AWS-KMS.render.json } seal)
              ]
      }

let test =
      { minimal =
            assert
          :   JSON.render
                ( JSON.omitNullFields
                    ( render.json
                        ( Seal.AWS-KMS
                            Options.AWS-KMS::{ kms_key_id = Some "example" }
                        )
                    )
                )
            ≡ ''
              { "awskms": { "kms_key_id": "example" } }
              ''
      }

let exports =
    {- The AWS-KMS export is provided as a helper export for the user.
    -- Instead of the user needing to write:
    --    let Seal = ./Seal.dhall
    --    in Seal.Type.AWS-KMS Seal.Options.AWS-KMS::{ kms_key_id = "example" }
    -- The user may instead write:
    --    let Seal = ./Seal.dhall
    --    in Seal.AWS-KMS Seal.Options.AWS-KMS::{ kms_key_id = "example" }
    -}
      { Type = Seal
      , AWS-KMS = λ(value : Options.AWS-KMS.Type) → Seal.AWS-KMS value
      , Options = Options
      , render = render
      }

in  exports
