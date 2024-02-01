# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DOCS_BUILDER="doxygen"
DOCS_DEPEND="media-gfx/graphviz"

inherit cmake docs llvm

LLVM_MAX_SLOT=17

DESCRIPTION="C++ Heterogeneous-Compute Interface for Portability"
HOMEPAGE="https://github.com/ROCm-Developer-Tools/hipamd"
SRC_URI="https://github.com/ROCm-Developer-Tools/HIPIFY/archive/rocm-${PV}.tar.gz -> hipify-clang-${PV}.tar.gz"

KEYWORDS="~amd64"
LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"

IUSE="debug"

DEPEND="
	sys-devel/clang:${LLVM_MAX_SLOT}
	x11-base/xorg-proto
	virtual/opengl
"
RDEPEND="${DEPEND}
	sys-devel/clang-runtime:="

S="${WORKDIR}"/HIPIFY-rocm-${PV}

pkg_setup() {
	export CC=clang CXX=clang++ CPP=clang
	tc-is-clang || die Not clang
	
	strip-unsupported-flags
}

src_prepare() {
	eapply "${FILESDIR}/${PN}-5.7.1-llvm-link.patch"
	#eapply "${FILESDIR}/${PN}-5.3.0-install.patch"
	eapply "${FILESDIR}/${PN}-5.3.0-sys-include.patch"
	sed -e "s,@CLANG_INCLUDE_PATH@,${CLANG_RESOURCE_DIR}/include," \
		-i src/main.cpp || die
	popd
	cmake_src_prepare
}

src_configure() {
	use debug && CMAKE_BUILD_TYPE="Debug"

	# TODO: Currently a GENTOO configuration is build,
	# this is also used in the cmake configuration files
	# which will be installed to find HIP;
	# Other ROCm packages expect a "RELEASE" configuration,
	# see "hipBLAS"
	local mycmakeargs=(
		-DCMAKE_PREFIX_PATH="$(get_llvm_prefix "${LLVM_MAX_SLOT}")"
		-DCMAKE_BUILD_TYPE=${buildtype}
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr"
		-DCMAKE_SKIP_RPATH=ON
		-DFILE_REORG_BACKWARD_COMPATIBILITY=OFF
	)

	cmake_src_configure
}
