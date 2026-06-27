# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
DESCRIPTION="A small and statically linkable alternative to Name Service Switch"
HOMEPAGE="https://skarnet.org/software/nsss"
SRC_URI="https://git.skarnet.org/cgit/nsss/snapshot/${P}.tar.gz"
LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64"
IUSE="shared-libs +s6"
RDEPEND="s6? ( sys-apps/s6 )
		 dev-libs/skalibs"
DEPEND="dev-libs/skalibs"

src_configure() {
	./configure \
		--prefix=/usr \
		--libdir=/usr/$(get_libdir) \
		--with-lib=/usr/$(get_libdir)/skalibs \
		--with-include=/usr/include/skalibs \
		$(usex shared-libs "--enable-shared --disable-allstatic" "") \
		|| die
}
src_compile() {
	emake
}
src_install() {
	emake DESTDIR="${D}" install
}
