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

export BRANCH=${BRANCH:-stable}
export ARCH=${ARCH:-x86_64}
export REPO_URL=${REPO_URL:-https://github.com/redeclipse/base.git}
# parsed automatically unless they are already set
export VERSION
export COMMIT

export WORKSPACE=$(readlink -f workspace)
export APPDIR=$WORKSPACE/redeclipse.AppDir
export BUILD=$(readlink -f ${BUILD:-$WORKSPACE/build})

export BUILD_CLIENT=${BUILD_CLIENT:-1}
export BUILD_SERVER=${BUILD_SERVER:-0}

if [ $BUILD_CLIENT -le 0 ] && [ $BUILD_SERVER -le 0 ]; then
    echo "$(tput bold)$(tput setaf 1)**Error** you have to activate at least one build, either BUILD_CLIENT=1, BUILD_SERVER=1 or both!$(tput sgr0)"
    exit 1
fi


notset="(parsed later from source code)"
log "VERSION: ${VERSION:-$notset} -- BRANCH: $BRANCH"

log "Prepare environment"
mkdir -p $WORKSPACE $PREFIX $DOWNLOADS $BUILD

cd "$BUILD"

if [ -z "$NO_UPDATE" ]; then

    if [ ! -d .git ]; then
        log "Clone Red Eclipse repository"
        git clone https://github.com/redeclipse/base.git -n .
    else
        log "Update Red Eclipse repository"
        git reset --hard HEAD
        git pull
    fi

    log "Check out ${COMMIT:-$BRANCH}"
    git checkout ${COMMIT:-$BRANCH}
    log "Update Git submodules"
    git submodule update --init

else
    log "Using passed source"
fi

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
LCOMMIT=$(git rev-parse $COMMIT)

export COMMIT

log "Download and set up linuxdeployqt"

mkdir -p $WORKSPACE/linuxdeployqt
cd $WORKSPACE/linuxdeployqt
$OLD_CWD/linuxdeployqt.AppImage --appimage-extract

linuxdeployqt () {
    $WORKSPACE/linuxdeployqt/squashfs-root/AppRun $@ -bundle-non-qt-libs -verbose=1
}

log "Download and set up appimagetool"

mkdir -p $WORKSPACE/appimagetool
cd $WORKSPACE/appimagetool
$OLD_CWD/appimagetool.AppImage --appimage-extract

appimagetool () {
    $WORKSPACE/appimagetool/squashfs-root/AppRun --comp=xz $@
}

log "Build Red Eclipse binaries"
pushd $BUILD/src
make clean
make PLATFORM=linux64 PLATFORM_BIN=amd64 PLATFORM_BUILD=${PLATFORM_BUILD} PLATFORM_BRANCH=\"${PLATFORM_BRANCH}\" PLATFORM_REVISION=\"${PLATFORM_REVISION}\" CFLAGS=-m64 CXXFLAGS=-m64 LDFLAGS=-m64 -j$(nproc) install
popd

log "copying Red Eclipse data to AppDirs"

# create AppDir
mkdir -p $APPDIR

log "Copy CubeScript files to $APPDIR"
mkdir -p $APPDIR/usr/bin/config
rsync -av --delete --exclude .github --exclude .git --delete $BUILD/config $APPDIR/usr/bin/

log "Create FHS-like directory tree in $APPDIR"
mkdir -p $APPDIR/usr/{bin,lib,share}

log "Link data directory"
if [ -f /.dockerenv ]; then
    rsync -av --delete --exclude .github --exclude .git --link-dest=$(readlink -f $BUILD/data) $(readlink -f $BUILD/data) $(readlink -f $APPDIR/usr/bin/)
else
    # has to be a subdirectory of usr/bin/ so that the binary in that directory is able to find them
    # TODO: make Red Eclipse find the game data relative to the binary (e.g., ../share/games/redeclipse/data)
    rm -rf $APPDIR/usr/bin/data
    # Dirs
    rsync -av --include '*/' --exclude '*' --exclude .github --exclude .git $(readlink -f $BUILD/data) $(readlink -f $APPDIR/usr/bin/)
    # Files
    pushd $BUILD/data/
    find . -type f \( ! -regex '.*/\..*' \) -exec ln -v {} $(readlink -f $APPDIR/usr/bin/data)/{} \;
    popd
fi

log "Copy icons"
mkdir -p $APPDIR/usr/share/icons/hicolor/128x128/ $APPDIR/usr/share/applications/
cp $OLD_CWD/*.png $APPDIR/usr/share/icons/hicolor/128x128/

log "Copy binaries"
cp $BUILD/bin/amd64/redeclipse_linux $APPDIR/usr/bin/redeclipse || true
cp $BUILD/bin/amd64/redeclipse_server_linux $APPDIR/usr/bin/redeclipse-server || true
cp $OLD_CWD/*.AppImage $APPDIR/usr/bin/

log "Copy desktop files"
cp $OLD_CWD/redeclipse.desktop $OLD_CWD/redeclipse-server.desktop $APPDIR/usr/share/applications/

log "Copy metainfo files"
mkdir -p $APPDIR/usr/share/metainfo
cp $OLD_CWD/redeclipse.appdata.xml $APPDIR/usr/share/metainfo/

log "Create $OLD_CWD/out"
mkdir -p $OLD_CWD/out


CLIENT_URL="zsync|https://redeclipse.net/appimage/${BRANCH}/redeclipse-${BRANCH}-${ARCH}.AppImage.zsync"
SERVER_URL="zsync|https://redeclipse.net/appimage/${BRANCH}/redeclipse-server-${BRANCH}-${ARCH}.AppImage.zsync"

glibc_needed()
{
  find . -name *.so -or -name *.so.* -or -type f -executable  -exec readelf -s '{}' 2>/dev/null \; | sed -n 's/.*@GLIBC_//p'| awk '{print $1}' | sort --version-sort | tail -n 1
}

export GLIBC_NEEDED="glibc$(glibc_needed)"

cd $APPDIR

if [ $BUILD_CLIENT -gt 0 ]; then
    log "Build client AppImage"

    log "Run linuxdeployqt"
    for i in `seq 1 2`; do
        linuxdeployqt usr/share/applications/redeclipse.desktop
    done

    log "Install AppRun script"
    rm $APPDIR/AppRun
    cp $OLD_CWD/AppRun $APPDIR/
    sed -i "s/_BRANCH_/$BRANCH/g" $APPDIR/AppRun
    sed -i "s/_COMMIT_/$LCOMMIT/g" $APPDIR/AppRun

    log "Run appimagetool"
    appimagetool -n -v --exclude-file $OLD_CWD/redeclipse.ignore -u "$CLIENT_URL" $APPDIR $(readlink -f $OLD_CWD/out/redeclipse-$BRANCH-$ARCH.AppImage)
fi

if [ $BUILD_SERVER -gt 0 ]; then
    log "Build server AppImage"

    #find usr/lib/ -type f -iname '*.so' -delete
    log "Run linuxdeployqt"
    for i in `seq 1 2`; do
        linuxdeployqt usr/share/applications/redeclipse-server.desktop
    done

    log "Install AppRun script"
    rm $APPDIR/AppRun
    cp $OLD_CWD/AppRun $APPDIR/
    sed -i "s/_BRANCH_/$BRANCH/g" $APPDIR/AppRun
    sed -i "s/_COMMIT_/$LCOMMIT/g" $APPDIR/AppRun

    log "Patch server AppRun script"
    sed -i 's|SERVER=no|SERVER=yes|g' $APPDIR/AppRun

    log "Run appimagetool"
    appimagetool -n -v --exclude-file $OLD_CWD/redeclipse-server.ignore -u "$SERVER_URL" $APPDIR $(readlink -f $OLD_CWD/out/redeclipse-server-$BRANCH-$ARCH.AppImage)
fi

log "Fixing AppImages' permissions"
chmod 0755 $OLD_CWD/out/*.AppImage

log "Cleaning up"
rm -r $APPDIR/
