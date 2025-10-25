#!/bin/bash

#
# Script: build_nodepTrue.sh
#
# Builds a conda-forge package that installs the standalone git-annex distribution
# ( https://git-annex.branchable.com/install/Linux_standalone/ )
# This conda package has no dependencies, and can be installed into conda environments that contain other packages which
# conflict with git-annex dependencies; however, the standalone distribution has some issues that the standard one does not have
# (it can be slower, and see e.g.
# https://git-annex.branchable.com/todo/restore_original_environment_when_running_external_special_remotes_from_standalone_git-annex__63__/
# ), the standard conda-forge package should be used whenever possible.  meta.yaml gives a higher build number to the standard
# package, causing it to be preferred over the nodep package for the same git-annex version.
#

set -e -o pipefail -x

PACKAGE_HOME=${PREFIX}/share/${PKG_NAME}-${PKG_VERSION}-${PKG_BUILDNUM}

mkdir -p ${PACKAGE_HOME} ${PREFIX}/bin

mv * ${PACKAGE_HOME}/
ln -s ${PACKAGE_HOME}/git-{annex,annex-*,remote-*} ${PREFIX}/bin/
touch ${PACKAGE_HOME}/.standalone-dist-installed

