#! /bin/bash

set -e

log() {
    tput setaf 2
    tput bold
    echo "#### $* ####"
    tput sgr0
}

OLD_CWD="$(pwd)"

export DEBIAN_FRONTEND=noninteractive
export TERM=xterm-256color
export LC_ALL=C
export LANGUAGE=C
export SUDO_UID=${SUDO_UID:-1000}
export SUDO_GID=${SUDO_GID:-1000}

export APP=redeclipse
export BRANCH=${BRANCH:-stable}
export ARCH=${ARCH:-x86_64}
export REPO_URL=${REPO_URL:-https://github.com/red-eclipse/base.git}
# parsed automatically unless they are already set
export VERSION
export COMMIT

export WORKSPACE=$(readlink -f workspace)
export PREFIX=$WORKSPACE/$APP.AppDir
export DOWNLOADS=$WORKSPACE/downloads
export BUILD=$WORKSPACE/build
export RE_DIR=$PREFIX/usr/lib/$APP

log "VERSION: ${VERSION:(parsed later from source code)} -- BRANCH: $BRANCH"


log "preparing environment"
mkdir -p $WORKSPACE $PREFIX $DOWNLOADS $BUILD

cd $WORKSPACE
wget -Nc https://github.com/probonopd/AppImages/raw/master/functions.sh
. functions.sh


log "downloading and extracting deb files"

cd $DOWNLOADS
apt-get download libasound2 libsdl2-2.0-0 libsdl2-image-2.0-0 \
    libsdl2-mixer-2.0-0 zlib1g libjpeg62 libpng12-0  libflac8 libogg0 \
    libvorbis0a libpciaccess0 libdrm2 libxcb-dri2-0 libxcb-dri3-0 \
    libxcb-present0 libxcb1 libxau6 libxext6  libx11-6 libx11-xcb1 \
    libxfixes3 libxcb-xfixes0 libxdamage1 libexpat1 libegl1-mesa \
    libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libgles2-mesa libglu1-mesa \
    libtinfo5

for package in *.deb; do
    dpkg-deb -x $package .
done


cd $BUILD
if [ ! -d .git ]; then
    log "cloning Red Eclipse repository"
    git clone https://github.com/red-eclipse/base.git -n .
else
    log "updating Red Eclipse repository"
    git reset --hard HEAD
    git fetch
fi

git checkout ${COMMIT:-$BRANCH}
git submodule update --init

export VERSION=${VERSION:-$(cat src/engine/version.h | grep VERSION_STRING | cut -d'"' -f2)}
export COMMIT=${COMMIT:-$(git rev-parse --short HEAD)}


log "building Red Eclipse binaries"
pushd src

[ ! -d build ] && mkdir build

pushd build
cmake .. -G Ninja
ninja -v install
popd

popd


log "copying Red Eclipse resources"
mkdir -p $RE_DIR
for dir in bin config data; do
    mkdir -p $RE_DIR/$dir
    rsync -av --delete --exclude .github --exclude .git --delete $BUILD/$dir $RE_DIR
done


log "modifying global variables for AppImage tools"
export PATH=$PREFIX/bin:$PATH
export LD_LIBRARY_PATH=$PREFIX/lib:$LD_LIBRARY_PATH
export XDG_DATA_DIRS=$PREFIX/share:$XDG_DATA_DIRS
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH


cd $PREFIX
log "downloading AppRun"
get_apprun

log "copying dependencies and libraries"
copy_deps; copy_deps; copy_deps
rsync -av $DOWNLOADS/{lib,usr} $PREFIX
move_lib
mkdir -p $PREFIX/usr/bin/
rsync -av /bin/bash $PREFIX/usr/bin/


# move PulseAudio libraries as requested in #3
mv $PREFIX/usr/lib/x86_64-linux-gnu/pulseaudio/*.so $PREFIX/usr/lib/x86_64-linux-gnu/


log "deleting blacklisted libraries"
(cd $PREFIX/usr/lib/ && delete_blacklisted)
rm -v $PREFIX/usr/lib/x86_64-linux-gnu/lib{xcb,GL,drm,X}*.so.* || true


log "copying desktop file, icon and launcher"
cp $OLD_CWD/$APP{.desktop,.png} $PREFIX/
cp $OLD_CWD/$APP $PREFIX/usr/bin/
sed -i 's/_BRANCH_/'"$BRANCH"'/g' $PREFIX/usr/bin/$APP


log "getting desktop integration"
get_desktopintegration $APP


cd $WORKSPACE
log "generating appimage"

[ ! -e $OLD_CWD/out ] && mkdir -p $OLD_CWD/out

# non-FUSE, simple replacement for generate_type2_appimage
wget -c https://github.com/probonopd/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage --appimage-extract

APPIMAGE_FILENAME=${APP}-${VERSION}-${BRANCH}-${COMMIT}.AppImage
APPIMAGE_PATH=$OLD_CWD/out/$APPIMAGE_FILENAME

URL="zsync|https://download.assassinate-you.net/red-eclipse/appimage/latest/redeclipse_continuous-${BRANCH}_x86_64.AppImage.zsync"

squashfs-root/AppRun -n -v $PREFIX $APPIMAGE_PATH -u "$URL"

rm -r squashfs-root


log "fixing AppImage permissions"
chown $SUDO_UID:$SUDO_GID $OLD_CWD/out/*.AppImage
