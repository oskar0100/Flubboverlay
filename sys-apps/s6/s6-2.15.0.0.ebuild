# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
EAPI=8
inherit toolchain-funcs
DESCRIPTION="skarnet.org's small & secure supervision software suite"
HOMEPAGE="https://skarnet.org/software/s6"
SRC_URI="https://git.skarnet.org/cgit/s6/snapshot/${P}.tar.gz"
LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="shared-libs +execline"
DEPEND="
    >=dev-libs/skalibs-2.15.0.0
    execline? ( >=dev-lang/execline-2.9.9.0 )"
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
        $(usex shared-libs "--enable-shared --disable-allstatic" "") \
        $(usex execline "" "--disable-execline") \
        || die
}
src_compile() {
    emake
}
src_install() {
    emake DESTDIR="${D}" install
}
