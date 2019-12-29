let
sources = import ./nix/sources.nix;
in

{ pkgsOrig ? import sources.nixpkgs { config.allowBroken = true; }
, compiler
, integer-simple
}:

let

user = "utdemir";
name = "ghc-musl";
tag = lib.concatStringsSep "-" [
  "v5"
  (if integer-simple then "integer-simple" else "libgmp")
  compiler
];

pkgsMusl = pkgsOrig.pkgsMusl;
haskell = pkgsMusl.haskell;
lib = pkgsMusl.stdenv.lib;

haskellPackages =
  (if integer-simple
   then haskell.packages.integer-simple
   else haskell.packages).${compiler}.override {
  overrides = se: su: {
  };
};

libraries = with pkgsMusl; [
  musl
  libffi (libffi.override { stdenv = makeStaticLibraries stdenv; })
] ++ lib.optionals (!integer-simple) [ gmp (gmp.override { withStatic = true; }) ];

packages = with pkgsMusl; [
  bash coreutils gnused gnugrep gawk
  pkgconfig automake autoconf
  shadow cacert wget
] ++ [
  haskellPackages.ghc
  (haskell.lib.justStaticExecutables haskellPackages.cabal-install)
];

base = pkgsOrig.dockerTools.buildImage {
  name = "base";
  fromImage = pkgsOrig.dockerTools.pullImage {
    imageName = "utdemir/ghc-musl";
    # tag: base-v1
    imageDigest = "sha256:d8126c95906c96e8ea2792ee243c80a0d2e3f908784fbb3928e964d332eafd0c";
    sha256 = "0yx9h7dq9yjfwwk8wr0n3x03xiragc3zlj86h8cgifa05yj0wsiz";
  };
};

image = pkgsOrig.dockerTools.buildImage {
  inherit name tag;
  diskSize = 8192;
  fromImage = base;
  config = {
    Cmd = [ "${pkgsMusl.bash}/bin/sh" ];
    Env = [
      "PATH=${lib.makeSearchPath "bin" packages}:/usr/bin:/bin:/sbin"
      "LIBRARY_PATH=${lib.makeLibraryPath libraries}:/usr/lib:/lib"
      "LD_LIBRARY_PATH=${lib.makeLibraryPath libraries}:/usr/lib:/lib"
      "C_INCLUDE_PATH=${lib.makeSearchPathOutput "dev" "include" libraries}:/usr/include:/include"
    ];
  };
};

in

{
  tag=tag;
  image=image;
  upload = pkgsOrig.writeScript "upload-${name}-${tag}" ''
    #!/usr/bin/env bash
    set -x
    # Ideally we would use skopeo, however somehow it doesn't
    # copy over the metadata like ENV or CMD.
    # ${pkgsOrig.skopeo}/bin/skopeo copy -f v2s2 \
    #   tarball:${image} \
    #   docker://${user}/${name}:${tag}

    cat ${image} | docker load
    docker tag "${name}:${tag}" "${user}/${name}:${tag}"
    docker push "${user}/${name}:${tag}"
  '';
}

