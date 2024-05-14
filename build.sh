#!/bin/bash

# Define the paths
BL=$PWD/treble_build_pe
BD=$HOME/builds
TREBLE_DIR=$PWD/treble_experimentations

# Function to handle the remote aosp conflict
handleRemoteAosp() {
    if git remote | grep -q 'aosp'; then
        git remote rm aosp
    fi
}

# Function to source the build environment
sourceBuildEnv() {
    # Replace this with the actual path to your build environment setup script
    source /path/to/your/envsetup.sh
}

# Main build function
buildGSI() {
    # Handle the remote aosp conflict
    handleRemoteAosp

    # Initialize the repo
    repo init -u https://github.com/PixelExperience/manifest -b fourteen
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)

    # Source the build environment
    sourceBuildEnv

    # Run the lunch command (ensure this is available in your environment)
    lunch treble_arm64_bvN-userdebug

    # Build the system image
    make installclean
    make systemimage

    # Move the system image to the builds directory
    mv $OUT/system.img $BD/system-treble_arm64_bvN.img
}

# Execute the build function
buildGSI
