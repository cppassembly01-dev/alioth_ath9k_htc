#!/bin/bash

# Exit on error
set -e

# Setup Toolchain PATHs
export CLANG_PATH="/home/akronnos/op8250/prebuilts/clang/bin"
export GCC_AARCH64_PATH="/home/akronnos/op8250/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin"
export GCC_ARM_PATH="/home/akronnos/op8250/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin"

export PATH="$CLANG_PATH:$GCC_AARCH64_PATH:$GCC_ARM_PATH:$PATH"

# Set compiler environments
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export CC=clang
export HOSTCC=gcc
export HOSTLD=ld

# Check if patch is already applied
if patch -p1 --dry-run --binary -F 3 < .repo/manifests/fix_op9r_build_errors.patch | grep -q "previously applied"; then
    echo "Patch already applied"
else
    patch -p1 --binary -F 3 < .repo/manifests/fix_op9r_build_errors.patch || true
fi

cd kernel/msm-4.19

# Reset files before modifying
git checkout HEAD -- oplus_native_features.mk OplusKernelEnvConfig.mk arch/arm64/configs/vendor/kona-perf_defconfig Makefile

# Apply the same sed commands from the workflow
sed -i 's/CONFIG_LTO=n/CONFIG_LTO=y/' "./arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_LTO_CLANG_FULL=y/CONFIG_LTO_CLANG_THIN=y/' "./arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_LTO_CLANG_NONE=y/CONFIG_LTO_CLANG_THIN=y/' "./arch/arm64/configs/vendor/kona-perf_defconfig"

# Fix warnings as errors in Makefile
sed -i 's/KBUILD_CFLAGS   += $(call cc-option,-Werror=strict-prototypes)/# KBUILD_CFLAGS   += $(call cc-option,-Werror=strict-prototypes)/' Makefile
sed -i 's/KBUILD_CFLAGS   += $(call cc-option,-Werror=implicit-int)/# KBUILD_CFLAGS   += $(call cc-option,-Werror=implicit-int)/' Makefile

# Disable features that have missing symbols
sed -i 's/CONFIG_UFSFEATURE=y/# CONFIG_UFSFEATURE is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_DUMP_TASKS_MEM=y/# CONFIG_DUMP_TASKS_MEM is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_PROCESS_RECLAIM_ENHANCE=y/# CONFIG_PROCESS_RECLAIM_ENHANCE is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"

# Disable OPLUS features
sed -i 's/OPLUS_FEATURE_ADFR/DISABLED_FEATURE_ADFR/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_MEMLEAK_DETECT/DISABLED_FEATURE_MEMLEAK_DETECT/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_PADL_STATISTICS/DISABLED_FEATURE_PADL_STATISTICS/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_PROCESS_RECLAIM/DISABLED_FEATURE_PROCESS_RECLAIM/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_UFSPLUS/DISABLED_FEATURE_UFSPLUS/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_UFS_SHOW_LATENCY/DISABLED_FEATURE_UFS_SHOW_LATENCY/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_WIFI_ROUTERBOOST/DISABLED_FEATURE_WIFI_ROUTERBOOST/g' oplus_native_features.mk OplusKernelEnvConfig.mk

# Make out dir
mkdir -p out

# Generate config
make O=out ARCH=arm64 CC=clang HOSTCC=gcc HOSTLD=ld vendor/kona-perf_defconfig

# Compile
make -j$(nproc) O=out ARCH=arm64 CC=clang HOSTCC=gcc HOSTLD=ld

echo "Build Completed Successfully!"