# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit toolchain-funcs

DESCRIPTION="A small scripting language for use in init scripts and other system tasks"
HOMEPAGE="https://skarnet.org/software/execline"
SRC_URI="https://git.skarnet.org/cgit/execline/snapshot/${P}.tar.gz"

LICENSE="ISC"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~alpha amd64 ~arm ~arm64 ~mips ~ppc ~ppc64 ~riscv x86"

IUSE="+static-libs shared-libs"
RDEPEND=">=dev-libs/skalibs-2.15.0.0:="
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
		--with-dynlib="/$(get_libdir)"
		--with-lib="/usr/$(get_libdir)/skalibs"
		--with-sysdeps="/usr/$(get_libdir)/skalibs"
		--enable-pkgconfig
		--pkgconfdir="/usr/$(get_libdir)/pkgconfig"

		$(use_enable shared-libs shared)
		$(usex static-libs \
			"--enable-static --enable-allstatic --enable-static-libc" \
			"--disable-static --disable-allstatic --disable-static-libc")
	)

	econf "${myconf[@]}"
}
