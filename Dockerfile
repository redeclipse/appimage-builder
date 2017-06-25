FROM ubuntu:xenial

MAINTAINER "TheAssassin <theassassin@users.noreply.github.com>"

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/archive.ubuntu.com/ftp.fau.de/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y libarchive13 wget desktop-file-utils aria2 gnupg2 \
        build-essential file autogen ca-certificates cmake gcc g++ git make \
        pkg-config subversion wget xz-utils rsync desktop-file-utils cmake \
        ninja-build libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev \
        libasound2 libsdl2-2.0-0 libsdl2-image-2.0-0 \
        libsdl2-mixer-2.0-0 zlib1g libjpeg62 libpng12-0  libflac8 libogg0 \
        libvorbis0a libpciaccess0 libdrm2 libxcb-dri2-0 libxcb-dri3-0 \
        libxcb-present0 libxcb1 libxau6 libxext6 libx11-6 libx11-xcb1 \
        libxfixes3 libxcb-xfixes0 libxdamage1 libexpat1 libegl1-mesa \
        libgl1-mesa-dri libgl1-mesa-glx libglapi-mesa libgles2-mesa libglu1-mesa \
        libtinfo5

RUN addgroup --gid 1000 builder && \
    adduser --uid 1000 --gid 1000 --disabled-login --disabled-password \
    --gecos "" builder && \
    install -d -o 1000 -g 1000 /workspace /out

COPY AppRun /AppRun
COPY redeclipse.desktop /redeclipse.desktop
COPY redeclipse-server.desktop /redeclipse-server.desktop
COPY redeclipse.png /redeclipse.png
COPY build-appimages.sh /build-appimages.sh
COPY *.ignore /

USER 1000
