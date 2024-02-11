# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

RESTRICT="strip"

inherit cmake llvm

LLVM_MAX_SLOT=17
LLVM_MIN_SLOT=17

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/Mystro256/ROCm-Device-Libs.git"
	inherit git-r3
	S="${WORKDIR}/${P}/src"
else
	SRC_URI="https://github.com/Mystro256/ROCm-Device-Libs/archive/refs/heads/release/${LLVM_MAX_SLOT}.x.tar.gz -> ${P}.tar.gz"
	S="${WORKDIR}/ROCm-Device-Libs-release-${LLVM_MAX_SLOT}.x"
	KEYWORDS="~amd64"
fi

DESCRIPTION="Radeon Open Compute Device Libraries"
HOMEPAGE="https://github.com/RadeonOpenCompute/ROCm-Device-Libs"

LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="sys-devel/clang:${LLVM_MAX_SLOT}"
DEPEND="${RDEPEND}"

CMAKE_BUILD_TYPE=Release

PATCHES=(
	"${FILESDIR}/${PN}-5.5.1-fix-llvm-link.patch"
	"${FILESDIR}/${PN}-6.0.2-revert-install-into-clang.patch"
	#"${FILESDIR}/${PN}-6.0.0-gws-feature.patch"
	)

pkg_setup() {
	export CC=clang CXX=clang++ CPP=clang
	tc-is-clang || Clang required
	strip-unsupported-flags
	
	append-cxxflags -O3 -flto=thin
}

src_prepare() {
	cmake_src_prepare
	sed -e "s:amdgcn/bitcode:lib/amdgcn/bitcode:" -i "${S}/cmake/OCL.cmake" || die
	sed -e "s:amdgcn/bitcode:lib/amdgcn/bitcode:" -i "${S}/cmake/Packages.cmake" || die
}

src_configure() {
	local mycmakeargs=(
		# -DLLVM_DIR="${EPREFIX}/usr/lib/llvm/roc/lib/cmake/llvm"
		-DLLVM_DIR="$(get_llvm_prefix "${LLVM_MAX_SLOT}")"
	)
	cmake_src_configure
}
