# Copyright 2021-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake flag-o-matic xdg optfeature

ASMJIT_COMMIT="416f7356967c1f66784dc1580fe157f9406d8bff" # master~71
GLSLANG_COMMIT="f0bd0257c308b9a26562c1a30c4748a0219cc951" # tags/16.2.0
WOLFSSL_COMMIT="1d363f3adceba9d1478230ede476a37b0dcdef24" # tags/5.9.1-stable
SOUNDTOUCH_COMMIT="a0fba77b6f9cfbdb71f8bbec58b6ac4e5e3b1097" # master
YAMLCPP_COMMIT="51a5d623e3fde1f58829a56ba910f1cb33596222" # master
FUSION_COMMIT="008e03eac0ac1d5f85e16f5fcaefdda3fee75cb8" # tags/1.2.11
VULKANMEMORYALLOCATOR_COMMIT="1d8f600fd424278486eade7ed3e877c99f0846b1" # tags/3.3.0
GAMEMODE_COMMIT="c54d6d4243b0dd0afcb49f2c9836d432da171a2b" # tags/1.8.2
DISCORD_COMMIT="3dc2c326cb4dc5815c6069970c13154898f58d48" # Vestrel/discord-rpc fork; fixes clang-format/rapidjson build errors in upstream discord/discord-rpc

DESCRIPTION="PS3 emulator/debugger"
HOMEPAGE="https://rpcs3.net/"
if [[ ${PV} == "9999" ]]; then
	EGIT_REPO_URI="https://github.com/RPCS3/rpcs3"
	# NOTE: submodules are NOT listed statically here. RPCS3 adds/removes/forks
	# bundled 3rdparty submodules fairly often (e.g. discord-rpc silently moved
	# from discord/discord-rpc to Vestrel/discord-rpc upstream), and a hand-
	# maintained allowlist here has previously gone stale and broken the build
	# for any component missing from the list. Instead, src_unpack() below
	# discovers submodules directly from RPCS3's own .gitmodules at build time
	# and only excludes the ones we deliberately want system-provided (see
	# SYSTEM_PROVIDED_SUBMODULES in src_unpack). This mirrors the approach
	# used by the rpcs3-git AUR package.
	inherit git-r3
else
	SRC_URI="
		https://github.com/RPCS3/rpcs3/archive/v${PV}.tar.gz -> ${P}.tar.gz
		https://github.com/asmjit/asmjit/archive/${ASMJIT_COMMIT}.tar.gz -> ${PN}-asmjit-${ASMJIT_COMMIT}.tar.gz
		https://github.com/KhronosGroup/glslang/archive/${GLSLANG_COMMIT}.tar.gz -> ${PN}-glslang-${GLSLANG_COMMIT}.tar.gz
		https://github.com/wolfSSL/wolfssl/archive/${WOLFSSL_COMMIT}.tar.gz -> ${PN}-wolfssl-${WOLFSSL_COMMIT}.tar.gz
		https://github.com/RPCS3/soundtouch/archive/${SOUNDTOUCH_COMMIT}.tar.gz
			-> ${PN}-soundtouch-${SOUNDTOUCH_COMMIT}.tar.gz
		https://github.com/RPCS3/yaml-cpp/archive/${YAMLCPP_COMMIT}.tar.gz -> ${PN}-yaml-cpp-${YAMLCPP_COMMIT}-.tar.gz
		https://github.com/xioTechnologies/Fusion/archive/${FUSION_COMMIT}.tar.gz -> ${PN}-fusion-${FUSION_COMMIT}.tar.gz
		https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/${VULKANMEMORYALLOCATOR_COMMIT}.tar.gz
			-> ${PN}-VulkanMemoryAllocator-${VULKANMEMORYALLOCATOR_COMMIT}.tar.gz
		https://github.com/FeralInteractive/gamemode/archive/${GAMEMODE_COMMIT}.tar.gz -> ${PN}-GameMode.tar.gz
		https://github.com/Vestrel/discord-rpc/archive/${DISCORD_COMMIT}.tar.gz -> ${PN}-Discord.tar.gz
	"
	KEYWORDS="~amd64"
fi

LICENSE="GPL-2"
SLOT="0"
IUSE="discord faudio +llvm opencv vulkan X wayland"

DEPEND="
	app-arch/7zip
	app-arch/zstd
	>=dev-libs/protobuf-33.0.0
	dev-libs/hidapi
	dev-libs/libevdev
	dev-libs/pugixml
	dev-libs/stb
	dev-qt/qtbase:6[concurrent,dbus,gui,widgets]
	dev-qt/qtmultimedia:6
	dev-qt/qtsvg:6
	media-libs/alsa-lib
	media-libs/cubeb
	media-libs/glew
	media-libs/libglvnd
	media-libs/libpng:=
	media-libs/openal
	media-libs/rtmidi
	media-libs/libsdl3[opengl,vulkan?,X?,wayland?]
	media-video/ffmpeg:=
	net-libs/miniupnpc:=
	net-misc/curl
	llvm-core/llvm:=
	virtual/zlib:=
	virtual/libusb:1
	x11-libs/libX11
	faudio? ( app-emulation/faudio )
	opencv? ( media-libs/opencv )
	vulkan? ( media-libs/vulkan-loader[wayland?] )
	wayland? ( dev-libs/wayland )
"
RDEPEND="${DEPEND}"

QA_PREBUILT="usr/share/rpcs3/test/.*"
QA_WX_LOAD="usr/share/rpcs3/test/*"

PATCHES=(
	"${FILESDIR}/${PN}-system-stb.patch"
)

src_unpack() {
	if [[ ${PV} == "9999" ]]; then
		git-r3_src_unpack

		# Dynamically discover and fetch RPCS3's bundled 3rdparty submodules
		# instead of hand-maintaining a static EGIT_SUBMODULES allowlist.
		# Submodules we want the SYSTEM version of instead (see DEPEND and
		# src_configure USE_SYSTEM_* flags) are excluded by path/name match.
		cd "${S}" || die

		local SYSTEM_PROVIDED_SUBMODULES=(
			libpng zlib curl llvm pugixml SDL cubeb ffmpeg hidapi
			libusb miniupnp opencv protobuf rtmidi stblib zstd
			7zip FAudio openal-soft
		)

		local submodule_paths
		submodule_paths=$(git config --file .gitmodules --get-regexp path | awk '{print $2}') \
			|| die "Could not read .gitmodules"

		local path skip name
		for path in ${submodule_paths}; do
			skip=0
			for name in "${SYSTEM_PROVIDED_SUBMODULES[@]}"; do
				[[ ${path} == *"${name}"* ]] && skip=1 && break
			done
			[[ ${skip} == 1 ]] && continue

			einfo "Initializing submodule: ${path}"
			git submodule init "${path}" || die "Could not init submodule ${path}"

			# Rewrite relative submodule URLs to absolute GitHub URLs the same
			# way rpcs3-git (AUR) does, in case .gitmodules uses relative paths
			local urlid="submodule.${path}.url"
			local url
			url=$(git config "${urlid}") || continue
			if [[ ${url} != http* ]]; then
				local resolved
				resolved=$(git config "${urlid}" | awk -F/ '{print $(NF-1)"/"$(NF-0)}')
				git config "${urlid}" "https://github.com/${resolved}" || die
			fi

			git -c protocol.file.allow=always submodule update --init --filter=tree:0 "${path}" \
				|| die "Could not update submodule ${path}"
		done
	else
		cmake_src_unpack
	fi
}

src_prepare() {
	if [[ ${PV} != "9999" ]]; then
		rmdir "${S}/3rdparty/asmjit/asmjit" || die
		mv "${WORKDIR}/asmjit-${ASMJIT_COMMIT}" "${S}/3rdparty/asmjit/asmjit" || die

		rmdir "${S}/3rdparty/glslang/glslang" || die
		mv "${WORKDIR}/glslang-${GLSLANG_COMMIT}" "${S}/3rdparty/glslang/glslang" || die

		rmdir "${S}/3rdparty/wolfssl/wolfssl" || die
		mv "${WORKDIR}/wolfssl-${WOLFSSL_COMMIT}" "${S}/3rdparty/wolfssl/wolfssl" || die

		rmdir "${S}/3rdparty/SoundTouch/soundtouch" || die
		mv "${WORKDIR}/soundtouch-${SOUNDTOUCH_COMMIT}" "${S}/3rdparty/SoundTouch/soundtouch" || die

		rmdir "${S}/3rdparty/yaml-cpp/yaml-cpp" || die
		mv "${WORKDIR}/yaml-cpp-${YAMLCPP_COMMIT}" "${S}/3rdparty/yaml-cpp/yaml-cpp" || die

		rmdir "${S}/3rdparty/fusion/fusion" || die
		mv "${WORKDIR}/Fusion-${FUSION_COMMIT}" "${S}/3rdparty/fusion/fusion" || die

		rmdir "${S}/3rdparty/GPUOpen/VulkanMemoryAllocator" || die
		mv "${WORKDIR}/VulkanMemoryAllocator-${VULKANMEMORYALLOCATOR_COMMIT}" \
			"${S}/3rdparty/GPUOpen/VulkanMemoryAllocator" || die

		rmdir "${S}/3rdparty/feralinteractive/feralinteractive" || die
		mv "${WORKDIR}/gamemode-${GAMEMODE_COMMIT}" \
			"${S}/3rdparty/feralinteractive/feralinteractive" || die

		rmdir "${S}/3rdparty/discord-rpc/discord-rpc" || die
		mv "${WORKDIR}/discord-rpc-${DISCORD_COMMIT}" "${S}/3rdparty/discord-rpc/discord-rpc" || die

		#Define RPCS3 Version
		{ echo "#define RPCS3_GIT_VERSION \"${PV}\""
		echo '#define RPCS3_GIT_BRANCH "master"'
		echo '#define RPCS3_GIT_FULL_BRANCH "RPCS3/rpcs3/master"'
		echo '#define RPCS3_GIT_VERSION_NO_UPDATE 1'; } > rpcs3/git-version.h
	fi

	# Disable automagic ccache
	sed -i -e '/find_program(CCACHE_PATH ccache .*)/d' CMakeLists.txt || die

	# QA Notice: Compatibility with CMake < 3.5 has been removed from CMake 4
	find . -maxdepth 9 -type f -name CMakeLists.txt \
	-exec sed -i -e '/cmake_minimum_required/c\cmake_minimum_required(VERSION 4.0)' {} \; \
	|| die "Could not update cmake_minimum_required"

	# Unbundle yaml-cpp: system yaml-cpp should be compiled with -fexceptions
	# sed -i -e '/yaml-cpp/d' 3rdparty/CMakeLists.txt || die
	# sed -i -e '$afind_package(yaml-cpp)\n' CMakeLists.txt || die
	# sed -i -e 's/3rdparty::yaml-cpp/yaml-cpp/' rpcs3/Emu/CMakeLists.txt \
	#	rpcs3/rpcs3qt/CMakeLists.txt || die

	cmake_src_prepare
}

src_configure() {
	filter-lto

	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=OFF # to remove after unbundling
		-DUSE_PRECOMPILED_HEADERS=ON
		-DUSE_SYSTEM_CUBEB=ON
		-DUSE_SYSTEM_CURL=ON
		-DUSE_SYSTEM_FFMPEG=ON
		-DUSE_SYSTEM_PROTOBUF=ON
		-DUSE_SYSTEM_HIDAPI=ON
		-DUSE_SYSTEM_LIBPNG=ON
		-DUSE_SYSTEM_LIBUSB=ON
		-DUSE_SYSTEM_MINIUPNPC=ON
		-DUSE_SYSTEM_PUGIXML=ON
		-DUSE_SYSTEM_RTMIDI=ON
		-DUSE_SYSTEM_ZLIB=ON
		-DUSE_SYSTEM_ZSTD=ON
		-DUSE_DISCORD_RPC=$(usex discord)
		-DUSE_FAUDIO=$(usex faudio)
		-DUSE_SYSTEM_OPENCV=$(usex opencv)
		-DUSE_VULKAN=$(usex vulkan)
		-DWITH_LLVM=$(usex llvm)
		$(cmake_use_find_package wayland Wayland)
	)
	# These options are defined conditionally to suppress QA notice
	use faudio && mycmakeargs+=( -DUSE_SYSTEM_FAUDIO=$(usex faudio) )

	cmake_src_configure

	sed -i -e 's/FFMPEG_LIB_AVFORMAT-NOTFOUND/avformat/' -e 's/FFMPEG_LIB_AVCODEC-NOTFOUND/avcodec/' \
		-e 's/FFMPEG_LIB_AVUTIL-NOTFOUND/avutil/' -e 's/FFMPEG_LIB_SWSCALE-NOTFOUND/swscale/' \
		-e 's/FFMPEG_LIB_SWRESAMPLE-NOTFOUND/swresample/' "${BUILD_DIR}"/build.ninja || die
}

src_install() {
	cmake_src_install

	# remove unneccessary files to save some space
	rm -rf "${ED}/usr/share/rpcs3/"{git,test} || die
}

pkg_postinst() {
	optfeature "FeralInteractive GameMode support" games-util/gamemode
}
