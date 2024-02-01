# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake

DESCRIPTION="Functional Programming Library for C++. Write concise and readable C++ code."
HOMEPAGE="https://github.com/Dobiasd/FunctionalPlus"
FUNCTIONALPLUS_COMMIT_TAG=v${PV}-p0
SRC_URI="https://github.com/Dobiasd/${PN}/archive/${FUNCTIONALPLUS_COMMIT_TAG}.tar.gz -> FunctionalPlus-${FUNCTIONALPLUS_COMMIT_TAG}.tar.gz"

LICENSE="MIT"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"
REQUIRED_USE="${ROCM_REQUIRED_USE}"

RDEPEND=""

DEPEND="${RDEPEND}
	dev-build/rocm-cmake"

BDEPEND="dev-build/rocm-cmake
	>=dev-build/cmake-3.22"

S="${WORKDIR}/${PN}-${PV}-p0"

src_configure() {
	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=On
	)

	cmake_src_configure
}
