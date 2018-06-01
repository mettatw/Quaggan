FROM pacman_builder:5.1.0

COPY pacman.patch /

# --no-pie is because newer gccs tend to by default enable pie
RUN cd && export LDFLAGS="-static -s -Wl,-O3 -Wl,--sort-common -no-pie" \
  && export CFLAGS="-g0 -O3 -pipe -w -fomit-frame-pointer" \
  && export CXXFLAGS="$CFLAGS" \
  && cd ~ \
    && curl -LJkO https://tukaani.org/xz/xz-5.2.4.tar.gz \
    && curl -LJkO https://curl.haxx.se/download/curl-7.60.0.tar.bz2 \
    && curl -LJkO http://www.libarchive.org/downloads/libarchive-3.3.2.tar.gz \
    && curl -LJkO https://sources.archlinux.org/other/pacman/pacman-5.1.0.tar.gz \
  && cd / \
    && tar xf ~/xz-*.tar.gz \
    && tar xf ~/curl-*.tar.bz2 \
    && tar xf ~/libarchive-*.tar.gz \
    && tar xf ~/pacman-*.tar.gz \
  && cd /xz-* \
    && ./configure --prefix=/tmp --disable-nls --disable-shared --disable-scripts --enable-threads \
    && make AM_LDFLAGS="-all-static" && upx --best src/xz/xz && install -D src/xz/xz /tmp/bin/xz \
  && cd /curl-* \
    && ./configure --prefix=/tmp --disable-nls \
    && make curl_LDFLAGS=-all-static && upx --best src/curl && install -D src/curl /tmp/bin/curl \
  && cd /libarchive-* \
    && ./configure --prefix=/tmp --disable-shared \
    && make bsdtar_LDFLAGS="-all-static" LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" \
    && upx --best bsdtar && install bsdtar /tmp/bin/bsdtar \
  && cd /pacman-* \
    && patch -Np1 < /pacman.patch \
    && ./configure --prefix="/tmp" --enable-static --disable-shared --disable-nls --disable-doc --with-root-dir="/tmp" --with-libcurl \
    && make AM_LDFLAGS="-all-static" LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" \
    && make install AM_LDFLAGS="-all-static" LIBS="-larchive -lcurl -lssl -lcrypto -lm -lbz2 -llzma -lexpat -lssh2 -lacl -llz4 -lz" \
    && upx --best /tmp/bin/pacman /tmp/bin/pacsort /tmp/bin/cleanupdelta /tmp/bin/pactree /tmp/bin/testpkg /tmp/bin/vercmp \
    && rm -f /tmp/bin/makepkg* \
  && cd /tmp/bin \
    && tar cJf /pacman-5.1.0-linux-x86-64.tar.xz *
