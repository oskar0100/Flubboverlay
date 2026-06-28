# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit desktop xdg

DESCRIPTION="Standalone Electron-based Discord client with Vencord (prebuilt binary)"
HOMEPAGE="https://github.com/Vencord/Vesktop"

SRC_URI="
    https://github.com/Vencord/Vesktop/releases/download/v${PV}/vesktop-${PV}.tar.gz
        -> ${P}.tar.gz
"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64"

RESTRICT="mirror strip"

RDEPEND="
    media-libs/alsa-lib
    x11-libs/gtk+:3
    dev-libs/nss
    x11-misc/xdg-utils
"

S="${WORKDIR}"

QA_PREBUILT="opt/vesktop/*"

src_install() {
    insinto /opt/vesktop

    # detect unpacked directory safely (handles upstream changes)
    local srcdir
    srcdir=( "${WORKDIR}"/vesktop-* )

    [[ -d "${srcdir[0]}" ]] || die "vesktop unpacked directory not found"

    doins -r "${srcdir[0]}"/. || die

    # main binary must exist
    [[ -f "${ED}/opt/vesktop/vesktop" ]] || die "vesktop binary not found after install"

    fperms +x /opt/vesktop/vesktop || die

    dosym /opt/vesktop/vesktop /usr/bin/vesktop

    # icon (fallback-safe pattern)
    if [[ -f "${srcdir[0]}/resources/icon.png" ]]; then
	newicon "${FILESDIR}/vesktop.png" vesktop.png
	fi

    make_desktop_entry \
        "vesktop" \
        "Vesktop" \
        "vesktop" \
        "Network;InstantMessaging;" \
        "StartupWMClass=Vesktop"
}
