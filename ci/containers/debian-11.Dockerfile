# THIS FILE WAS AUTO-GENERATED
#
#  $ lcitool manifest ci/manifest.yml
#
# https://gitlab.com/libvirt/libvirt-ci

FROM docker.io/library/debian:11-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y eatmydata && \
    eatmydata apt-get dist-upgrade -y && \
    eatmydata apt-get install --no-install-recommends -y \
            autoconf \
            automake \
            bash \
            bash-completion \
            bsdextrautils \
            ca-certificates \
            cargo \
            ccache \
            clang \
            e2fsprogs \
            expect \
            fdisk \
            flake8 \
            g++ \
            gcc \
            genisoimage \
            git \
            golang \
            gzip \
            iproute2 \
            jq \
            libc-bin \
            libc6-dev \
            libcurl4-gnutls-dev \
            libgnutls28-dev \
            libguestfs-dev \
            liblzma-dev \
            libnbd-dev \
            libperl-dev \
            libselinux1-dev \
            libssh-gcrypt-dev \
            libtool-bin \
            libtorrent-dev \
            libvirt-dev \
            libzstd-dev \
            linux-libc-dev \
            locales \
            lua5.4 \
            make \
            mount \
            ocaml \
            openssh-client \
            perl \
            perl-base \
            podman \
            python3 \
            python3-boto3 \
            python3-dev \
            python3-libnbd \
            qemu-utils \
            rustc \
            socat \
            tcl-dev \
            xz-utils \
            zlib1g-dev && \
    eatmydata apt-get autoremove -y && \
    eatmydata apt-get autoclean -y && \
    sed -Ei 's,^# (en_US\.UTF-8 .*)$,\1,' /etc/locale.gen && \
    dpkg-reconfigure locales && \
    dpkg-query --showformat '${Package}_${Version}_${Architecture}\n' --show > /packages.txt && \
    mkdir -p /usr/libexec/ccache-wrappers && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/c++ && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/cc && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/clang && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/g++ && \
    ln -s /usr/bin/ccache /usr/libexec/ccache-wrappers/gcc

ENV LANG "en_US.UTF-8"
ENV MAKE "/usr/bin/make"
ENV PYTHON "/usr/bin/python3"
ENV CCACHE_WRAPPERSDIR "/usr/libexec/ccache-wrappers"
