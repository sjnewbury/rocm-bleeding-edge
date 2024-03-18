# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION=${PV}
LLVM_MAX_SLOT="17"

inherit cmake edo llvm rocm

DESCRIPTION="AMD ROCm Performance Primitives (RPP) library is a comprehensive high-performance computer vision library"
HOMEPAGE="https://github.com/ROCm/rpp"
SRC_URI="https://github.com/ROCm/rpp/archive/rocm-${PV}.tar.gz -> rpp-${PV}.tar.gz"

LICENSE="BSD"
KEYWORDS="~amd64"
SLOT="0/$(ver_cut 1-2)"

IUSE="test benchmark"
REQUIRED_USE="${ROCM_REQUIRED_USE}"

RDEPEND="
	dev-util/hip
	dev-util/hipcc
	dev-libs/half
"
DEPEND="${RDEPEND}"
BDEPEND="test? ( dev-cpp/gtest
	>=dev-build/cmake-3.22
	)
"

RESTRICT="!test? ( test )"

S=${WORKDIR}/${PN}-rocm-${PV}

pkg_setup() {
	export CC="$(get_llvm_prefix)/bin/clang" CXX="$(get_llvm_prefix)/bin/clang++"
	tc-is-clang || die Clang required
	strip-unsupported-flags
}

src_prepare() {
	cmake_src_prepare
	# Use system LLVM
	sed 	-e "s:\${ROCM_PATH}/llvm:$(get_llvm_prefix):g" \
		-e '/set(/s/-mavx2 -mf16c -mfma //' \
		-i CMakeLists.txt || die

	sed 	-e '/#include/s/half\/\(half\.hpp\)/\1/' \
		-e '/define __AVX2__/d' \
		-i $(find ${S} -type f -name '*.hpp') || die
}

src_configure() {
	# avoid sandbox violation
	addpredict /dev/kfd
	addpredict /dev/dri/

	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=On
		-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		-Wno-dev
		-DROCM_PATH=/usr
		-DBACKEND=HIP
		-DBUILD_WITH_AMD_ADVANCE=OFF
	)

	cmake_src_configure
}

src_test() {
	check_amdgpu
	cd "${BUILD_DIR}"/clients/staging || die
	LD_LIBRARY_PATH="${BUILD_DIR}/library/src" edob ./rpp-test
}

src_install() {
	cmake_src_install

	if use benchmark; then
		cd "${BUILD_DIR}" || die
		dobin clients/staging/rpp-bench
	fi
}
