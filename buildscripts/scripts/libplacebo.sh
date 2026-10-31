#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix
vulkan=${LIBPLACEBO_VULKAN:-enabled}

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf $build
	exit 0
else
	exit 255
fi

unset CC CXX
# Vulkan 后端必须同时启用 shaderc，否则 libplacebo 没有 SPIR-V 编译器，
# mpv 会在初始化 Vulkan device 时直接失败（表现为 HDR 视频纯黑屏）。
meson setup $build --cross-file "$prefix_dir"/crossfile.txt \
	-Dvulkan=$vulkan -Dshaderc=enabled -Ddemos=false

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install

# add missing libraries for static linking
# shaderc 是 libplacebo 的私有依赖，静态链接进 libmpv 时需要显式补上；
# 这里不是 "-lstdc++" 而是 "-lc++" 是 meson 的已知问题：
# https://github.com/mesonbuild/meson/issues/11300
${SED:-sed} '/^Libs:/ s|$| -lshaderc_combined -lc++|' "$prefix_dir/lib/pkgconfig/libplacebo.pc" -i
