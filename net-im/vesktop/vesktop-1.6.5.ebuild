# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8

inherit desktop xdg

DESCRIPTION="Standalone Electron-based Discord client with Vencord (prebuilt binary)"
HOMEPAGE="https://github.com/Vencord/Vesktop"

SRC_URI="
    https://github.com/Vencord/Vesktop/releases/download/v${PV}/Vesktop-${PV}.tar.gz
        -> ${P}.tar.gz
"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="amd64"

RESTRICT="strip mirror"

S="${WORKDIR}"

RDEPEND="
    media-libs/alsa-lib
    x11-libs/gtk+:3
    dev-libs/nss
    x11-misc/xdg-utils
"

QA_PREBUILT="opt/vesktop/*"

src_install() {
    insinto /opt/vesktop
    doins -r Vesktop-linux-unpacked/* || die

    [[ -f Vesktop-linux-unpacked/vesktop ]] || die "binary not found"
    fperms +x /opt/vesktop/vesktop || die

    dosym /opt/vesktop/vesktop /usr/bin/vesktop

    newicon Vesktop-linux-unpacked/resources/icon.png vesktop.png

    make_desktop_entry \
        "vesktop" \
        "Vesktop" \
        "vesktop" \
        "Network;InstantMessaging;" \
        "StartupWMClass=Vesktop"
}
