#!/usr/bin/env bash
# Build a statically-linked version of pacman
set -euo pipefail

if ! docker images | grep 'pacman_builder\s*5.1.0' >/dev/null 2>&1; then
  docker build -t pacman_builder:5.1.0 pacman_builder
fi

if ! docker images | grep 'pacman_build\s*5.1.0' >/dev/null 2>&1; then
  docker build -t pacman_build:5.1.0 pacman_build
fi

id="$(docker create pacman_build:5.1.0)"
docker cp "$id:/pacman-5.1.0-linux-x86-64.tar.xz" .
docker rm -v "$id"
