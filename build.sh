#!/bin/bash

sudo apt update
sudo apt upgrade
sudo apt-get install git-core gnupg flex bison build-essential zip curl zlib1g-dev libc6-dev-i386 x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig
wget https://dl.google.com/android/repository/android-ndk-r28c-linux.zip
unzip android-ndk-r28c-linux.zip
cd android_kernel_xiaomi_sm8250
kernel=$(pwd)
make O=out ARCH=arm64 SUBARCH=arm64 CC=kernel/../android-ndk-r28c/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android35-clang CROSS_COMPILE=kernel/../android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9/bin/aarch64-linux-android- CROSS_COMPILE_ARM32=kernel/../android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9/bin/arm-linux-androideabi- olddefconfig

