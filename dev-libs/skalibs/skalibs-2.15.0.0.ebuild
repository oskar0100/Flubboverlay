# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8
inherit toolchain-funcs
DESCRIPTION="A set of general-purpose C programming libraries"
HOMEPAGE="https://www.skarnet.org/software/skalibs/"
SRC_URI="https://git.skarnet.org/cgit/skalibs/snapshot/${P}.tar.gz"
LICENSE="ISC"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~alpha amd64 ~arm ~arm64 ~mips ~ppc ~ppc64 ~riscv x86"
IUSE="+static-libs shared-libs"
HTML_DOCS=( doc/. )

src_prepare() {
	default
	sed -i -e 's/.*-Wl,--hash-style=both$/:/' configure || die
	sed -i -e '/AR := /d' -e '/RANLIB := /d' Makefile || die
}

src_configure() {
	tc-export AR CC RANLIB
	local myconf=(
		--dynlibdir="/$(get_libdir)"
		--libdir="/usr/$(get_libdir)/${PN}"
		--sysdepdir="/usr/$(get_libdir)/${PN}/sysdeps"
		--sysconfdir=/etc
		--enable-pkgconfig
		--pkgconfdir="/usr/$(get_libdir)/pkgconfig"
		--enable-clock
		--enable-ipv6
		$(usex static-libs "--enable-static" "--disable-static")
		$(usex shared-libs "--enable-shared" "--disable-shared")
	)
	econf "${myconf[@]}"
}

src_install() {
	emake DESTDIR="${D}" install
	rm -f "${D}"/usr/$(get_libdir)/skalibs/sysdeps
	insinto /usr/$(get_libdir)/skalibs/sysdeps
	doins sysdeps.cfg/*
}
