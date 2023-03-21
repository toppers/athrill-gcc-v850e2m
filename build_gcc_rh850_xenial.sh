# exit if command failed.
set -o errexit
# exit if pipe failed.
set -o pipefail
# exit if variable not set.
set -o nounset

# sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

sudo apt update -y
sudo apt install build-essential mingw-w64 wget texinfo bison zip -y

BINUTILS_VERSION="2.24"
GCC_VERSION="4.9.2"
NEWLIB_VERSION="2.1.0"
GDB_VERSION="7.8.1"
RENESAS_VERSION="v850_v14.01"

BUILD="x86_64-linux-gnu"
LINUX_HOST="x86_64-linux-gnu"
WINDOWS_HOST="x86_64-w64-mingw32"
DARWIN_HOST="x86_64-apple-darwin"

TARGET="v850-elf"

CURRENT_PATH=$(cd $(dirname $0);pwd)
BASE_PATH="${CURRENT_PATH}/work"

PATCH_PATH=$(dirname $(readlink -f "$0"))/patch
SOURCE_PATH="${BASE_PATH}/source"
BUILD_LINUX_PATH="${BASE_PATH}/build/linux"
BUILD_WINDOWS_PATH="${BASE_PATH}/build/win32"
BUILD_DARWIN_PATH="${BASE_PATH}/build/darwin"
INSTALL_LINUX_PATH="${BASE_PATH}/install/v850-elf-gcc-linux-x64"
INSTALL_WINDOWS_PATH="${BASE_PATH}/install/v850-elf-gcc-win32-x64"
INSTALL_DARWIN_PATH="${BASE_PATH}/install/v850-elf-gcc-darwin-x64"
STAGE_PATH="${BASE_PATH}/stage"
PATH=$PATH:${INSTALL_LINUX_PATH}/bin

mkdir -p ${SOURCE_PATH}
mkdir -p ${BUILD_LINUX_PATH}
mkdir -p ${BUILD_WINDOWS_PATH}
mkdir -p ${INSTALL_LINUX_PATH}
mkdir -p ${INSTALL_WINDOWS_PATH}
mkdir -p ${STAGE_PATH}

# download tarballs
if [ ! -e ${STAGE_PATH}/download_binutils ]
then
    wget -c -O ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}.tar.bz2 https://llvm-gcc-renesas.com/downloads/d.php?f=v850/binutils/14.01/binutils-${BINUTILS_VERSION}_${RENESAS_VERSION}.tar.bz2
    touch ${STAGE_PATH}/download_binutils
fi

if [ ! -e ${STAGE_PATH}/download_gcc ]
then
    wget -c -O ${SOURCE_PATH}/gcc-${GCC_VERSION}.tar.bz2 https://llvm-gcc-renesas.com/downloads/d.php?f=v850/gcc/14.01/gcc-${GCC_VERSION}_${RENESAS_VERSION}.tar.bz2
    touch ${STAGE_PATH}/download_gcc
fi

if [ ! -e ${STAGE_PATH}/download_newlib ]
then
    wget -c -O ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}.tar.bz2 https://llvm-gcc-renesas.com/downloads/d.php?f=v850/newlib/14.01/newlib-${NEWLIB_VERSION}_${RENESAS_VERSION}.tar.bz2
    touch ${STAGE_PATH}/download_newlib
fi

if [ ! -e ${STAGE_PATH}/download_gdb ]
then
    wget -c -O ${SOURCE_PATH}/gdb-${GDB_VERSION}.tar.bz2 https://llvm-gcc-renesas.com/downloads/d.php?f=v850/gdb/14.01/gdb-${GDB_VERSION}_${RENESAS_VERSION}.tar.bz2
    touch ${STAGE_PATH}/download_gdb
fi

# extract tarballs
if [ ! -e ${STAGE_PATH}/extract_binutils ]
then
    echo "extract_binutils"
    tar -jxf ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}.tar.bz2 -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_binutils
fi

if [ ! -e ${STAGE_PATH}/extract_gcc ]
then
    echo "extract_gcc"
    tar -jxf ${SOURCE_PATH}/gcc-${GCC_VERSION}.tar.bz2 -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_gcc
fi

if [ ! -e ${STAGE_PATH}/extract_newlib ]
then
    echo "extract_newlib"
    tar -jxf ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}.tar.bz2 -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_newlib
fi

if [ ! -e ${STAGE_PATH}/extract_gdb ]
then
    echo "extract_gdb"
    tar -jxf ${SOURCE_PATH}/gdb-${GDB_VERSION}.tar.bz2 -C ${SOURCE_PATH}
    touch ${STAGE_PATH}/extract_gdb
fi

# download gcc prerequisites
cd ${SOURCE_PATH}/gcc-${GCC_VERSION}
./contrib/download_prerequisites

# # do patches
# if [ ! -e ${STAGE_PATH}/do_patch ]
# then
#     cd ${SOURCE_PATH}
#     patch -p0 -i ${PATCH_PATH}/gcc.patch
#     patch -p0 -i ${PATCH_PATH}/newlib.patch
#     touch ${STAGE_PATH}/do_patch
# fi

# build linux toolchain
if [ ! -e ${STAGE_PATH}/build_linux_binutils ]
then
    mkdir -p ${BUILD_LINUX_PATH}/binutils
    cd ${BUILD_LINUX_PATH}/binutils

    ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --enable-soft-float \
        --disable-nls \
        --disable-werror

    make
    make install-strip

    touch ${STAGE_PATH}/build_linux_binutils
fi

if [ ! -e ${STAGE_PATH}/build_linux_gcc_1st ]
then
    mkdir -p ${BUILD_LINUX_PATH}/gcc_1st
    cd ${BUILD_LINUX_PATH}/gcc_1st

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --enable-languages=c \
        --without-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-nls

    make all-gcc
    make install-strip-gcc

    touch ${STAGE_PATH}/build_linux_gcc_1st
fi

if [ ! -e ${STAGE_PATH}/build_linux_newlib ]
then
    mkdir -p ${BUILD_LINUX_PATH}/newlib
    cd ${BUILD_LINUX_PATH}/newlib

    ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --disable-nls

    # do not use GP based addressing

    #if defined(__v850) && !defined(__rtems__)
    #define __ATTRIBUTE_IMPURE_PTR__ __attribute__((__sda__))
    #endif

    # make CFLAGS_FOR_TARGET="-gdwarf-2 -fdata-sections -ffunction-sections -g -Os -D__rtems__"
    make CFLAGS_FOR_TARGET="-mv850e2v3 -mhard-float"
    make install

    touch ${STAGE_PATH}/build_linux_newlib
fi

if [ ! -e ${STAGE_PATH}/build_linux_gcc_2nd ]
then
    mkdir -p ${BUILD_LINUX_PATH}/gcc_2nd
    cd ${BUILD_LINUX_PATH}/gcc_2nd

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${LINUX_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_LINUX_PATH} \
        --enable-languages=c,c++ \
        --with-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-multilib \
        --disable-nls

    make
    make install-strip

    touch ${STAGE_PATH}/build_linux_gcc_2nd
fi

# # build win32 toolchain
if [ ! -e ${STAGE_PATH}/build_win32_binutils ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/binutils
    cd ${BUILD_WINDOWS_PATH}/binutils

    ${SOURCE_PATH}/binutils-${BINUTILS_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-soft-float \
        --disable-nls \
        --disable-werror


    make
    make install-strip

    touch ${STAGE_PATH}/build_win32_binutils
fi

if [ ! -e ${STAGE_PATH}/build_win32_gcc_1st ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/gcc_1st
    cd ${BUILD_WINDOWS_PATH}/gcc_1st

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-languages=c \
        --without-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-nls

    make all-gcc
    make install-strip-gcc

    touch ${STAGE_PATH}/build_win32_gcc_1st
fi

if [ ! -e ${STAGE_PATH}/build_win32_newlib ]
then
    mkdir -p ${BUILD_WINDOWS_PATH}/newlib
    cd ${BUILD_WINDOWS_PATH}/newlib

    ${SOURCE_PATH}/newlib-${NEWLIB_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-newlib-nano-malloc \
        --enable-newlib-nano-formatted-io \
        --enable-newlib-reent-small \
        --disable-nls

#     # do not use GP based addressing

#     #if defined(__v850) && !defined(__rtems__)
#     #define __ATTRIBUTE_IMPURE_PTR__ __attribute__((__sda__))
#     #endif

    # make CFLAGS_FOR_TARGET="-gdwarf-2 -fdata-sections -ffunction-sections -g -Os -D__rtems__"
    make CFLAGS_FOR_TARGET="-mv850e2v3 -mhard-float"
    make install

    touch ${STAGE_PATH}/build_win32_newlib
fi

if [ ! -e ${STAGE_PATH}/build_win32_gcc_2nd ]
then
    cd ${SOURCE_PATH}
    patch -p0 -i ${PATCH_PATH}/gcc.patch
    touch ${STAGE_PATH}/do_patch

    mkdir -p ${BUILD_WINDOWS_PATH}/gcc_2nd
    cd ${BUILD_WINDOWS_PATH}/gcc_2nd

    ${SOURCE_PATH}/gcc-${GCC_VERSION}/configure \
        --build=${BUILD} \
        --host=${WINDOWS_HOST} \
        --target=${TARGET} \
        --prefix=${INSTALL_WINDOWS_PATH} \
        --enable-languages=c,c++ \
        --with-headers \
        --with-newlib  \
        --with-gnu-as \
        --with-gnu-ld \
        --disable-threads \
        --disable-libssp \
        --disable-shared \
        --disable-multilib \
        --disable-nls

    make
    make install-strip

    touch ${STAGE_PATH}/build_win32_gcc_2nd
fi


# # zip toolchain
cd ${BASE_PATH}/install
zip -r v850-elf-gcc-linux-x64.zip v850-elf-gcc-linux-x64
zip -r v850-elf-gcc-win32-x64.zip v850-elf-gcc-win32-x64
