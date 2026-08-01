# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Range confirmed from mach's own site.py: MIN_PYTHON_VERSION=(3,9),
# MAX_PYTHON_VERSION_TO_CONSIDER=(3,12). Deliberately NOT extending to
# 3_13/3_14/3_15 despite pkgcheck's PythonCompatUpdate suggestion - mach
# hard-refuses to run under anything above 3.12, confirmed from source,
# not a guess. Bumping this would let the eclass prefer a version mach
# won't accept (this is exactly the bug that caused an earlier failure).
PYTHON_COMPAT=( python3_9 python3_10 python3_11 python3_12 )

inherit multilib multiprocessing python-any-r1 toolchain-funcs xdg

DESCRIPTION="Firefox-based web browser focused on performance and customizability"
HOMEPAGE="https://floorp.app/"

# Floorp splits its source into 3 components merged at build time, mirroring
# the floorp AUR PKGBUILD this was derived from:
#   - Floorp:         the noraneko UI layer + branding assets
#   - Floorp-Runtime:  the actual Gecko/Firefox engine fork (topsrcdir == S)
#   - Floorp-core:     API keys only (apis/api-*-key)
_RUNTIME_COMMIT="838d2c243625a5e0347bc1cf7fe4106ceabdb575" # daily-952, per upstream PKGBUILD
_CORE_COMMIT="97a8a848fd8ed2e368f8cb6ad088afac33c1256d" # Floorp-core@main HEAD, verified via
# `git ls-remote https://github.com/Floorp-Projects/Floorp-core main` on 2026-07-08.
# Repo has been archived/read-only since 2025-10-26, so main can't move further -
# re-run that ls-remote if that policy ever changes and this needs re-pinning.

SRC_URI="
	https://github.com/Floorp-Projects/Floorp/archive/refs/tags/v${PV}.tar.gz -> ${P}-components.tar.gz
	https://github.com/Floorp-Projects/Floorp-Runtime/archive/${_RUNTIME_COMMIT}.tar.gz -> ${P}-runtime.tar.gz
	https://github.com/Floorp-Projects/Floorp-core/archive/${_CORE_COMMIT}.tar.gz -> ${P}-core.tar.gz
"

S="${WORKDIR}/Floorp-Runtime-${_RUNTIME_COMMIT}"

LICENSE="MPL-2.0"
SLOT="0"
KEYWORDS="~amd64"
IUSE="+alsa debug +hardened +jack lto +system-libs +wayland"

# Firefox on Linux is effectively clang-only at this point - cross-language
# rust<->C++ LTO specifically needs it - so clang/lld/llvm are unconditional
# BDEPEND rather than a USE-gated choice. Matches upstream's own mozconfig,
# which never offers a gcc path either.
#
# Not included below, unclear if actually load-bearing for this Floorp
# version (add if the build complains about a missing tool): diffutils,
# dump_syms, imake, inetutils. All four are in the AUR PKGBUILD's
# makedepends; diffutils is almost certainly already in @system, and I
# can't confirm correct Gentoo atoms for the other three with confidence.
#
# dev-lang/deno-bin (confirmed on packages.gentoo.org - GURU) - makes sense as
# -bin, source-building deno's own Rust toolchain would be its own ordeal.
BDEPEND="
	dev-util/cbindgen
	dev-vcs/git
	dev-vcs/mercurial
	|| (
		dev-lang/rust-bin
		dev-lang/rust
	)
	dev-lang/nasm
	dev-lang/yasm
	dev-lang/deno-bin
	dev-python/setuptools
	virtual/pkgconfig
	${PYTHON_DEPS}
	net-misc/rsync
	sys-apps/findutils
	app-arch/unzip
	app-arch/zip
	llvm-core/clang
	llvm-core/lld
	llvm-core/llvm
	net-libs/nodejs
	jack? ( media-sound/jack2 )
"

# RLBox/wasm-sandboxed libs (hunspell, graphite, etc.) need a pinned wasi-sdk
# sysroot to build; --without-wasm-sandboxed-libraries in src_configure
# sidesteps that rather than packaging it here. See www-client/firefox's own
# ebuild for the real mechanism (it fetches a pinned wasi-sdk release via
# SRC_URI) if you want that sandboxing back.
#
# Gentoo generally prefers nss/nspr linked against system copies regardless
# of +system-libs, for independent CVE turnaround - upstream's own mozconfig
# groups them with the rest of the system-libs toggle, so I matched that
# instead of unilaterally splitting the flag. Worth revisiting.
DEPEND="
	x11-libs/gtk+:3[wayland?]
	media-libs/mesa
	sys-apps/dbus
	media-video/ffmpeg
	x11-libs/libXScrnSaver
	x11-libs/libXt
	alsa? ( media-libs/alsa-lib )
	media-libs/libpulse
	system-libs? (
		dev-libs/nspr
		dev-libs/nss
		dev-libs/libevent
		media-libs/libjpeg-turbo
		media-libs/libvpx
		media-libs/libwebp
		virtual/zlib
	)
"
RDEPEND="${DEPEND}"

# Mozilla's build already strips via --enable-strip/--enable-install-strip;
# skip Portage's own strip pass on top of that (matches upstream's `!strip`).
# noraneko's frontend is an npm-backed Deno workspace with nothing vendored -
# `deno install` genuinely needs the network during src_compile to pull from
# registry.npmjs.org. RESTRICT=network-sandbox is the correct escape hatch
# for that rather than trying to vendor the whole npm tree via SRC_URI.
RESTRICT="strip network-sandbox"

pkg_setup() {
	tc-is-cross-compiler && die "This ebuild does not support cross-compiling Floorp."
	python-any-r1_pkg_setup
}

src_prepare() {
	default

	einfo "Merging Floorp components into the Mozilla Runtime tree..."
	rsync -aL --mkpath "${WORKDIR}/Floorp-${PV}/" "${S}/noraneko/" || die "Failed to merge noraneko components"
	rsync -aL --mkpath "${S}/.github/assets/branding/" "${S}/browser/branding/" || die "Failed to merge branding"

	einfo "Copying API keys from Floorp-core..."
	cp "${WORKDIR}/Floorp-core-${_CORE_COMMIT}"/apis/api-*-key "${S}/" || die "Failed to copy API keys"

	einfo "Applying upstream patches (best-effort, matches upstream's own tolerance for skew)..."
	local patch
	for patch in "${S}"/.github/patches/upstream/*.patch; do
		[[ -e ${patch} ]] || continue
		git apply --ignore-space-change --ignore-whitespace "${patch}" || true
	done
}

src_configure() {
	# Portage exports XARGS="xargs -r" itself; a bug in moz.configure's
	# check_progs() treats that whole string as a literal program name to
	# search PATH for instead of parsing prog+flag, so it "can't find xargs"
	# even though xargs is right there. Confirmed cause + fix: moz bug
	# 1677994, which points at how www-client/firefox handles this exact
	# thing. Has to be unset here AND in src_compile since Portage restores
	# its own env at the start of every phase.
	unset XARGS

	local mozconfig="${S}/.mozconfig"

	# mach looks for ".mozconfig" (or $MOZCONFIG) in the topsrcdir - the
	# ebuild this was based on wrote a plain "mozconfig" file mach would
	# never have found, so configure would have silently used defaults.
	cat > "${mozconfig}" <<-EOF || die
		ac_add_options --enable-application=browser
		ac_add_options --disable-artifact-builds
		mk_add_options MOZ_OBJDIR="${S}/obj-artifact-build-output"

		ac_add_options --prefix=/usr
		ac_add_options --libdir=/usr/$(get_libdir)
		ac_add_options --enable-release
		ac_add_options --enable-rust-simd
		ac_add_options --enable-wasm-simd
		ac_add_options --enable-linker=lld
		ac_add_options --disable-elf-hack
		ac_add_options --disable-bootstrap

		# Floorp branding
		ac_add_options --with-app-basename=Floorp
		ac_add_options --with-app-name=floorp
		ac_add_options --with-branding=browser/branding/floorp-official
		ac_add_options --enable-update-channel=nightly
		ac_add_options --with-distribution-id=org.gentoo
		ac_add_options --with-unsigned-addon-scopes=app,system
		ac_add_options --allow-addon-sideload
		export MOZ_APP_NAME=floorp
		export MOZ_APP_REMOTINGNAME=floorp
		MOZ_REQUIRE_SIGNING=

		# Keys
		ac_add_options --with-mozilla-api-keyfile="${S}/api-mozilla-key"
		ac_add_options --with-google-location-service-api-keyfile="${S}/api-google-location-service-key"
		ac_add_options --with-google-safebrowsing-api-keyfile="${S}/api-google-safe-browsing-key"

		# Features
		ac_add_options --enable-eme=widevine
		ac_add_options --enable-jxl
		ac_add_options --enable-proxy-bypass-protection
		ac_add_options --enable-pulseaudio
		ac_add_options --enable-sandbox
		ac_add_options --enable-unverified-updates
		ac_add_options --enable-webrtc
		ac_add_options --disable-crashreporter
		ac_add_options --disable-default-browser-agent
		ac_add_options --disable-parental-controls
		ac_add_options --disable-tests
		ac_add_options --disable-updater

		# See the BDEPEND comment re: wasi-sdk - disable sandboxed libs
		# explicitly rather than let configure die looking for a sysroot.
		ac_add_options --without-wasm-sandboxed-libraries

		# Telemetry off
		mk_add_options MOZ_DATA_REPORTING=0
		mk_add_options MOZ_SERVICES_HEALTHREPORT=0
		mk_add_options MOZ_TELEMETRY_REPORTING=0

		# Optimization
		ac_add_options --enable-optimize
		ac_add_options OPT_LEVEL="2"
		ac_add_options RUSTC_OPT_LEVEL="2"

		# Floorp/Firefox is effectively clang-only on Linux; cross-language
		# rust<->C++ LTO specifically requires it.
		export AR=llvm-ar
		export CC=clang
		export CXX=clang++
		export NM=llvm-nm
		export RANLIB=llvm-ranlib

		# bindgen needs libclang.so specifically (separate from the clang
		# binary) - mach's own search doesn't check Gentoo's slotted
		# /usr/lib/llvm/<slot>/ layout, so point it there explicitly.
		ac_add_options --with-libclang-path="$(llvm-config --libdir)"

		# see the unset XARGS above - must be ac_add_options, not
		# mk_add_options, or it hits the same check_progs() bug
		ac_add_options XARGS=/usr/bin/xargs

		mk_add_options MOZ_PARALLEL_BUILD=$(makeopts_jobs)
	EOF

	if use alsa; then
		echo "ac_add_options --enable-alsa" >> "${mozconfig}" || die
	fi

	if use jack; then
		echo "ac_add_options --enable-jack" >> "${mozconfig}" || die
	fi

	if use hardened; then
		echo "ac_add_options --enable-hardening" >> "${mozconfig}" || die
	fi

	if use debug; then
		echo "ac_add_options --enable-debug" >> "${mozconfig}" || die
	else
		cat >> "${mozconfig}" <<-EOF || die
			ac_add_options --disable-debug
			ac_add_options --disable-debug-symbols
			ac_add_options --disable-debug-js-modules
			ac_add_options --enable-strip
			ac_add_options --enable-install-strip
			export STRIP_FLAGS="--strip-debug --strip-unneeded"
		EOF
	fi

	if use lto; then
		echo "ac_add_options --enable-lto=cross,full" >> "${mozconfig}" || die
	fi

	if use system-libs; then
		cat >> "${mozconfig}" <<-EOF || die
			ac_add_options --with-system-jpeg
			ac_add_options --with-system-libevent
			ac_add_options --with-system-libvpx
			ac_add_options --with-system-nspr
			ac_add_options --with-system-nss
			ac_add_options --with-system-webp
			ac_add_options --with-system-zlib
		EOF
	fi
}

src_compile() {
	unset XARGS # see src_configure - Portage restores this every phase

	export RUSTUP_TOOLCHAIN=stable # likely a no-op on Gentoo's (non-rustup) dev-lang/rust; harmless

	export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${T}/xdg-runtime}"
	[[ -d ${XDG_RUNTIME_DIR} ]] || mkdir -m700 "${XDG_RUNTIME_DIR}" || die

	# MACH_USE_SYSTEM_PYTHON is deprecated in mach's own site.py and (via its
	# fallback path) resolves to SitePackagesSource.NONE, not .SYSTEM despite
	# the name - use the explicit modern equivalent instead. Specifically
	# avoiding NATIVE_PACKAGE_SOURCE=pip: that maps to SitePackagesSource.VENV,
	# i.e. mach creates its own venv and `pip install`s into it - a second,
	# Portage-untracked package manager doing its own PyPI fetches. =none
	# skips that path entirely; native (compiled) deps come from the system
	# Python install or not at all.
	export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none
	export MOZBUILD_STATE_PATH="${T}/mozbuild"
	mkdir -p "${MOZBUILD_STATE_PATH}" || die
	# intentionally unquoted - relies on word-splitting to bundle -u/-d, see
	# upstream's build() for the original of this trick
	export MOZ_BUILD_DATE="$(date -u${SOURCE_DATE_EPOCH:+d @$SOURCE_DATE_EPOCH} +%Y%m%d%H%M%S)"
	export MOZ_NOSPAM=1
	export DENO_DIR="${WORKDIR}/.deno"

	# malloc_usable_size() usage trips over _FORTIFY_SOURCE=3; -fexceptions
	# breaks the build outright (moz bug 1896066). This is upstream's own
	# workaround, not just hardened-profile paranoia on my part.
	export CFLAGS="${CFLAGS/_FORTIFY_SOURCE=3/_FORTIFY_SOURCE=2}"
	export CXXFLAGS="${CXXFLAGS/_FORTIFY_SOURCE=3/_FORTIFY_SOURCE=2}"
	export CFLAGS="${CFLAGS//-fexceptions/}"
	export CXXFLAGS="${CXXFLAGS//-fexceptions/}"

	ulimit -n 4096 # LTO/parallel rust codegen wants more open fds than the default

	cd "${S}" || die

	einfo "Running noraneko pre-mach deno tasks..."
	pushd "${S}/noraneko" > /dev/null || die
	deno install --allow-scripts || die "deno install failed"
	deno task feles-build misc writeVersion || die "deno writeVersion failed"
	NODE_ENV=production deno task feles-build build --phase before-mach || die "deno before-mach phase failed"
	popd > /dev/null || die

	einfo "Applying packaging patches (best-effort, matches upstream's tolerance for skew)..."
	local patch
	for patch in "${S}"/.github/patches/packaging/*.patch; do
		[[ -e ${patch} ]] || continue
		git apply --ignore-space-change --ignore-whitespace "${patch}" || true
	done

	einfo "Setting Floorp version strings..."
	local floorp_ver firefox_ver
	floorp_ver=$(<"${S}/noraneko/static/gecko/config/version.txt")
	firefox_ver=$(sed -E -e 's&^.*@&&' "${S}/browser/config/version.txt")
	echo "${floorp_ver}@${firefox_ver}" \
		| tee "${S}/browser/config/version.txt" "${S}/browser/config/version_display.txt" \
		> /dev/null || die

	einfo "Clearing forced startup homepage prefs..."
	sed -E -e 's&^\s*pref\("startup\.homepage.*$&&' \
		-i "${S}"/browser/branding/*/pref/firefox-branding.js || die

	einfo "Starting Mozilla mach build (this takes a long time)..."
	"${EPYTHON}" ./mach build --priority normal || die "mach build failed"

	# missing on install per upstream packaging notes
	cp "${S}/noraneko/_dist/buildid2" "${S}/obj-artifact-build-output/dist/bin/browser/" || die

	einfo "Dereferencing symlinks in the objdir before install..."
	rsync -aL "${S}/obj-artifact-build-output/" "${S}/obj-artifact-build-output_new/" || die
	rm -rf "${S}/obj-artifact-build-output_old"
	mv "${S}/obj-artifact-build-output" "${S}/obj-artifact-build-output_old" || die
	mv "${S}/obj-artifact-build-output_new" "${S}/obj-artifact-build-output" || die

	einfo "Running noraneko post-mach deno task..."
	pushd "${S}/noraneko" > /dev/null || die
	deno task feles-build build --phase after-mach || die "deno after-mach phase failed"
	popd > /dev/null || die

	einfo "Applying noraneko output patches (best-effort)..."
	for patch in "${S}"/noraneko/tools/patches/*.patch; do
		[[ -e ${patch} ]] || continue
		git apply --reject --directory="${S}/obj-artifact-build-output/dist/bin" --unsafe-paths "${patch}" || true
	done

	bash "${S}/noraneko/static/gecko/pref/override.sh" \
		"${S}/obj-artifact-build-output/dist/bin/browser/defaults/preferences/firefox.js" || die
}

src_install() {
	cd "${S}" || die
	local libdir="/usr/$(get_libdir)/floorp"

	export MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=none
	DESTDIR="${D}" "${EPYTHON}" ./mach install || die "mach install failed"

	dodir "${libdir}"/browser/defaults/preferences
	cat > "${D}${libdir}/browser/defaults/preferences/vendor.js" <<-EOF || die
		// Use LANG environment variable to choose locale
		pref("intl.locale.requested", "");

		// Use system-provided dictionaries
		pref("spellchecker.dictionary_path", "/usr/share/hunspell");

		// Disable default browser checking
		pref("browser.shell.checkDefaultBrowser", false);

		// Don't disable extensions in the application directory
		pref("extensions.autoDisableScopes", 11);

		// Enable GNOME Shell search provider
		pref("browser.gnome-search-provider.enabled", true);

		// Enable JPEG XL images
		pref("image.jxl.enabled", true);

		// Prevent about:config warning
		pref("browser.aboutConfig.showWarning", false);

		// Prevent telemetry notification
		pref("services.settings.main.search-telemetry-v2.last_check", $(date +%s));
	EOF

	dodir "${libdir}"/distribution
	cat > "${D}${libdir}/distribution/distribution.ini" <<-EOF || die
		[Global]
		id=gentoo
		version=rolling
		about=Floorp for Gentoo

		[Preferences]
		app.distributor=gentoo
		app.distributor.channel=floorp
		app.partner.gentoo=gentoo
	EOF

	dodir /usr/share/gnome-shell/search-providers
	cat > "${D}/usr/share/gnome-shell/search-providers/floorp.search-provider.ini" <<-EOF || die
		[Shell Search Provider]
		DesktopId=floorp.desktop
		BusName=org.mozilla.floorp.SearchProvider
		ObjectPath=/org/mozilla/floorp/SearchProvider
		Version=2
	EOF

	dosym floorp "${libdir}/floorp-bin"

	local desktop="${T}/floorp.desktop"
	cat > "${desktop}" <<-EOF || die
		[Desktop Entry]
		Version=1.0
		Name=Floorp
		GenericName=Web Browser
		Comment=Browse the World Wide Web
		Keywords=Internet;WWW;Browser;Web;Explorer
		Exec=floorp %u
		Terminal=false
		X-MultipleArgs=false
		Type=Application
		Icon=floorp
		Categories=Network;WebBrowser;
		MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
		StartupNotify=true
		StartupWMClass=floorp
		Actions=new-window;new-private-window;

		[Desktop Action new-window]
		Name=Open a New Window
		Exec=floorp %u
		Icon=floorp

		[Desktop Action new-private-window]
		Name=Open a New Private Window
		Exec=floorp --private-window %u
		Icon=floorp
	EOF
	domenu "${desktop}"

	newicon -s 256 "${S}/browser/branding/floorp-official/default256.png" floorp.png
	local size
	for size in 16 32 48 64 128; do
		dosym "${libdir}/browser/chrome/icons/default/default${size}.png" \
			"/usr/share/icons/hicolor/${size}x${size}/apps/floorp.png"
	done
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "Optional, not pulled in automatically (matching upstream's own optdepends):"
	elog "  app-text/hunspell (+ dictionaries)  - spell checking"
	elog "  x11-libs/libnotify                  - desktop notifications"
	elog "  app-accessibility/speech-dispatcher  - text-to-speech"
	elog "  net-misc/networkmanager              - wifi-based location lookups"
	elog "  sys-apps/xdg-desktop-portal(-wlr)     - Wayland screen sharing"
}
