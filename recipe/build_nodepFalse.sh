#!/bin/bash

set -e -o pipefail -x

#######################################################################################################
# Set up build environment
#######################################################################################################

mkdir -p $PREFIX/bin $BUILD_PREFIX/bin $PREFIX/lib $BUILD_PREFIX/lib $PREFIX/share $BUILD_PREFIX/share
export LIBRARY_PATH="${PREFIX}/lib:${LIBRARY_PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}"
export LDFLAGS=" -L${PREFIX}/lib ${LDFLAGS} "
export CPPFLAGS="-I${PREFIX}/include ${CPPFLAGS} "

export GMP_INCLUDE_DIRS=$PREFIX/include
export GMP_LIB_DIRS=$PREFIX/lib

#
# Install shim scripts to ensure that certain flags are always passed to the compiler/linker
#

if [ -z ${CC+x} ]; then
    echo "CC is unset";
else
    echo "CC is $CC"
    export CC=$(which $CC)
    echo "CC after which is $CC"

    echo "#!/bin/bash" > $CC-shim
    echo "set -e -o pipefail -x " >> $CC-shim
    echo "$CC -I$PREFIX/include -L$PREFIX/lib -pthread -fPIC \"\$@\"" >> $CC-shim
    chmod u+x $CC-shim
    export CC=$CC-shim
    echo "CC after shim is $CC"
fi

if [ -z ${GCC+x} ]; then
    echo "GCC is unset";
else
    echo "GCC is $GCC"
    export GCC=$(which $GCC)
    echo "GCC after which is $GCC"

    echo "#!/bin/bash" > $GCC-shim
    echo "set -e -o pipefail -x " >> $GCC-shim
    echo "$GCC -I$PREFIX/include -L$PREFIX/lib -pthread -fPIC \"\$@\"" >> $GCC-shim
    chmod u+x $GCC-shim
    export GCC=$GCC-shim
    echo "GCC after shim is $GCC"
fi

if [ -z ${LD+x} ]; then
    echo "LD is unset";
else
    echo "LD is $LD"
    export LD=$(which $LD)
    echo "LD after which is $LD"

    echo "#!/bin/bash" > $LD-shim
    echo "set -e -o pipefail -x " >> $LD-shim
    echo "$LD -L$PREFIX/lib \"\$@\"" >> $LD-shim
    chmod u+x $LD-shim
    export LD=$LD-shim
    echo "LD after shim is $LD"

    echo "#!/bin/bash" > ${LD}.gold
    echo "set -e -o pipefail -x " >> ${LD}.gold
    echo "$LD_GOLD -L$PREFIX/lib \"\$@\"" >> ${LD}.gold
    chmod u+x ${LD}.gold
    export LD_GOLD=${LD}.gold
    echo "LD_GOLD after shim is ${LD_GOLD}"
fi

#
# Hack: ensure that the correct libpthread is used.
# This fixes an issue specific to https://github.com/conda-forge/docker-images/tree/master/linux-anvil-comp7
# which I do not fully understand, but the fix seems to work.
# See https://github.com/conda/conda/issues/8380
#

HOST_LIBPTHREAD="${BUILD_PREFIX}/${HOST}/sysroot/usr/lib/libpthread.so"

if [[ -f "${HOST_LIBPTHREAD}" ]]; then
    rm ${HOST_LIBPTHREAD}
    ln -s /lib64/libpthread.so.0 ${HOST_LIBPTHREAD}
fi

#######################################################################################################
# Install bootstrap ghc
#######################################################################################################

mv ${SRC_DIR}/ghc_stk/stack ${BUILD_PREFIX}/bin/
chmod u+x ${BUILD_PREFIX}/bin/stack
which stack
stack --version

export GHC_BOOTSTRAP_PREFIX=${SRC_DIR}/ghc_bootstrap_pfx
mkdir -p $GHC_BOOTSTRAP_PREFIX/bin
export PATH=$PATH:${GHC_BOOTSTRAP_PREFIX}/bin

pushd ${SRC_DIR}/ghc_bootstrap
echo AAAAAAAAAAAAAAAABOUT to run configure
pwd
ls -l
./configure --prefix=${GHC_BOOTSTRAP_PREFIX} --with-gmp-includes=$PREFIX/include --with-gmp-libraries=$PREFIX/lib || cat config.log
make install
ghc-pkg recache

popd

#which cabal
#cabal update
#cabal install alex happy

#######################################################################################################
# Build recent ghc from source
#######################################################################################################

# pushd ${SRC_DIR}/ghc_src

# touch mk/build.mk
# echo "HADDOCK_DOCS = NO" >> mk/build.mk
# echo "BuildFlavour = quick" >> mk/build.mk
# echo "libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-includes=$PREFIX/include" >> mk/build.mk
# echo "libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-libraries=$PREFIX/lib" >> mk/build.mk
# echo "STRIP_CMD = $STRIP" >> build.mk

# ./boot
# ./configure --prefix=${BUILD_PREFIX}  --with-gmp-includes=$PREFIX/include --with-gmp-libraries=$PREFIX/lib  --with-iconv-includes=$PREFIX/include --with-iconv-libraries=$PREFIX/lib --with-system-libffi
# set +e
# make -j${CPU_COUNT}
# set -e
# make
# make install
# ghc-pkg recache
# popd

#######################################################################################################
# Build git-annex
#######################################################################################################

pushd ${SRC_DIR}/git_annex_main

export STACK_ROOT=${SRC_DIR}/stack_root
mkdir -p $STACK_ROOT
( 
    echo "extra-include-dirs:"
    echo "- ${PREFIX}/include"
    echo "extra-lib-dirs:"
    echo "- ${PREFIX}/lib"
    echo "ghc-options:"
    echo "  \"\$everything\": -optc-I${PREFIX}/include -optl-L${PREFIX}/lib"
    echo "apply-ghc-options: everything"
    echo "system-ghc: true"
) > "${STACK_ROOT}/config.yaml"

stack setup
stack update
stack install --extra-include-dirs ${PREFIX}/include --extra-lib-dirs ${PREFIX}/lib --ghc-options " -optc-I${PREFIX}/include -optl-L${PREFIX}/lib " --local-bin-path ${PREFIX}/bin --flag git-annex:magicmime
ln -s ${PREFIX}/bin/git-annex ${PREFIX}/bin/git-annex-shell
popd
