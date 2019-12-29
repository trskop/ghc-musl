#!/usr/bin/env bash

set -o errexit

tag="$1"
if [[ -z "$tag" ]]; then
  echo "invalid syntax." 1>&2
  exit 1
fi

set -o xtrace

res="utdemir/ghc-musl:$tag"

im="$(docker build -q .)"
docker tag "$im" "$res"
docker push "$res"
