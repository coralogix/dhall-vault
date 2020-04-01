let
  nixpkgs = import (
    let
      version = "ef4b914b113119b7a70cf90b37496413d85723a3";
    in builtins.fetchTarball {
      name   = "nixpkgs-${version}";
      url    = "https://github.com/NixOS/nixpkgs/archive/${version}.tar.gz";
      sha256 = "1flgwivn53vk04svj4za39gg6g6r7r92g3y201h8cml0604gsmg8";
    }
  ) {};

  dhall-haskell = import (
    let
      version = "1.31.1";
    in nixpkgs.fetchFromGitHub {
      owner           = "dhall-lang";
      repo            = "dhall-haskell";
      rev             = version;
      fetchSubmodules = true;
      sha256          = "1pc5zrmyfby4wfr9a901iz7yihvq9q5vg2qdg74xdxvrcrxj9916";
    }
  );

in nixpkgs.mkShell {
  buildInputs = [
    dhall-haskell.dhall
    dhall-haskell.dhall-json
    nixpkgs.awscli
    nixpkgs.bash
    nixpkgs.coreutils
    nixpkgs.git
    nixpkgs.jq
    nixpkgs.kubectl
    nixpkgs.vault
  ];
}
