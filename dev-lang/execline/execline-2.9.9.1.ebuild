# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8
inherit toolchain-funcs
DESCRIPTION="A small scripting language for use in init scripts and other system tasks"
HOMEPAGE="https://skarnet.org/software/execline"
SRC_URI="https://git.skarnet.org/cgit/execline/snapshot/${P}.tar.gz"
LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="shared-libs"
DEPEND=">=dev-libs/skalibs-2.15.0.0"
RDEPEND="${DEPEND}"

src_configure() {
    tc-export AR CC RANLIB
    ./configure \
        --prefix=/usr \
        --bindir=/usr/bin \
        --libdir=/usr/$(get_libdir) \
        --with-lib=/usr/$(get_libdir)/skalibs \
        --with-include=/usr/include/skalibs \
        --with-sysdeps=/usr/$(get_libdir)/skalibs/sysdeps \
        $(usex shared-libs "--enable-shared --disable-allstatic" "") \
        || die
}

src_compile() {
    emake
}

src_install() {
    emake DESTDIR="${D}" install
}
