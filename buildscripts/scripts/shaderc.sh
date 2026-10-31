#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf local include libs
	exit 0
else
	exit 255
fi

builddir=$PWD

abi=armeabi-v7a
[[ "$ndk_triple" == "aarch64"* ]] && abi=arm64-v8a
[[ "$ndk_triple" == "x86_64"* ]] && abi=x86_64
[[ "$ndk_triple" == "i686"* ]] && abi=x86

# build using the NDK's scripts, but keep object files in our build dir
cd "$(dirname "$(which ndk-build)")/sources/third_party/shaderc"
ndk-build -j$cores \
	NDK_PROJECT_PATH=. APP_BUILD_SCRIPT=Android.mk \
	APP_PLATFORM=android-26 APP_STL=c++_shared APP_ABI=$abi \
	NDK_APP_OUT="$builddir" NDK_APP_LIBS_OUT="$builddir/libs" \
	libshaderc_combined

cd "$builddir"
# NDK 的 shaderc 构建会把头文件生成到 NDK_APP_LIBS_OUT/../include，
# 即 $builddir/include，而不是源码树里的 include/。
mkdir -p "$prefix_dir/include"
cp -r "$builddir/include"/* "$prefix_dir/include"
cp libs/*/$abi/libshaderc.a "$prefix_dir/lib/libshaderc_combined.a"

# create a pkgconfig file
# libplacebo 的 meson 用 dependency('shaderc') 查找的是 shaderc.pc，
# 但 NDK 合并出来的静态库名是 libshaderc_combined.a，所以 Libs 仍写后者。
mkdir -p "$prefix_dir"/lib/pkgconfig
cat >"$prefix_dir"/lib/pkgconfig/shaderc.pc <<"END"
prefix=/usr/local
exec_prefix=${prefix}
libdir=${prefix}/lib
includedir=${prefix}/include

Name: shaderc
Description: Combined shaderc static library from the Android NDK
Version: 2022.3
Libs: -L${libdir} -lshaderc_combined
Cflags: -I${includedir}
END