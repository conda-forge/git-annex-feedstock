#
# Script: build_nodepTrue_win.bat
#
# Builds a conda-forge package that installs the standalone git-annex distribution for Windows
# as built/maintained at https://github.com/datalad/datalad-extensions
# and distributed through http://datasets.datalad.org/datalad/packages/windows/
# This conda package has no dependencies, and would require sensible bash
# installation (see https://github.com/ContinuumIO/anaconda-issues/issues/12124
# as a blocker for using m2-bash ATM) which could come by using git bash from
# git for windows installation.  So it does neither depend on git, although
# it might be installed inside conda environment.
#
# Note: very experimental
#

7z x git-annex-installer_*_x64.exe
xcopy /I /E usr\ %LIBRARY_PREFIX%\
