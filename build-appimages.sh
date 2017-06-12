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

export BRANCH=${BRANCH:-stable}
export ARCH=${ARCH:-x86_64}
export REPO_URL=${REPO_URL:-https://github.com/red-eclipse/base.git}
# parsed automatically unless they are already set
export VERSION
export COMMIT

export WORKSPACE=$(readlink -f workspace)
export CLIENT_APPDIR=$WORKSPACE/redeclipse.AppDir
export SERVER_APPDIR=$WORKSPACE/redeclipse-server.AppDir
export BUILD=$WORKSPACE/build

export BUILD_CLIENT=${BUILD_CLIENT:-1}
export BUILD_SERVER=${BUILD_SERVER:-0}


appdirs=()

if [ $BUILD_CLIENT -gt 0 ]; then
    appdirs+=("$CLIENT_APPDIR")
fi
if [ $BUILD_SERVER -gt 0 ]; then
    appdirs+=("$SERVER_APPDIR")
fi

if [ ${#appdirs[@]} -eq 0 ]; then
    echo "$(tput bold)$(tput setaf 1)**Error** you have to activate at least one build, either BUILD_CLIENT=1, BUILD_SERVER=1 or both!$(tput sgr0)"
    exit 1
fi


notset="(parsed later from source code)"
log "VERSION: ${VERSION:-$notset} -- BRANCH: $BRANCH"


log "Prepare environment"
mkdir -p $WORKSPACE $PREFIX $DOWNLOADS $BUILD


cd $BUILD
if [ ! -d .git ]; then
    log "Clone Red Eclipse repository"
    git clone https://github.com/red-eclipse/base.git -n .
else
    log "Update Red Eclipse repository"
    git reset --hard HEAD
    git pull
fi

log "Check out ${COMMIT:-$BRANCH}"
git checkout ${COMMIT:-$BRANCH}
log "Update Git submodules"
git submodule update --init

if [ "$VERSION" == "" ]; then
    log "Parse version from source code"
    VERSION="$(cat src/engine/version.h | grep VERSION_MAJOR | head -n1 | awk '{print $3}')"
    VERSION="$VERSION.$(cat src/engine/version.h | grep VERSION_MINOR | head -n1 | awk '{print $3}')"
    VERSION="$VERSION.$(cat src/engine/version.h | grep VERSION_PATCH | head -n1 | awk '{print $3}')"
fi
export VERSION

log "Version: $VERSION"


# fall back to HEAD when no commit is given
COMMIT=${COMMIT:-$(git rev-parse HEAD)}

log "Commit: $COMMIT"


# shorten commit if necessary
COMMIT=$(git rev-parse --short $COMMIT)

export COMMIT


log "Download and set up linuxdeployqt"

mkdir -p $WORKSPACE/linuxdeployqt
cd $WORKSPACE/linuxdeployqt
wget -cN https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage
chmod +x linuxdeployqt-continuous-x86_64.AppImage
./linuxdeployqt-continuous-x86_64.AppImage --appimage-extract

linuxdeployqt () {
    $WORKSPACE/linuxdeployqt/squashfs-root/AppRun $@ -bundle-non-qt-libs -verbose=1
}


log "Download and set up appimagetool"

mkdir -p $WORKSPACE/appimagetool
cd $WORKSPACE/appimagetool
wget -cN https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
./appimagetool-x86_64.AppImage --appimage-extract

appimagetool () {
    $WORKSPACE/appimagetool/squashfs-root/AppRun $@
}


log "Build Red Eclipse binaries"
pushd $BUILD/src

mkdir -p build

pushd build
cmake .. -G Ninja || (rm -r * && cmake .. -G Ninja)
ninja -v install
popd

popd


log "copying Red Eclipse data to AppDirs"

# create AppDirs
mkdir -p ${appdirs[@]}

# common operations for AppDirs
for appdir in ${appdirs[@]}; do
    log "Copy CubeScript files to $appdir"
    mkdir -p $appdir/usr/bin/config
    rsync -av --delete --exclude .github --exclude .git --delete $BUILD/config $appdir/usr/bin/

    log "Create FHS-like directory tree in $appdir"
    mkdir -p $appdir/usr/{bin,lib,share}

    log "Create data directory for $appdir"
    # has to be a subdirectory of usr/bin/ so that the binary in that directory is able to find them
    # TODO: make Red Eclipse find the game data relative to the binary (e.g., ../share/games/redeclipse/data)
    mkdir -p $appdir/usr/bin/data/maps

    mkdir -p $appdir/usr/share/icons/hicolor/128x128/ $appdir/usr/share/applications/
    log "Copy icons"
    cp $OLD_CWD/*.png $appdir/usr/share/icons/hicolor/128x128/
done

# copy client data
if [ $BUILD_CLIENT -gt 0 ]; then
    log "Copy client data"
    rsync -av --delete --exclude .github --exclude .git --delete $BUILD/data $CLIENT_APPDIR/usr/bin/

    log "Copy client binary"
    cp $BUILD/bin/amd64/redeclipse_linux $CLIENT_APPDIR/usr/bin/redeclipse

    log "Copy client desktop file"
    cp $OLD_CWD/redeclipse.desktop $CLIENT_APPDIR/usr/share/applications
fi

# copy server data
if [ $BUILD_SERVER -gt 0 ]; then
    # server just needs the maps, can omit the rest of the data
    log "Copy server data"
    rsync -av --delete --exclude .github --exclude .git --delete $BUILD/data/maps $SERVER_APPDIR/usr/bin/data/

    log "Copy server binary"
    cp $BUILD/bin/amd64/redeclipse_server_linux $SERVER_APPDIR/usr/bin/redeclipse-server

    log "Copy client desktop file"
    cp $OLD_CWD/redeclipse-server.desktop $SERVER_APPDIR/usr/share/applications
fi


log "Create $OLD_CWD/out"
[ ! -e $OLD_CWD/out ] && mkdir -p $OLD_CWD/out


for appdir in ${appdirs[@]}; do
    cd $appdir

    log "Run linuxdeployqt for $appdir"
    for i in `seq 1 2`; do
        linuxdeployqt usr/share/applications/*.desktop
    done

    log "Install AppRun script"
    rm $appdir/AppRun
    cp $OLD_CWD/AppRun $appdir/
    sed -i "s/_BRANCH_/$BRANCH/g" $appdir/AppRun
done

if [ $BUILD_SERVER -gt 0 ]; then
    log "Patch server AppRun script"
    sed -i 's|./redeclipse|./redeclipse-server|g' $SERVER_APPDIR/AppRun
fi


CLIENT_URL="zsync|https://download.assassinate-you.net/red-eclipse/appimage/latest/redeclipse-${BRANCH}-x86_64.AppImage.zsync"
SERVER_URL="zsync|https://download.assassinate-you.net/red-eclipse/appimage/latest/redeclipse-server-${BRANCH}-x86_64.AppImage.zsync"

glibc_needed()
{
  find . -name *.so -or -name *.so.* -or -type f -executable  -exec readelf -s '{}' 2>/dev/null \; | sed -n 's/.*@GLIBC_//p'| awk '{print $1}' | sort --version-sort | tail -n 1
}

export GLIBC_NEEDED="glibc$(glibc_needed)"

if [ $BUILD_CLIENT -gt 0 ]; then
    log "Create client AppImage"
    appimagetool -n -v -u "$CLIENT_URL" $CLIENT_APPDIR $OLD_CWD/out/redeclipse-$VERSION-$BRANCH-$COMMIT-$ARCH.$GLIBC_NEEDED.AppImage
fi

if [ $BUILD_SERVER -gt 0 ]; then
    log "Create server AppImage"
    appimagetool -n -v -u "$SERVER_URL" $SERVER_APPDIR $OLD_CWD/out/redeclipse-server-$VERSION-$BRANCH-$COMMIT-$ARCH.$GLIBC_NEEDED.AppImage
fi

log "fixing AppImages' permissions"
chown $SUDO_UID:$SUDO_GID $OLD_CWD/out/*.AppImage
