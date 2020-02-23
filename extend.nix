let
  sources = import ./nix/sources.nix;

  defaultNixpkgs = import sources.nixpkgs { config.allowBroken = true; };

  defaultCompiler = "ghc865";

in { pkgsOrig ? defaultNixpkgs, compiler ? defaultCompiler
, integer-simple ? false }:

let
  pkgs = pkgsOrig.pkgsMusl;
  lib = pkgs.stdenv.lib;

  name = "ghc-musl";
  baseImageTag = lib.concatStringsSep "-" [
    "v4"
    (if integer-simple then "integer-simple" else "libgmp")
    compiler
  ];
  tag = lib.concatStringsSep "-" [ baseImageTag "extended" ];

  extraLibraries = with pkgs; [
    ncurses
    (ncurses.override { enableStatic = true; })
  ];

  baseImage = pkgsOrig.dockerTools.pullImage {
    imageName = "utdemir/${name}";
    finalImageName = "${name}";
    finalImageTag = baseImageTag;
    imageDigest = if integer-simple then
      "sha256:93b580bad763a91d8e538a13e9823aa5ed198f75899acdfbc68d186c82b28f42"
    else
      "sha256:d7e8df404eec76ee7b173b67bb8a47af350a808e59c0f5a7ed7977724ff4a703";
    sha256 = if integer-simple then
      "1kw6z08asad1rnnm99k0ks7wvbnlnls9cr3akkik7dggwxlxap9g" # TODO: Is this correct?
    else
      "1g8gkb2y08sk53rvjyc8g0rwikr8ia47f7v2skc5v8aalbw1cn03";
  };

  image = pkgsOrig.dockerTools.buildImage {
    inherit name tag;
    fromImage = baseImage;
    contents = extraLibraries;

    # TODO:
    #   How can we extend existing config from previous layer?
    #
    #   At the moment these values were obtained by analysing baseImage
    #   manually:
    #   ```
    #   tar xf /nix/store/<hash>-docker-image-utdemir-ghc-musl-v4-libgmp-ghc865.tar manifest.json
    #   configJson="$(jq --raw-output '.[] | .Config' < ./manifest.json)"
    #   tar xf /nix/store/<hash>-docker-image-utdemir-ghc-musl-v4-libgmp-ghc865.tar "${configJson}"
    #   jq .config < "./${configJson}"
    #   ```
    config = {
      Cmd =
        [ "/nix/store/z2dycr9p0ky50xrx092pf34l9snrg0jg-bash-4.4-p23/bin/sh" ];
      Env = [
        "PATH=/nix/store/z2dycr9p0ky50xrx092pf34l9snrg0jg-bash-4.4-p23/bin:/nix/store/g28qj8qs91b9c8q3h0yxm6hsr9fbc2dc-coreutils-8.31/bin:/nix/store/ljlp3ki981wxx2xv6sgyxcwm0ia9b45f-gnused-4.7/bin:/nix/store/7l3qyw4cadnxkpa9d62qiz5gqng924df-gnugrep-3.3/bin:/nix/store/6rnqxq12dpdh53h45r24rs428zngmdil-gawk-5.0.1/bin:/nix/store/gnpd2bvbyfn47qxf4jyqhq70s8bc0jji-binutils-wrapper-2.31.1/bin:/nix/store/b1zj8ydpycg7vncj40mafr177bs66gw1-binutils-2.31.1/bin:/nix/store/war4i15p8qxjfcfh0z36sqvvksfd3l7j-gcc-wrapper-8.3.0/bin:/nix/store/r3cd50f8hx3i6a6k7y12n050xlprwzsa-pkg-config-0.29.2/bin:/nix/store/gijlwiffb8arby6h81hq6fdyrj292dn9-automake-1.16.1/bin:/nix/store/hz2n1y3z07lbqnhxk0vnfgk1pw47vsid-autoconf-2.69/bin:/nix/store/8sabqvrbjl2vk5lcfii0hddn1j9w5bl9-shadow-4.7/bin:/nix/store/fx5rbdxj90m1f5gryad09l1pdglq4nm3-nss-cacert-3.46.1/bin:/nix/store/4888cn1b1gfpa5qnymkcwl1dxpjiday6-ghc-8.6.5/bin:/nix/store/8nairi77rny5gsgzf7v0gxw5xxavf54x-cabal-install-3.0.0.0/bin:/bin"
        "NIX_CC_WRAPPER_x86_64_unknown_linux_musl_TARGET_TARGET=1"
        "NIX_BINTOOLS_WRAPPER_x86_64_unknown_linux_musl_TARGET_TARGET=1"
        "LD_LIBRARY_PATH=/nix/store/sgna2llf4wds8va3r2qgr0gjy56x7jix-musl-1.1.24/lib:/nix/store/l5ybly3d4iva0lhjwl9yygcmzd0rqhrl-zlib-1.2.11/lib:/nix/store/n99gwnf3zkbs89kp4ik7l675zw53lp03-zlib-1.2.11-static/lib:/nix/store/58vyfy3wv7lnvy2nr33f648d1rjp4iz5-libffi-3.2.1/lib:/nix/store/lrkz0hr9mrwhwpnp21lqq1lw944pisiw-libffi-3.2.1/lib:/nix/store/h8lv17fdhnd734dgi92ym5376jsshhhf-gmp-6.1.2/lib:/nix/store/l5dfinb1z7qn71m2y8dcrbjlxp4man6w-gmp-6.1.2/lib"
        "C_INCLUDE_PATH=/nix/store/jav4r2b5j8rg7pf7clnrhqawclq48zva-musl-1.1.24-dev/include:/nix/store/diqbpkdcn5m8x4l7bz92pa7spam85fd9-zlib-1.2.11-dev/include:/nix/store/n99gwnf3zkbs89kp4ik7l675zw53lp03-zlib-1.2.11-static/include:/nix/store/2wv8iwqrnp848p8rw5asjwd4lpwb1qg2-libffi-3.2.1-dev/include:/nix/store/38jg0z1qsm0r8bbv8sl4yll3y024nzgb-libffi-3.2.1-dev/include:/nix/store/8v5ixwc7g4ww6xdbs3dcf65fcd1sx1xd-gmp-6.1.2-dev/include:/nix/store/lp16kzw9q73n9qlsnzab1vpx5pf9r4ib-gmp-6.1.2-dev/include:${
          lib.makeSearchPathOutput "dev" "include" extraLibraries
        }"
        "NIX_TARGET_LDFLAGS=-L/nix/store/sgna2llf4wds8va3r2qgr0gjy56x7jix-musl-1.1.24/lib -L/nix/store/l5ybly3d4iva0lhjwl9yygcmzd0rqhrl-zlib-1.2.11/lib -L/nix/store/n99gwnf3zkbs89kp4ik7l675zw53lp03-zlib-1.2.11-static/lib -L/nix/store/58vyfy3wv7lnvy2nr33f648d1rjp4iz5-libffi-3.2.1/lib -L/nix/store/lrkz0hr9mrwhwpnp21lqq1lw944pisiw-libffi-3.2.1/lib -L/nix/store/h8lv17fdhnd734dgi92ym5376jsshhhf-gmp-6.1.2/lib -L/nix/store/l5dfinb1z7qn71m2y8dcrbjlxp4man6w-gmp-6.1.2/lib ${
          lib.concatMapStringsSep " " (s: "-L${lib.getOutput "lib" s}/lib")
          extraLibraries
        }"
      ];
    };
  };

in { inherit image; }
