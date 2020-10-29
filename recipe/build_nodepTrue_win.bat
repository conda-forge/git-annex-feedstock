rem
rem Script: build_nodepTrue_win.bat
rem
rem Builds a conda-forge package that installs the standalone git-annex distribution for Windows
rem as built/maintained at https://github.com/datalad/datalad-extensions
rem and distributed through http://datasets.datalad.org/datalad/packages/windows/
rem This conda package has no dependencies, and would require sensible bash
rem installation (see https://github.com/ContinuumIO/anaconda-issues/issues/12124
rem as a blocker for using m2-bash ATM) which could come by using git bash from
rem git for windows installation.  So it does neither depend on git, although
rem it might be installed inside conda environment.
rem
rem Note: very experimental
rem

7z x git-annex-installer_*_x64.exe
xcopy /I /E usr %LIBRARY_PREFIX%\usr
