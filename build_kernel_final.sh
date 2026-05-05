#!/bin/bash

# Exit on error
set -e

# Define root workspace
WORKSPACE_ROOT=$(pwd)
KERNEL_DIR="kernel/msm-4.19"
OUT_DIR="out"

echo "=== 1. Setting up Toolchains and Environment ==="
export CLANG_PATH="${WORKSPACE_ROOT}/prebuilts/clang/bin"
export GCC_AARCH64_PATH="${WORKSPACE_ROOT}/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin"
export GCC_ARM_PATH="${WORKSPACE_ROOT}/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin"

# Prepend toolchains to PATH
export PATH="${CLANG_PATH}:${GCC_AARCH64_PATH}:${GCC_ARM_PATH}:${PATH}"

# Export cross-compilation variables
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export CROSS_COMPILE_ARM32=arm-linux-androideabi-
export CC=clang
export HOSTCC=gcc
export HOSTLD=ld

echo "=== 2. Applying Patches ==="
# Check if patch is already applied to avoid patching errors
if patch -p1 --dry-run --binary -F 3 < .repo/manifests/fix_op9r_build_errors.patch | grep -q "previously applied"; then
    echo "Patch already applied"
else
    patch -p1 --binary -F 3 < .repo/manifests/fix_op9r_build_errors.patch || true
fi

# Move into kernel source directory
cd ${KERNEL_DIR}

echo "=== 3. Fixing Makefiles and Configurations ==="
# Reset files before modifying to ensure a clean slate
git checkout HEAD -- oplus_native_features.mk OplusKernelEnvConfig.mk arch/arm64/configs/vendor/kona-perf_defconfig Makefile arch/arm64/boot/dts/vendor/19066/Makefile mm/vmscan.c

# Apply LTO configs 
sed -i 's/CONFIG_LTO=n/CONFIG_LTO=y/' "./arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_LTO_CLANG_FULL=y/CONFIG_LTO_CLANG_THIN=y/' "./arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_LTO_CLANG_NONE=y/CONFIG_LTO_CLANG_THIN=y/' "./arch/arm64/configs/vendor/kona-perf_defconfig"

# Comment out -Werror rules for implicit-int and strict-prototypes to avoid build failure on warnings
sed -i 's/KBUILD_CFLAGS   += $(call cc-option,-Werror=strict-prototypes)/# KBUILD_CFLAGS   += $(call cc-option,-Werror=strict-prototypes)/' Makefile
sed -i 's/KBUILD_CFLAGS   += $(call cc-option,-Werror=implicit-int)/# KBUILD_CFLAGS   += $(call cc-option,-Werror=implicit-int)/' Makefile

# Disable missing features/symbols in defconfig
sed -i 's/CONFIG_UFSFEATURE=y/# CONFIG_UFSFEATURE is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_DUMP_TASKS_MEM=y/# CONFIG_DUMP_TASKS_MEM is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_PROCESS_RECLAIM_ENHANCE=y/# CONFIG_PROCESS_RECLAIM_ENHANCE is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"
sed -i 's/CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' "arch/arm64/configs/vendor/kona-perf_defconfig"

# Disable missing OPLUS features by renaming their macro prefix
sed -i 's/OPLUS_FEATURE_ADFR/DISABLED_FEATURE_ADFR/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_MEMLEAK_DETECT/DISABLED_FEATURE_MEMLEAK_DETECT/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_PADL_STATISTICS/DISABLED_FEATURE_PADL_STATISTICS/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_PROCESS_RECLAIM/DISABLED_FEATURE_PROCESS_RECLAIM/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_UFSPLUS/DISABLED_FEATURE_UFSPLUS/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_UFS_SHOW_LATENCY/DISABLED_FEATURE_UFS_SHOW_LATENCY/g' oplus_native_features.mk OplusKernelEnvConfig.mk
sed -i 's/OPLUS_FEATURE_WIFI_ROUTERBOOST/DISABLED_FEATURE_WIFI_ROUTERBOOST/g' oplus_native_features.mk OplusKernelEnvConfig.mk

# Fix implicit declaration of proc_create missing from vmscan
if ! grep -q "linux/proc_fs.h" mm/vmscan.c; then
    sed -i '1i#include <linux/proc_fs.h>' mm/vmscan.c
fi

# Remove missing dtb target that doesn't exist in the tree
sed -i 's/kona-v2.1-iot-rb5.dtb//g' arch/arm64/boot/dts/vendor/19066/Makefile

echo "=== 4. Fixing Broken Device Tree (DTB) Symlinks ==="
cd arch/arm64/boot/dts/vendor/qcom
rm -f display camera
ln -s ${WORKSPACE_ROOT}/vendor/qcom/proprietary/display-devicetree/display display
ln -s ${WORKSPACE_ROOT}/vendor/qcom/proprietary/camera-devicetree camera
cd - > /dev/null

echo "=== 5. Compiling Kernel ==="
mkdir -p ${OUT_DIR}

# Generate the config
make O=${OUT_DIR} ARCH=arm64 CC=clang HOSTCC=gcc HOSTLD=ld vendor/kona-perf_defconfig

# Compile the kernel
make -j$(nproc) O=${OUT_DIR} ARCH=arm64 CC=clang HOSTCC=gcc HOSTLD=ld

echo "Build Completed Successfully! Output in ${KERNEL_DIR}/${OUT_DIR}"