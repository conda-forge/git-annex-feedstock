set -eu

# based on https://raw.githubusercontent.com/conda/conda-recipes/master/vagrant/build.sh
# THANK YOU!
if [ `uname` != Darwin ]; then
    echo "This recipe only supports OS X for now."
    exit 1
fi

echo "Mounting the disk image"
DMG=`ls $SRC_DIR`
MOUNT_POINT=`hdiutil attach $DMG| tail -n 1 | cut -f 1 -d" "`
MOUNT_LOCATION=`mount | grep $MOUNT_POINT | cut -d" " -f 3`

echo "Copying"
rsync -a "$MOUNT_LOCATION/git-annex.app/Contents/MacOS/" "$PREFIX/bin/"

# We might to do that into some lib/ and then add symlinks
# ln -s ../...

echo "Unmounting the disk image"
hdiutil detach "$MOUNT_LOCATION"

