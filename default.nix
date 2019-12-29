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

ghc = haskellPackages.ghc.overrideDerivation (su: {
  postInstall = ''
    ${su.postInstall}
    for i in "$out/bin/"*; do
      test ! -h $i || continue
      egrep --quiet '^#!' <(head -n 1 $i) || continue
      sed -i -e '/^export PATH/d' $i
    done
  '';
});

packages = [
  ghc
  (haskell.lib.justStaticExecutables haskellPackages.cabal-install)
];

base = pkgsOrig.dockerTools.pullImage {
  imageName = "utdemir/ghc-musl";
  # tag: base-v1
  imageDigest = "sha256:4a9a672359ad7fa272af3cc5c9f010beedddef6d57bb79f790da729bfa10dcdd";
  sha256 = "0cixs4p36mj56k0jlrwbqv37chhq4nklmi9r5qs8fpgg1xabnx07";
};

image = pkgsOrig.dockerTools.buildImage {
  inherit name tag;
  fromImage = base;
  config = {
    Cmd = [ "${pkgsMusl.bash}/bin/sh" ];
    Env = [
      "PATH=/usr/bin:/bin:/sbin:${lib.makeSearchPath "bin" packages}"
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

