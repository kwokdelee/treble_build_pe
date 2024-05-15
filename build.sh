#!/bin/bash

multipleLanguages() {
    if [ -n $(echo $LANG | grep zh_CN) ]; then
        BUILDBOT="Miku UI Udon通用镜像自动构建"
        BUILDBOT_EXIT="3秒后开始构建Miku UI通用镜像 - CTRL-C退出"
        SHOW_VERSION="构建版本"
        ONCE_PASSWORD="请输入 $USER 的密码: "
        ARCH_LINUX="检测到Arch Linux"
        INIT_MIKU_UI="初始Miku UI"
        PREPARE_LOCAL_MANIFEST="处理treble manifest"
        SYNC_REPOS="同步仓库"
        APPLY_TREBLEDROID_PATCH="应用 trebledroid 补丁中"
        APPLY_PERSONAL_PATCH="应用 personal 补丁中"
        SET_UP_ENVIRONMENT="准备构建环境"
        DOWNLOAD_VIA="下载Via"
        GEN_DEVICE_MAKEFILE="生成 treble 设备"
        BUILD_TREBLE_APP="构建 treble app 中"
        BUILD_TREBLE_IMAGE="构建 treble 镜像中"
        BUILD_VNDKLITE_VARIANT="构建 vndklite 版本中"
        GEN_PACKAGE="打包中"
        GEN_UP_JSON="生成升级json"
        UP_GITHUB_RELEASE="上传到Github release"
        COMPLETED="构建完成，使用了 $1 分钟 $2 秒"
    else
        BUILDBOT="Miku UI Udon Treble Buildbot"
        BUILDBOT_EXIT="Executing in 3 seconds - CTRL-C to exit"
        SHOW_VERSION="Build version"
        ONCE_PASSWORD="Please enter the password of $USER: "
        ARCH_LINUX="Arch Linux Detected"
        INIT_MIKU_UI="Initializing Miku UI workspace"
        PREPARE_LOCAL_MANIFEST="Preparing local manifest"
        SYNC_REPOS="Syncing repos"
        APPLY_TREBLEDROID_PATCH="Applying trebledroid patches"
        APPLY_PERSONAL_PATCH="Applying personal patches"
        SET_UP_ENVIRONMENT="Setting up build environment"
        DOWNLOAD_VIA="Downloading Via"
        GEN_DEVICE_MAKEFILE="Treble device generation"
        BUILD_TREBLE_APP="Building treble app"
        BUILD_TREBLE_IMAGE="Building treble image"
        BUILD_VNDKLITE_VARIANT="Building vndklite variant"
        GEN_PACKAGE="Generating packages"
        GEN_UP_JSON="Generating Update json"
        UP_GITHUB_RELEASE="Upload to github release"
        COMPLETED="Buildbot completed in $1 minutes and $2 seconds"
    fi
}

warning() {
    echo
    echo "-----------------------------------------"
    echo "      $BUILDBOT                          "
    echo "                  by                     "
    echo "               xiaoleGun                 "
    echo " $BUILDBOT_EXIT                          "
    echo "-----------------------------------------"
    echo
    echo "$SHOW_VERSION: $VERSION_CODE"
    echo
}

autoInstallDependencies() {
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        distro=$(awk -F= '$1 == "ID" {print $2}' /etc/os-release)
        id_like=$(awk -F= '$1 == "ID_LIKE" {print $2}' /etc/os-release)
        if [[ "$distro" == "arch" || "$id_like" == "arch" ]]; then
            echo "$ARCH_LINUX"
            git clone https://github.com/akhilnarang/scripts $BD/builds
            cd $BD/scripts
            bash setup/arch-manjaro.sh
            cd $ND
        else
            echo "$password" | sudo -S apt-get update
            echo "$password" | sudo -S apt-get install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev xattr openjdk-11-jdk jq android-sdk-libsparse-utils python3 python2 repo -y
        fi
    fi
}

initRepo() {
    if [ ! -d .repo ]; then
        echo
        echo "--> $INIT_MIKU_UI"
        echo
        repo init -u https://github.com/Miku-UI/manifesto -b Udon_v2 --depth=1
    fi

    if [ -d .repo ] && [ ! -f .repo/local_manifests/miku-treble.xml ]; then
        echo
        echo "--> $PREPARE_LOCAL_MANIFEST"
        echo
        rm -rf .repo/local_manifests
        mkdir -p .repo/local_manifests
        echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<manifest>
  <remote name=\"github\"
          fetch=\"https://github.com\" />

  <project name=\"TrebleDroid/vendor_hardware_overlay\" path=\"vendor/hardware_overlay\" remote=\"github\" revision=\"pie\" />
  <project name=\"TrebleDroid/device_phh_treble\" path=\"device/phh/treble\" remote=\"github\" revision=\"android-14.0\" />
  <project name=\"TrebleDroid/vendor_interfaces\" path=\"vendor/interfaces\" remote=\"github\" revision=\"android-14.0\" />
  <project name=\"phhusson/vendor_magisk\" path=\"vendor/magisk\" remote=\"github\" revision=\"android-10.0\" />
  <project name=\"TrebleDroid/treble_app\" path=\"treble_app\" remote=\"github\" revision=\"master\" />
  <project name=\"phhusson/sas-creator\" path=\"sas-creator\" remote=\"github\" revision=\"master\" />
  <project name=\"platform/prebuilts/vndk/v28\" path=\"prebuilts/vndk/v28\" remote=\"aosp\" revision=\"204f1bad00aaf480ba33233f7b8c2ddaa03155dd\" clone-depth=\"1\" />

  <project path=\"packages/apps/QcRilAm\" name=\"AndyCGYan/android_packages_apps_QcRilAm\" remote=\"github\" revision=\"master\" />
</manifest>" > .repo/local_manifests/miku-treble.xml
    fi
}

syncRepo() {
    echo
    echo "--> $SYNC_REPOS"
    echo
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --all)
}

applyPatches() {
    patches="$(readlink -f -- $1)"
    tree="$2"

    for project in $(cd $patches/patches/$tree; echo *);do
        p="$(tr _ / <<<$project | sed -e 's;platform/;;g')"
        [ "$p" == treble/app ] && p=treble_app
        [ "$p" == vendor/hardware/overlay ] && p=vendor/hardware_overlay
        pushd $p
        for patch in $patches/patches/$tree/$project/*.patch; do
            git am $patch || exit
        done
        popd
    done
}

applyingPatches() {
    echo
    echo "--> $APPLY_TREBLEDROID_PATCH"
    echo
    applyPatches $SD trebledroid
    echo
    echo "--> $APPLY_PERSONAL_PATCH"
    echo
    applyPatches $SD personal
}

initEnvironment() {
    echo
    echo "--> $SET_UP_ENVIRONMENT"
    echo
    source build/envsetup.sh &> /dev/null
    rm -rf $BD
    mkdir -p $BD
}

downloadVia() {
    echo
    echo "--> $DOWNLOAD_VIA"
    echo
    wget https://res.viayoo.com/v1/via-release-cn.apk
}

generateDevice() {
    echo
    echo "--> $GEN_DEVICE_MAKEFILE"
    echo
    rm -rf device/*/sepolicy/common/private/genfs_contexts
    cd device/phh/treble
    git clean -fdx
    bash generate.sh miku
    cd via
    downloadVia
    cd ../../../..
}

buildTrebleApp() {
    echo
    echo "--> $BUILD_TREBLE_APP"
    echo
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ../vendor/hardware_overlay
    git commit -a -m "Update Treble App"
    cd ../..
}

buildTreble() {
    echo
    echo "--> $BUILD_TREBLE_IMAGE: $1"
    echo
    lunch $1-ap1a-userdebug
    make -j$(nproc --all) systemimage
    mv $OUT/system.img $BD/system-$1.img
    make installclean
}

buildSasImages() {
    echo
    echo "--> $BUILD_VNDKLITE_VARIANT: $1"
    echo
    cd sas-creator
    if [ -n "$(cat lite-adapter.sh | grep 3500M)" ]; then
        sed -i 's/3500M/5000M/' lite-adapter.sh
        sed -i 's/3500M/5000M/' run.sh
    fi
    echo "$password" | sudo -S bash lite-adapter.sh 64 $BD/system-$1.img
    cp s.img $BD/system-$1-vndklite.img
    echo "$password" | sudo -S rm -rf s.img d tmp
    cd ..
}

generatePackages() {
    echo
    echo "--> $GEN_PACKAGE: $1"
    echo
    BASE_IMAGE=$BD/system-$1.img
    mkdir --parents $BD/dsu/$1/; mv $BASE_IMAGE $BD/dsu/$1/system.img
    xz -cv9 $BD/dsu/$1/system.img -T0 > $BD/MikuUI-$VERSION-$VERSION_CODE-$2$3-$BUILD_DATE-UNOFFICIAL.img.xz
    mkdir --parents $BD/dsu/$1-vndklite/; mv ${BASE_IMAGE%.img}-vndklite.img $BD/dsu/$1-vndklite/system.img
    xz -cv9 $BD/dsu/$1-vndklite/system.img -T0 > $BD/MikuUI-$VERSION-$VERSION_CODE-$2$3-vndklite-$BUILD_DATE-UNOFFICIAL.img.xz
    rm -rf $BD/dsu
}

generateOtaJson() {
    echo
    echo "--> $GEN_UP_JSON"
    echo
    prefix="MikuUI-$VERSION-$VERSION_CODE-"
    suffix="-$BUILD_DATE-UNOFFICIAL.img.gz"
    json="{\"version\": \"$VERSION_CODE\",\"date\": \"$(date +%s -d '-4hours')\",\"variants\": ["
    find $BD -name "*.img.xz" | {
        while read file; do
            packageVariant=$(echo $(basename $file) | sed -e s/^$prefix// -e s/$suffix$//)
            case $packageVariant in
                "a64-ab") name="miku_treble_a64_bvN" ;;
                "arm64-ab") name="miku_treble_arm64_bvN" ;;
                "a64-ab-vndklite") name="miku_treble_a64_bvN-vndklite" ;;
                "arm64-ab-vndklite") name="miku_treble_arm64_bvN-vndklite" ;;
                "a64-ab-gapps") name="miku_treble_a64_bgN" ;;
                "arm64-ab-gapps") name="miku_treble_arm64_bgN" ;;
                "a64-ab-gapps-vndklite") name="miku_treble_a64_bgN-vndklite" ;;
                "arm64-ab-gapps-vndklite") name="miku_treble_arm64_bgN-vndklite" ;;
            esac
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/xiaoleGun/treble_build_miku/releases/download/$VERSION-$VERSION_CODE/$(basename $file)"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq '.variants |= sort_by(.name)' > $SD/ota.json
        cp $SD/ota.json $BD/ota.json
    }
}

personal() {
    echo
    echo "--> $UP_GITHUB_RELEASE"
    echo
    cd $SD
    git config user.name "xiaoleGun"
    git config user.email "1592501605@qq.com"
    GITLATESTTAG=$(git describe --tags --abbrev=0)
    GITCHANGELOG=$(git log $GITLATESTTAG..HEAD --pretty=format:"%s")
    GITHUB_TOKEN=$2
    assets=()
    for f in $BD/MikuUI-$VERSION-$VERSION_CODE-*.xz; do [ -f "$f" ] && assets+=(-a "$f"); done
    hub release create ${assets[@]} -m "Miku UI $VERSION v$VERSION_CODE

- CI build on $BUILD_DATE

### Change log
$GITCHANGELOG" $VERSION-$VERSION_CODE

    rm -rf $BD/MikuUI-$VERSION-$VERSION_CODE-*.xz
    cd ..
}

# Performing function
START=$(date +%s)
BUILD_DATE="$(date +%Y%m%d)"

SD=$(cd $(dirname $0);pwd)
BD=$HOME/builds
VERSION=Udon_v2
VERSION_CODE=`grep -oP '(?<=最新版本: ).*' $SD/README.md`

multipleLanguages
warning

sleep 3

read -s -p "$ONCE_PASSWORD" password

if [ $USER != xiaolegun ]; then
    autoInstallDependencies
fi
initRepo
syncRepo
applyingPatches
initEnvironment
generateDevice
buildTrebleApp

buildTreble miku_treble_arm64_bvN
buildTreble miku_treble_arm64_bgN
buildTreble miku_treble_a64_bvN
buildTreble miku_treble_a64_bgN

buildSasImages miku_treble_arm64_bvN
buildSasImages miku_treble_arm64_bgN
buildSasImages miku_treble_a64_bvN
buildSasImages miku_treble_a64_bgN

generatePackages miku_treble_arm64_bvN arm64-ab
generatePackages miku_treble_arm64_bgN arm64-ab -gapps
generatePackages miku_treble_a64_bvN a64-ab
generatePackages miku_treble_a64_bgN a64-ab -gapps

generateOtaJson

if [ $1 == release ] && [ -z $2 ]; then
    echo "请预设Token"
    exit 2
else
    personal
fi

END=$(date +%s)
ELAPSEDM=$(($(($END - $START)) / 60))
ELAPSEDS=$(($(($END - $START)) - $ELAPSEDM * 60))

multipleLanguages $ELAPSEDM $ELAPSEDS

echo
echo "--> $COMPLETED"
echo
