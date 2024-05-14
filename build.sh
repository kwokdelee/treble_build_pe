#!/bin/bash

# Set up environment variables
BL=$PWD/treble_build_pe
BD=$HOME/builds
TREBLE_DIR=$PWD/treble_experimentations
PATCHES_ZIP_URL=$(curl -s https://api.github.com/repos/TrebleDroid/treble_experimentations/releases/latest | grep -oP '"browser_download_url": "\K(.*patches-for-developers.zip)')

# Functions
initRepos() {
    if [ ! -d .repo ]; then
        echo "--> Initializing workspace"
        repo init -u https://github.com/PixelExperience/manifest -b fourteen
    else
        echo "--> Reinitializing workspace"
        repo forall -c 'git reset --hard; git clean -fdx'
        repo init -u https://github.com/PixelExperience/manifest -b fourteen
    fi

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BL/manifest.xml .repo/local_manifests/pixel.xml
}

syncRepos() {
    echo "--> Syncing repos"
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
}

applyPatches() {
    echo "--> Applying patches"
    bash $BL/apply-patches.sh $BL
}

setupEnv() {
    echo "--> Setting up build environment"
    source build/envsetup.sh &>/dev/null
    mkdir -p $BD
}

buildVariant() {
    echo "--> Building treble_arm64_bvN"
    lunch treble_arm64_bvN-userdebug
    make -j$(nproc --all) installclean
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-treble_arm64_bvN.img
}

# Main execution
echo "--------------------------------------"
echo "    Pixel Experience 14.0 Buildbot    "
echo "                  by                  "
echo "                ponces                "
echo "--------------------------------------"

# Download and prepare TrebleDroid files
wget -q "$PATCHES_ZIP_URL" -O patches-for-developers.zip
unzip -q patches-for-developers.zip -d $TREBLE_DIR
cp $TREBLE_DIR/manifest.xml .repo/local_manifests/pixel.xml
rm -rf system

# Initialize and sync repositories
initRepos
syncRepos

# Apply patches
applyPatches

# Set up build environment
setupEnv

# Build the GSI variant
buildVariant

echo "--> Build completed successfully"
