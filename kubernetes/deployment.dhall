let imports = ../imports.dhall

let Prelude = imports.Prelude

let Kubernetes = imports.Kubernetes

let UtilityLibrary = imports.UtilityLibrary

let Image = UtilityLibrary.kubernetes.Image

let Settings = ../settings.dhall

in    λ(settings : Settings.Type)
    → λ(references : { configmap : { name : Text }, secret : { name : Text } })
    → Kubernetes.Deployment::{
      , metadata = Settings.common.kubernetes.metadata.object-meta settings
      , spec = Some Kubernetes.DeploymentSpec::{
        , progressDeadlineSeconds = Some 600
        , replicas = Some 1
        , revisionHistoryLimit = Some 10
        , selector = Kubernetes.LabelSelector::{
          , matchLabels = Some
              (Settings.common.kubernetes.metadata.labels.selector settings)
          }
        , strategy = Some Kubernetes.DeploymentStrategy::{
          , type = Some "RollingUpdate"
          , rollingUpdate = Some Kubernetes.RollingUpdateDeployment::{
            , maxSurge = Some (Kubernetes.IntOrString.Int 1)
            , maxUnavailable = Some (Kubernetes.IntOrString.Int 1)
            }
          }
        , template = Kubernetes.PodTemplateSpec::{
          , metadata = Settings.common.kubernetes.metadata.object-meta settings
          , spec = Some
              ( let volumes =
                      { config = Kubernetes.Volume::{
                        , name = "config"
                        , configMap = Some Kubernetes.ConfigMapVolumeSource::{
                          , name = Some references.configmap.name
                          , optional = Some False
                          , items = Some
                            [ Kubernetes.KeyToPath::{
                              , key = "config.json"
                              , path = "config.json"
                              , mode = Some 444
                              }
                            ]
                          }
                        }
                      }

                in  Kubernetes.PodSpec::{
                    , affinity = Some Kubernetes.Affinity::{
                      , podAntiAffinity = Some Kubernetes.PodAntiAffinity::{
                        , preferredDuringSchedulingIgnoredDuringExecution = Some
                          [ Kubernetes.WeightedPodAffinityTerm::{
                            , podAffinityTerm = Kubernetes.PodAffinityTerm::{
                              , labelSelector = Some Kubernetes.LabelSelector::{
                                , matchLabels = Some
                                    ( Settings.common.kubernetes.metadata.labels.selector
                                        settings
                                    )
                                }
                              , topologyKey = "kubernetes.io/hostname"
                              }
                            , weight = 100
                            }
                          ]
                        }
                      }
                    , containers =
                      [ Kubernetes.Container::{
                        , command = Some [ "docker-entrypoint.sh" ]
                        , args = Some [ "server" ]
                        , env = Some
                            (   [ Kubernetes.EnvVar::{
                                  , name = "POD_IP"
                                  , valueFrom = Some Kubernetes.EnvVarSource::{
                                    , fieldRef = Some Kubernetes.ObjectFieldSelector::{
                                      , apiVersion = Some "v1"
                                      , fieldPath = "status.podIP"
                                      }
                                    }
                                  }
                                , Kubernetes.EnvVar::{
                                  , name = "VAULT_CLUSTER_ADDR"
                                  , value = Some
                                      "https://\$(POD_IP):${Natural/show
                                                              settings.ports.cluster-coordination.number}"
                                  }
                                ]
                              # merge
                                  { AWS-Simple =
                                        λ ( options
                                          : Settings.ConfigTemplate.Options.AWS-Simple.Type
                                          )
                                      → [ Kubernetes.EnvVar::{
                                          , name = "AWS_ACCESS_KEY_ID"
                                          , valueFrom = Some Kubernetes.EnvVarSource::{
                                            , secretKeyRef = Some Kubernetes.SecretKeySelector::{
                                              , name = Some
                                                  references.secret.name
                                              , key = "AWS_ACCESS_KEY_ID"
                                              , optional = Some False
                                              }
                                            }
                                          }
                                        , Kubernetes.EnvVar::{
                                          , name = "AWS_SECRET_ACCESS_KEY"
                                          , valueFrom = Some Kubernetes.EnvVarSource::{
                                            , secretKeyRef = Some Kubernetes.SecretKeySelector::{
                                              , name = Some
                                                  references.secret.name
                                              , key = "AWS_SECRET_ACCESS_KEY"
                                              , optional = Some False
                                              }
                                            }
                                          }
                                        ]
                                  }
                                  settings.config.template
                            )
                        , image = Some (Image.render settings.image)
                        , imagePullPolicy = Some "IfNotPresent"
                        , livenessProbe = Some Kubernetes.Probe::{
                          , failureThreshold = Some 3
                          , periodSeconds = Some 10
                          , successThreshold = Some 1
                          , tcpSocket = Some Kubernetes.TCPSocketAction::{
                            , port =
                                Kubernetes.IntOrString.Int
                                  settings.ports.api.number
                            }
                          , timeoutSeconds = Some 1
                          }
                        , name = Settings.common.kubernetes.metadata.name
                        , ports = Some
                          [ Kubernetes.ContainerPort::{
                            , containerPort = settings.ports.api.number
                            , protocol = Some "TCP"
                            }
                          , Kubernetes.ContainerPort::{
                            , containerPort =
                                settings.ports.cluster-coordination.number
                            , protocol = Some "TCP"
                            }
                          ]
                        , readinessProbe = Some Kubernetes.Probe::{
                          , failureThreshold = Some 3
                          , httpGet = Some Kubernetes.HTTPGetAction::{
                            , path = Some
                                "/v1/sys/health?standbycode=204&uninitcode=204&"
                            , port =
                                Kubernetes.IntOrString.Int
                                  settings.ports.api.number
                            , scheme = Some "HTTP"
                            }
                          , periodSeconds = Some 10
                          , successThreshold = Some 1
                          , timeoutSeconds = Some 1
                          }
                        , resources = Some Kubernetes.ResourceRequirements::{=}
                        , securityContext = Some Kubernetes.SecurityContext::{
                          , capabilities = Some Kubernetes.Capabilities::{
                            , add = Some [ "IPC_LOCK" ]
                            }
                          , readOnlyRootFilesystem =
                              let becauseSetCap = Some False in becauseSetCap
                          }
                        , terminationMessagePath = Some "/dev/termination-log"
                        , terminationMessagePolicy = Some "File"
                        , volumeMounts = Some
                          [ Kubernetes.VolumeMount::{
                            , name = volumes.config.name
                            , mountPath = "/vault/config"
                            }
                          ]
                        }
                      ]
                    , dnsPolicy = Some "ClusterFirst"
                    , restartPolicy = Some "Always"
                    , schedulerName = Some "default-scheduler"
                    , securityContext = Some Kubernetes.PodSecurityContext::{=}
                    , terminationGracePeriodSeconds = Some 30
                    , volumes = Some [ volumes.config ]
                    }
              )
          }
        }
      }
