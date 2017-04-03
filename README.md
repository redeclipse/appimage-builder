# Red Eclipse AppImage builder

This project contains files and scripts that allow the easy, reproducible and
incremental generation of AppImages for the
[Red Eclipse](http://redeclipse.net) project.


## Build with Docker (recommended way)

Software required to use this approach is the Docker container engine. See
https://docs.docker.com/engine/installation/linux/ for more information how to
install Docker.

All you have to do is running the following command:

    bash build-with-docker.sh

The AppImage is built securely in a fresh Docker container. After the script
successfully ran, the AppImage is going to reside in a directory called `out/`
in the repository's root directory.

You can then distribute the AppImage.

Beware that you should NOT put the AppImage in any further archives. Read the
AppImage documentation for more information.

Note that the script is building a Docker container to save time on future
builds. This image is tagged `redeclipse-appimage-build`. You can remove this
image if you want to, it will just be rebuilt. If you want to build a newer
version, you can also just remove it from your host.


## Build without Docker

It is also possible to build AppImages without Docker with this project.

To do this, you need to install the build dependencies on your local system.

On Debian/Ubuntu, just run the following command to install these dependencies:

    sudo apt-get install -y libarchive13 wget desktop-file-utils aria2 gnupg2 \
        build-essential file autogen ca-certificates cmake gcc g++ git make \
        pkg-config subversion wget xz-utils rsync desktop-file-utils cmake \
        ninja-build libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev

Then you just have to run this command to build the AppImage:

    bash build-appimage.sh

Note that `build-appimage.sh` is only tested in containers. It should not
modify any essential system files, but you might want to read it before
executing it outside a Docker container.


## Configure AppImage build

By setting some special environment variables, the AppImage build script can be
influenced in some way.

| variable | default                                 | explanation |
| -------- | --------------------------------------- | ----------- |
|`BRANCH`  | `stable`                                | Git branch to be built. Can be set to e.g. `master` for development builds. |
|`ARCH`    | `x86_64`                                | Architecture to be built. Only `x86_64` builds are implemented at the moment. You should **not** change this. |
|`REPO_URL`| https://github.com/red-eclipse/base.git | Repository URL. If you want to build an AppImage for your own fork, you can change this to another git repository's URL. |
|`VERSION` | (parsed from source code)               | Red Eclipse version. There is actually no use case of overriding this variable, the correct value is parsed from `version.h`. |
|`COMMIT`  | (read from local Git clone)             | Commit ID to check out. Continuous integration builds should override this to make sure the correct version is fetched from GitHub. If not set, it is fetched using `git rev-parse HEAD`. |

Beware: you **must set `BRANCH` if you set `COMMIT`**, as the commit could be
part of multiple branches and thus it would be really, really hard to
automatically determine the right branch name. So make sure you always set
`BRANCH` whenever you set `COMMIT`.
