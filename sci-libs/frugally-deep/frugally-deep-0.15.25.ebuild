# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Header-only library for using Keras (TensorFlow) models in C++."
HOMEPAGE="https://github.com/Dobiasd/frugally-deep"
FRUGALLY_DEEP_COMMIT_TAG=v${PV}-p0
SRC_URI="https://github.com/Dobiasd/${PN}/archive/${FRUGALLY_DEEP_COMMIT_TAG}.tar.gz -> ${PN}-${FRUGALLY_DEEP_COMMIT_TAG}.tar.gz"

LICENSE="MIT"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"

RDEPEND=""

DEPEND="dev-libs/FunctionalPlus
	${RDEPEND}"

BDEPEND=">=dev-build/cmake-3.22"

S="${WORKDIR}/${P}-p0"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=On
	)
	cmake_src_configure
}
