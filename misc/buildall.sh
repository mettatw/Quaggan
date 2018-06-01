#!/usr/bin/env bash
# Build a statically-linked version of essential tools
set -euo pipefail

if ! command -v docker >/dev/null || ! docker images >/dev/null; then
  echo "Error: You need to be able to use docker to build these things" >&2
  exit 1
fi

SCRIPTPATH="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$SCRIPTPATH"
trap "rm -fv '$SCRIPTPATH/Dockerfile'" EXIT

# Configs and functions

DEST=../bootstrap/bin

docker_copy_out() {
  local name="$1"
  shift
  local dest="$1"
  shift

  local id="$(docker create "$name")"
  for f in "$@"; do
    docker cp "$id:$f" "$dest"
  done
  docker rm -v "$id"
}

docker_image_exists() {
  local name="$1"
  if [[ "$(docker images -q "$name" 2>/dev/null)" == "" ]]; then
    return 1
  else
    return 0
  fi
}

# --no-pie is because newer gccs tend to by default enable pie
SETBUILDPARAMS="$(cat <<"EOF"
  && export LDFLAGS="-static -s -Wl,-O3 -Wl,--sort-common -no-pie" \
  && export CFLAGS="-g0 -O3 -pipe -w -fomit-frame-pointer" \
  && export CXXFLAGS="\$CFLAGS"
EOF
)"

# ++++ Build main builder docker image and set common things

VERBUILDER=0.0.1
NAMEBUILDER=quaggan-builder:$VERBUILDER
if ! docker_image_exists "$NAMEBUILDER"; then
  cat > Dockerfile <<"EOFDOCKER"
FROM alpine:3.7

RUN apk add --update g++ m4 libtool make upx curl xz libarchive perl sed file \
    curl-dev libarchive-dev libressl-dev xz-dev zlib-dev bzip2-dev libssh2-dev acl-dev lz4-dev expat-dev linux-headers \
    git automake autoconf \
  && rm -rf /var/cache/apk/*
EOFDOCKER
  docker build -t "$NAMEBUILDER" .
fi


# ++++ Build supplementary tools

VERXZ=5.2.4
NAMEXZ=quaggan-build-xz:$VERBUILDER-$VERXZ
if ! docker_image_exists "$NAMEXZ"; then
  cat > Dockerfile <<EOFDOCKER
FROM $NAMEBUILDER

RUN cd \
$SETBUILDPARAMS \
  && curl -LJO https://tukaani.org/xz/xz-$VERXZ.tar.gz \
  && cd / && tar xf ~/xz-*.tar.gz \
  && cd /xz-* \
  && ./configure --prefix=/tmp --disable-nls --disable-shared --disable-scripts --enable-threads \
  && make AM_LDFLAGS="-all-static" \
  && upx --best src/xz/xz \
  && install -D src/xz/xz /tmp/bin/xz
EOFDOCKER

  docker build -t "$NAMEXZ" .
  docker_copy_out "$NAMEXZ" "$DEST" /tmp/bin/xz
fi

VERCURL=7.60.0
NAMECURL=quaggan-build-curl:$VERBUILDER-$VERCURL
if ! docker_image_exists "$NAMECURL"; then
  cat > Dockerfile <<EOFDOCKER
FROM $NAMEBUILDER

RUN cd \
$SETBUILDPARAMS \
  && curl -LJO https://curl.haxx.se/download/curl-$VERCURL.tar.bz2 \
  && cd / && tar xf ~/curl-*.tar.bz2 \
  && cd /curl-* \
  && ./configure --prefix=/tmp --disable-nls \
  && make curl_LDFLAGS=-all-static \
  && upx --best src/curl \
  && install -D src/curl /tmp/bin/curl
EOFDOCKER

  docker build -t "$NAMECURL" .
  docker_copy_out "$NAMECURL" "$DEST" /tmp/bin/curl
fi

VERLIBARCHIVE=3.3.2
NAMELIBARCHIVE=quaggan-build-libarchive:$VERBUILDER-$VERLIBARCHIVE
if ! docker_image_exists "$NAMELIBARCHIVE"; then
  cat > Dockerfile <<EOFDOCKER
FROM $NAMEBUILDER

RUN cd \
$SETBUILDPARAMS \
  && curl -LJO http://www.libarchive.org/downloads/libarchive-$VERLIBARCHIVE.tar.gz \
  && cd / && tar xf ~/libarchive-*.tar.gz \
  && cd /libarchive-* \
  && ./configure --prefix=/tmp --disable-shared \
  && make bsdtar_LDFLAGS="-all-static" LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" \
  && upx --best bsdtar \
  && install -D bsdtar /tmp/bin/bsdtar
EOFDOCKER

  docker build -t "$NAMELIBARCHIVE" .
  docker_copy_out "$NAMELIBARCHIVE" "$DEST" /tmp/bin/bsdtar
fi

# ++++ Build pacman

VERPACMAN=5.1.0
NAMEPACMAN=quaggan-build-pacman:$VERBUILDER-$VERPACMAN
if ! docker_image_exists "$NAMEPACMAN"; then
  cat > Dockerfile <<EOFDOCKER
FROM $NAMEBUILDER

COPY pacman.patch /

RUN cd \
$SETBUILDPARAMS \
  && curl -LJO https://sources.archlinux.org/other/pacman/pacman-$VERPACMAN.tar.gz \
  && cd / && tar xf ~/pacman-*.tar.gz \
  && cd /pacman-* \
  && patch -Np1 -i /pacman.patch \
  && ./configure --prefix="/tmp" --enable-static --disable-shared --disable-nls --disable-doc --with-root-dir="/tmp" --with-libcurl \
  && make AM_LDFLAGS="-all-static" LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" \
  && make install AM_LDFLAGS="-all-static" LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" \
  \
  && cd ~ && git clone https://git.archlinux.org/pacman-contrib.git \
  && cd pacman-contrib && ./autogen.sh \
  && PKG_CONFIG_PATH="/tmp/lib/pkgconfig" ./configure --enable-static --disable-nls --disable-shared --with-root-dir="/tmp" --prefix="/tmp" \
  && make LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" -C src \
  && install -D src/pacsort src/pactree /tmp/bin/ \
  && upx --best /tmp/bin/pacman /tmp/bin/testpkg /tmp/bin/vercmp /tmp/bin/cleanupdelta \
    /tmp/bin/pacsort /tmp/bin/pactree
EOFDOCKER

  docker build -t "$NAMEPACMAN" .
  docker_copy_out "$NAMEPACMAN" "$DEST" /tmp/bin/{pacman,cleanupdelta,testpkg,vercmp,pacsort,pactree}
fi
