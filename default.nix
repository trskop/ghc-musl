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
  "v4"
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
  gcc-unwrapped
  zlib zlib.static
  libffi (libffi.override { stdenv = makeStaticLibraries stdenv; })
] ++ lib.optionals (!integer-simple) [ gmp (gmp.override { withStatic = true; }) ];

packages = with pkgsMusl; [
  bash coreutils gnused gnugrep gawk
  gcc-unwrapped binutils-unwrapped
  pkgconfig automake autoconf
  shadow cacert
] ++ [
  haskellPackages.ghc
  (haskell.lib.justStaticExecutables haskellPackages.cabal-install)
];

base = pkgsOrig.dockerTools.buildImage {
  name = "base";
  fromImage = pkgsOrig.dockerTools.pullImage {
    imageName = "alpine";
    # tag: 3.11.0
    imageDigest = "sha256:d371657a4f661a854ff050898003f4cb6c7f36d968a943c1d5cde0952bd93c80";
    sha256 = "1vihf2h65q9hb13kaf47hqlb1khnyiiz32x7ck11srvjwvqfry4h";
  };
  runAsRoot = ''
    #!${pkgsMusl.stdenv.shell}
    ${pkgsMusl.dockerTools.shadowSetup}
  '';
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

