#!/bin/bash

#
# Script: build_nodepFalse.sh
#
# Builds the standard (not no-dependencies) git-annex package.
#

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
# Hack: install shim scripts to ensure that certain flags are always passed to the compiler/linker
#

echo "#!/bin/bash" > $CC-shim
echo "set -e -o pipefail -x " >> $CC-shim
echo "$CC -I$PREFIX/include -L$PREFIX/lib -pthread -fPIC -O2 \"\$@\"" >> $CC-shim
chmod u+x $CC-shim
export CC=$CC-shim

echo "#!/bin/bash" > $GCC-shim
echo "set -e -o pipefail -x " >> $GCC-shim
echo "$GCC -I$PREFIX/include -L$PREFIX/lib -pthread -fPIC -O2 \"\$@\"" >> $GCC-shim
chmod u+x $GCC-shim
export GCC=$GCC-shim

echo "#!/bin/bash" > $LD-shim
echo "set -e -o pipefail -x " >> $LD-shim
echo "$LD -L$PREFIX/lib -O2 \"\$@\"" >> $LD-shim
chmod u+x $LD-shim
export LD=$LD-shim

echo "#!/bin/bash" > ${LD}.gold
echo "set -e -o pipefail -x " >> ${LD}.gold
echo "$LD_GOLD -L$PREFIX/lib -O2 \"\$@\"" >> ${LD}.gold
chmod u+x ${LD}.gold
export LD_GOLD=${LD}.gold

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

#
# Ensure that GHC build platform is x86_64-unknown-linux (which GHC knows how to target),
# rather than x86_64-conda-linux (which GHC does not know about).
# Suggested by @isuruf on github; see
# https://github.com/conda-forge/git-annex-feedstock/pull/96/commits/796678ac2cc106e67c4f1f89fb2e92c2ff153616 and
# https://github.com/conda-forge/git-annex-feedstock/runs/945996913
#
unset host_alias
unset build_alias

#######################################################################################################
# Install bootstrap ghc
#######################################################################################################

export GHC_BOOTSTRAP_PREFIX=${SRC_DIR}/ghc_bootstrap_pfx
mkdir -p $GHC_BOOTSTRAP_PREFIX/bin
export PATH_ORIG=$PATH
export PATH=$PATH:${GHC_BOOTSTRAP_PREFIX}/bin

pushd ${SRC_DIR}/ghc_bootstrap
./configure --prefix=${GHC_BOOTSTRAP_PREFIX}
make install
ghc-pkg recache
popd

#######################################################################################################
# Build recent ghc from source
#######################################################################################################

export GHC_SRC_PREFIX=${SRC_DIR}/ghc_src_pfx
mkdir -p $GHC_SRC_PREFIX/bin
export PATH=$PATH:${GHC_SRC_PREFIX}/bin

pushd ${SRC_DIR}/ghc_src

touch mk/build.mk
#echo "HADDOCK_DOCS = NO" >> mk/build.mk
echo "BuildFlavour = perf" >> mk/build.mk
echo "libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-includes=$PREFIX/include" >> mk/build.mk
echo "libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-libraries=$PREFIX/lib" >> mk/build.mk
echo "STRIP_CMD = $STRIP" >> build.mk

echo "========CHECKING FREE SPACE GLOBALLY==========="
df

echo "========CHECKING FREE SPACE==========="
df .

./boot
./configure --prefix=${GHC_SRC_PREFIX}  --with-gmp-includes=$PREFIX/include --with-gmp-libraries=$PREFIX/lib --with-system-libffi

set +e
echo "========BUILING GHC-STAGE1 FROM SOURCE, multi-cpu==========="
df .
make -j${CPU_COUNT} inplace/bin/ghc-stage1
df .
echo "========DONE BUILING GHC-STAGE1 FROM SOURCE, multi-cpu==========="
set -e
echo "========BUILING GHC-STAGE1 FROM SOURCE, one-cpu==========="
df .
make inplace/bin/ghc-stage1
df .
echo "========DONE BUILING GHC-STAGE1 FROM SOURCE, one-cpu==========="

echo "========SPACE USAGE AFTER STAGE1================"
du | sort -rn
echo "========DONE SPACE USAGE AFTER STAGE1================"

set +e
echo "========BUILING GHC FROM SOURCE, multi-cpu==========="
df .
make -j${CPU_COUNT}
df .
echo "========DONE BUILING GHC FROM SOURCE, multi-cpu==========="
set -e
echo "========BUILING GHC FROM SOURCE, one-cpu==========="
df .
make
df .
echo "========DONE BUILING GHC FROM SOURCE, one-cpu==========="
echo "========INSTALLING GHC==========="
df .
make install
df .
echo "========CLEANING GHC==========="
rm -rf `find . -type d -name testsuite`
make clean || echo "Error cleaning, ignoring"
df .
echo "========RECACHING==========="
ghc-pkg recache
echo "========DONE RECACHING==========="
df .
echo "========SPACE USAGE AFTER RECACHING==========="
pwd
du -hs .
popd

#######################################################################################################
# Build most recent ghc from source
#######################################################################################################

echo "========BUILDING GHC_SRC2==========="

pushd ${SRC_DIR}/ghc_src2

echo "BEFORE FIXING PATH"
echo $PATH
export PATH=${PATH_ORIG}:${GHC_SRC_PREFIX}/bin
echo "AFTER FIXING PATH"
echo $PATH

touch mk/build.mk
#echo "HADDOCK_DOCS = NO" >> mk/build.mk
echo "BuildFlavour = perf" >> mk/build.mk
echo "libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-includes=$PREFIX/include" >> mk/build.mk
echo "libraries/integer-gmp_CONFIGURE_OPTS += --configure-option=--with-gmp-libraries=$PREFIX/lib" >> mk/build.mk
echo "STRIP_CMD = $STRIP" >> build.mk

echo "========CHECKING FREE SPACE GLOBALLY==========="
df

echo "========CHECKING FREE SPACE==========="
df .

./boot
./configure --prefix=${BUILD_PREFIX}  --with-gmp-includes=$PREFIX/include --with-gmp-libraries=$PREFIX/lib --with-system-libffi

set +e
echo "========BUILING GHC-STAGE1 FROM SOURCE, multi-cpu==========="
df .
make -j${CPU_COUNT} inplace/bin/ghc-stage1
df .
echo "========DONE BUILING GHC-STAGE1 FROM SOURCE, multi-cpu==========="
set -e
echo "========BUILING GHC-STAGE1 FROM SOURCE, one-cpu==========="
df .
make inplace/bin/ghc-stage1
df .
echo "========DONE BUILING GHC-STAGE1 FROM SOURCE, one-cpu==========="

echo "========SPACE USAGE AFTER STAGE1================"
du | sort -rn
echo "========DONE SPACE USAGE AFTER STAGE1================"

set +e
echo "========BUILING GHC FROM SOURCE, multi-cpu==========="
df .
make -j${CPU_COUNT}
df .
echo "========DONE BUILING GHC FROM SOURCE, multi-cpu==========="
set -e
echo "========BUILING GHC FROM SOURCE, one-cpu==========="
df .
make
df .
echo "========DONE BUILING GHC FROM SOURCE, one-cpu==========="
echo "========INSTALLING GHC==========="
df .
make install
df .
echo "========CLEANING GHC==========="
rm -rf `find . -type d -name testsuite`
make clean || echo "Error cleaning, ignoring"
df .
echo "========RECACHING==========="
ghc-pkg recache
echo "========DONE RECACHING==========="
df .
echo "========SPACE USAGE AFTER RECACHING==========="
pwd
du -hs .
popd

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
#    echo "apply-ghc-options: everything"
    echo "system-ghc: true"
) > "${STACK_ROOT}/config.yaml"

echo $PATH
echo "========CALLING STACK SETUP==========="
stack -v --system-ghc setup 
echo "========CALLING STACK PATH==========="
stack -v --system-ghc path
echo "========CALLING STACK UPDATE==========="
stack -v --system-ghc update 
#echo "========CALLING STACK BUILD NETWORK==========="
#stack -v --system-ghc build --cabal-verbose --extra-include-dirs ${PREFIX}/include --extra-lib-dirs ${PREFIX}/lib --ghc-options " -optc-I${PREFIX}/include -optl-L${PREFIX}/lib " --local-bin-path ${PREFIX}/bin network-2.8.0.1
echo "========CALLING STACK BUILD==========="
stack -v --system-ghc install --cabal-verbose --extra-include-dirs ${PREFIX}/include --extra-lib-dirs ${PREFIX}/lib --ghc-options " -optc-I${PREFIX}/include -optl-L${PREFIX}/lib " --local-bin-path ${PREFIX}/bin --flag git-annex:magicmime --flag git-annex:dbus
ln -s ${PREFIX}/bin/git-annex ${PREFIX}/bin/git-annex-shell
echo "========CALLING STACK INSTALL==========="
#make install BUILDER=stack PREFIX=${PREFIX}
popd
