FROM ubuntu:xenial

MAINTAINER "TheAssassin <theassassin@users.noreply.github.com>"

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/archive.ubuntu.com/ftp.fau.de/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y libarchive13 wget desktop-file-utils aria2 gnupg2 \
        build-essential file autogen ca-certificates cmake gcc g++ git make \
        pkg-config subversion wget xz-utils rsync desktop-file-utils cmake \
        ninja-build libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev

RUN addgroup --gid 1000 builder && \
    adduser --uid 1000 --gid 1000 --disabled-login --disabled-password \
    --gecos "" builder && \
    install -d -o 1000 -g 1000 /workspace /out

ADD redeclipse /redeclipse
ADD redeclipse.desktop /redeclipse.desktop
ADD redeclipse.png /redeclipse.png
ADD build-appimage.sh /build-appimage.sh

USER 1000
