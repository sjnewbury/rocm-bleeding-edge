# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CMAKE_ECLASS=cmake
PYTHON_COMPAT=( python3_{8..11} )
inherit cmake linux-info llvm llvm.org multilib-minimal  python-any-r1

DESCRIPTION="Polyhedral optimizations for LLVM"
HOMEPAGE="https://llvm.org/"

LICENSE="Apache-2.0-with-LLVM-exceptions UoI-NCSA"
SLOT="$(ver_cut 1)"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="~sys-devel/llvm-${PV}[${MULTILIB_USEDEP}]"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-util/cmake-3.16
	test? ( $(python_gen_any_dep "~dev-python/lit-${PV}[\${PYTHON_USEDEP}]") )"

LLVM_COMPONENTS=( polly cmake llvm )
LLVM_TEST_COMPONENTS=( llvm/utils/{lit,unittest} )
llvm.org_set_globals

python_check_deps() {
	has_version -b "dev-python/lit[${PYTHON_USEDEP}]"
}

pkg_setup() {
	LLVM_MAX_SLOT=${PV%%.*} llvm_pkg_setup
	use test && python-any-r1_pkg_setup
}

src_prepare() {
	cmake_src_prepare
	default
	eapply "${FILESDIR}"/optional-tests.patch
}

multilib_src_configure() {
	local mycmakeargs=(
		-DBUILD_SHARED_LIBS=OFF
		-DLLVM_LINK_LLVM_DYLIB=ON
		-DLLVM_POLLY_LINK_INTO_TOOLS=OFF
		-DLLVM_INCLUDE_TESTS=$(usex test)
		-DPOLLY_INCLUDE_TESTS=$(usex test)
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr/lib/llvm/${SLOT}"
		-DCMAKE_PREFIX_PATH="${EPREFIX}/usr/lib/llvm/${SLOT}/$(get_libdir)/cmake/llvm"
	)
	use test && mycmakeargs+=(
		-DLLVM_BUILD_TESTS=ON
		-DLLVM_MAIN_SRC_DIR="${WORKDIR}/llvm"
		-DLLVM_EXTERNAL_LIT="${EPREFIX}/usr/bin/lit"
		-DLLVM_LIT_ARGS="$(get_lit_flags)"
		-DPython3_EXECUTABLE="${PYTHON}"
	)

	cmake_src_configure
}

multilib_src_compile() {
	cmake_src_compile
}

multilib_src_test() {
	local -x LIT_PRESERVES_TMP=1
	cmake_build check-polly
}

multilib_src_install() {
	cmake_src_install
}
