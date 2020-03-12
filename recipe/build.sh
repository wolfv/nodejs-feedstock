#!/usr/bin/env bash

# scrub -std=... flag which conflicts with builds
export CXXFLAGS=$(echo ${CXXFLAGS:-} | sed -E 's@\-std=[^ ]*@@g')

# Increase CPUs for multiarch builds
if [ "$(uname -m)" = "armv8" ] || [ "$(uname -m)" = "ppc64le" ]; then
    echo "Using $(grep -c ^processor /proc/cpuinfo) CPUs"
    CPU_COUNT=$(grep -c ^processor /proc/cpuinfo)
fi

if [ "$(uname)" = "Darwin" ]; then
    # unset macosx-version-min hardcoded in clang CPPFLAGS
    export CPPFLAGS="$(echo ${CPPFLAGS:-} | sed -E 's@\-mmacosx\-version\-min=[^ ]*@@g')"
    export CPPFLAGS="${CPPFLAGS} -D_DARWIN_C_SOURCE"
    echo "CPPFLAGS=$CPPFLAGS"
else
    # need librt for clock_gettime with nodejs >= 12.12
    export LDFLAGS="$LDFLAGS -lrt"
fi

echo "sysroot: ${CONDA_BUILD_SYSROOT:-unset}"

# The without snapshot comes from the error in
# https://github.com/nodejs/node/issues/4212.
./configure \
    --ninja \
    --prefix=${PREFIX} \
    --without-snapshot \
    --without-node-snapshot \
    --shared \
    --shared-libuv \
    --shared-openssl \
    --shared-zlib \
    --with-intl=system-icu

ninja -C out/Release

python tools/install.py install ${PREFIX} ''
cp out/Release/node $PREFIX/bin

node -v
npm version

if [ "$(uname)" != "Darwin" ]; then
  # Get rid of OSX specific files that confuse conda-build
  rm -rf $PREFIX/lib/node_modules/npm/node_modules/term-size/vendor/macos/term-size
fi
