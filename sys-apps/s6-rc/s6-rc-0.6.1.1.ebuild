# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8
inherit toolchain-funcs
DESCRIPTION="A dependency-based service manager for s6"
HOMEPAGE="https://skarnet.org/software/s6-rc"
SRC_URI="https://git.skarnet.org/cgit/s6-rc/snapshot/${P}.tar.gz"
LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="shared-libs"
DEPEND="
    >=dev-libs/skalibs-2.15.0.0
    >=dev-lang/execline-2.9.9.1
    >=sys-apps/s6-2.15.0.0"
RDEPEND="${DEPEND}"
src_configure() {
    tc-export AR CC RANLIB
    ./configure \
        --prefix=/usr \
        --bindir=/usr/bin \
        --libdir=/usr/$(get_libdir) \
        --with-lib=/usr/$(get_libdir)/skalibs \
        --with-dynlib=/$(get_libdir) \
        --with-include=/usr/include/skalibs \
        --with-sysdeps=/usr/$(get_libdir)/skalibs/sysdeps \
        --with-lib=/usr/$(get_libdir)/s6 \
        --with-dynlib=/usr/$(get_libdir)/s6 \
        --with-include=/usr/include/s6 \
        $(usex shared-libs "--enable-shared --disable-allstatic" "") \
        || die
}
src_compile() {
    emake
}
src_install() {
    emake DESTDIR="${D}" install
}
