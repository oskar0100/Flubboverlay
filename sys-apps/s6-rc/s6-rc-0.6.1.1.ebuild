# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8
inherit toolchain-funcs
DESCRIPTION="A dependency-based service manager for s6"
HOMEPAGE="https://skarnet.org/software/s6-rc"
SRC_URI="https://git.skarnet.org/cgit/s6-rc/snapshot/${P}.tar.gz"
LICENSE="ISC"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="amd64 ~arm ~x86"
RDEPEND="
	dev-lang/execline:=
	>=dev-libs/skalibs-2.15.0.0:=
	>=sys-apps/s6-2.15.0.0:=[execline]
"
DEPEND="${RDEPEND}"
src_prepare() {
	default
	sed -i -e 's/.*-Wl,--hash-style=both$/:/' configure || die
	sed -i -e '/AR := /d' -e '/RANLIB := /d' Makefile || die
}
src_configure() {
	tc-export AR CC RANLIB
	local myconf=(
		--bindir=/bin
		--dynlibdir="/$(get_libdir)"
		--libdir="/usr/$(get_libdir)/${PN}"
		--libexecdir=/lib/s6
		--with-dynlib="/$(get_libdir)"
		--with-lib="/usr/$(get_libdir)/execline"
		--with-lib="/usr/$(get_libdir)/s6"
		--with-lib="/usr/$(get_libdir)/skalibs"
		--with-sysdeps="/usr/$(get_libdir)/skalibs"
		--enable-pkgconfig
		--pkgconfdir="/usr/$(get_libdir)/pkgconfig"
		--enable-shared
		--disable-allstatic
		--disable-static
		--disable-static-libc
	)
	econf "${myconf[@]}"
}
