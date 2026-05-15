#!/bin/bash
set -euxo pipefail

NDK_VERSION="r28"
GLIBC_VERSION="2.40"
SYSROOT_DIR="$(pwd)/sysroot"
OUTPUT_DIR="$(pwd)/output"

# --- 下载 Android NDK ---
if [ ! -d "android-ndk-${NDK_VERSION}" ]; then
    wget -q "https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip"
    unzip -q "android-ndk-${NDK_VERSION}-linux.zip"
    rm "android-ndk-${NDK_VERSION}-linux.zip"
fi
NDK="$(pwd)/android-ndk-${NDK_VERSION}"
TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"

# --- 下载 glibc 源码 ---
if [ ! -d "glibc-${GLIBC_VERSION}" ]; then
    wget -q "https://ftp.gnu.org/gnu/glibc/glibc-${GLIBC_VERSION}.tar.gz"
    tar xf "glibc-${GLIBC_VERSION}.tar.gz"
    rm "glibc-${GLIBC_VERSION}.tar.gz"
fi

# --- 安装 Linux 内核头文件（glibc 编译需要）---
if [ ! -d "linux" ]; then
    git clone --depth=1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
fi
mkdir -p "${SYSROOT_DIR}/usr"
make -C linux ARCH=arm64 INSTALL_HDR_PATH="${SYSROOT_DIR}/usr" headers_install

# --- 查找 compiler-rt builtins（提供 __multi3、__floatundidf 等运行时函数）---
# Clang 没有 libgcc，这些低层函数由 compiler-rt 提供
BUILTINS=$(find "${TOOLCHAIN}/lib/clang" -name "libclang_rt.builtins-aarch64-android.a" | head -1)
if [ -z "${BUILTINS}" ]; then
    echo "ERROR: compiler-rt builtins not found in NDK"
    exit 1
fi
echo "Found compiler-rt builtins: ${BUILTINS}"

# --- 设置交叉编译器 ---
# NDK Clang 默认 target 是 Android，我们用 -target 改为 aarch64-linux-gnu
# -rtlib=compiler-rt 告诉 Clang 链接 compiler-rt 而非 libgcc
CC="${TOOLCHAIN}/bin/clang -target aarch64-linux-gnu --sysroot=${SYSROOT_DIR} -rtlib=compiler-rt"
CXX="${TOOLCHAIN}/bin/clang++ -target aarch64-linux-gnu --sysroot=${SYSROOT_DIR} -rtlib=compiler-rt"

export CC CXX
export AR="${TOOLCHAIN}/bin/llvm-ar"
export LD="${TOOLCHAIN}/bin/ld.lld"
export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
export STRIP="${TOOLCHAIN}/bin/llvm-strip"
export NM="${TOOLCHAIN}/bin/llvm-nm"
export OBJCOPY="${TOOLCHAIN}/bin/llvm-objcopy"
export OBJDUMP="${TOOLCHAIN}/bin/llvm-objdump"
export READELF="${TOOLCHAIN}/bin/llvm-readelf"

# --- 配置 glibc ---
mkdir -p "glibc-${GLIBC_VERSION}/build"
cd "glibc-${GLIBC_VERSION}/build"

# glibc 的 configure 需要 ld 能处理 --sysroot，用 ld.lld
# 注意: musl 模式下可能需要禁用一些 glibc 特有的功能
../configure \
    --host=aarch64-linux-gnu \
    --build=x86_64-linux-gnu \
    --target=aarch64-linux-gnu \
    --prefix=/usr \
    --disable-werror \
    --enable-kernel=5.4 \
    --with-headers="${SYSROOT_DIR}/usr/include" \
    CC="${CC}" \
    CXX="${CXX}" \
    AR="${AR}" \
    LD="${LD}"

# --- 编译 ---
make -j$(nproc)

# --- 安装到输出目录 ---
make DESTDIR="${OUTPUT_DIR}" install

# --- 打包 ---
cd "${OUTPUT_DIR}"
tar czf "${OUTPUT_DIR}/../glibc-${GLIBC_VERSION}-aarch64-ndk.tar.gz" .

echo "=== Build complete ==="
echo "Output: glibc-${GLIBC_VERSION}-aarch64-ndk.tar.gz"
