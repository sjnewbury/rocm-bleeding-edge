# Copyright 2021 Haelwenn (lanodan) Monnier <contact@hacktivis.me>
# Distributed under the terms of the GNU General Public License v2

EAPI=7

ROCM_VERSION=5.4.2

inherit llvm cmake rocm

CPUINFO_COMMIT=5916273f79a21551890fd3d56fc5375a78d1598d
#ONNX_COMMIT=5a5f8a5935762397aa68429b5493084ff970f774
MP11_COMMIT=21cace4e574180ba64d9307a5e4ea9e5e94d3e8d
OPTIONAL_LITE_COMMIT=4acf4553baa886e10e6613fe1452b706b0250e78
SAFEINT_COMMIT=ff15c6ada150a5018c5ef2172401cb4529eac9c0
FLATBUFFERS_PV=1.12.0
NSYNC_PV=1.25.0
DESCRIPTION="cross-platform, high performance ML inferencing and training accelerator"
HOMEPAGE="https://github.com/microsoft/onnxruntime"
SRC_URI="
	https://github.com/microsoft/${PN}/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/pytorch/cpuinfo/archive/${CPUINFO_COMMIT}.tar.gz -> pytorch-cpuinfo-${CPUINFO_COMMIT:0:10}.tar.gz
	https://github.com/boostorg/mp11/archive/${MP11_COMMIT}.tar.gz -> boost_mp11-${MP11_COMMIT:0:11}.tar.gz
	https://github.com/google/flatbuffers/archive/v${FLATBUFFERS_PV}.tar.gz -> flatbuffers-${FLATBUFFERS_PV}.tar.gz
	https://github.com/dcleblanc/SafeInt/archive/${SAFEINT_COMMIT}.tar.gz -> SafeInt-${SAFEINT_COMMIT:0:10}.tar.gz
	https://github.com/google/nsync/archive/refs/tags/${NSYNC_PV}.tar.gz -> nsync-${NSYNC_PV}.tar.gz
"
#	https://github.com/onnx/onnx/archive/${ONNX_COMMIT}.tar.gz -> onnx-${ONNX_COMMIT:0:10}.tar.gz
#	https://github.com/martinmoene/optional-lite/archive/${OPTIONAL_LITE_COMMIT}.tar.gz -> optional-lite-${OPTIONAL_LITE_COMMIT:0:10}.tar.gz

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="benchmark test rocm"

RESTRICT="test"

PATCHES=(
	"${FILESDIR}/shared-flatbuffers.patch"
	"${FILESDIR}/re2-pkg-config.patch"
	"${FILESDIR}/no-system-flatbuffers.patch"
	"${FILESDIR}/system-onnx.patch"
	"${FILESDIR}/rocm-version-override-r1.patch"
)

S="${WORKDIR}/${P}/cmake"

# Needs https://gitlab.com/libeigen/eigen/-/commit/d0e3791b1a0e2db9edd5f1d1befdb2ac5a40efe0.patch on eigen-3.4.0
RDEPEND="
	dev-python/numpy
	dev-libs/date:=
	>=dev-libs/boost-1.66:=
	dev-libs/protobuf:=
	dev-libs/re2:=
	dev-cpp/nlohmann_json:=
	dev-libs/nsync
	dev-cpp/eigen:3
	benchmark? ( dev-cpp/benchmark )
	sci-libs/onnx:=
"
#	dev-libs/flatbuffers:=

DEPEND="
	${RDEPEND}
	test? ( dev-cpp/gtest )
	rocm? (
		>=dev-libs/rocr-runtime-${ROCM_VERSION}:=
		>=dev-util/hip-${ROCM_VERSION}:=
		>=dev-libs/rccl-${ROCM_VERSION}:=
		>=sci-libs/miopen-${ROCM_VERSION}:=
		>=dev-util/roctracer-${ROCM_VERSION}:=
	)
"

src_prepare() {
	pushd ..
	eapply "${FILESDIR}/13799.patch"
	eapply "${FILESDIR}/shared-build-fix.patch"
	eapply 	"${FILESDIR}/use-hip-language.patch"
	eapply 	"${FILESDIR}/hipify-during-build.patch"
	eapply 	"${FILESDIR}/rocm-warn-and-dev.patch"
	eapply 	"${FILESDIR}/drop-hip_add_library.patch"
	popd

	cmake_src_prepare

	rm -r "${S}/external/pytorch_cpuinfo" || die
	mv "${WORKDIR}/cpuinfo-${CPUINFO_COMMIT}" "${S}/external/pytorch_cpuinfo" || die

	#rm -r "${S}/external/onnx" || die
	#mv "${WORKDIR}/onnx-${ONNX_COMMIT}" "${S}/external/onnx" || die

	rm -r "${S}/external/mp11" || die
	mv "${WORKDIR}/mp11-${MP11_COMMIT}" "${S}/external/mp11" || die

	rm -r "${S}/external/flatbuffers" || die
	mv "${WORKDIR}/flatbuffers-${FLATBUFFERS_PV}" "${S}/external/flatbuffers" || die

	#rm -r "${S}/external/optional-lite" || die
	#mv "${WORKDIR}/optional-lite-${OPTIONAL_LITE_COMMIT}" "${S}/external/optional-lite" || die

	rm -r "${S}/external/SafeInt/safeint" || die
	mv "${WORKDIR}/SafeInt-${SAFEINT_COMMIT}" "${S}/external/SafeInt/safeint" || die

	rm -r "${S}/external/nsync" || die
	mv "${WORKDIR}/nsync-${NSYNC_PV}" "${S}/external/nsync" || die
}

src_configure() {
	append-cppflags "-I/usr/include/eigen3"

	filter-flags -flto*

	export ROCM_PATH=/usr
	export ROCM_VERSIONERSION=$(($(ver_cut 1 ${ROCM_VERSION})*10000 + $(ver_cut 2 ${ROCM_VERSION})*100 + $(ver_cut 3 ${ROCM_VERSION})))

	local mycmakeargs=(
		-Donnxruntime_PREFER_SYSTEM_LIB=ON
		-Donnxruntime_BUILD_BENCHMARKS=$(usex benchmark)
		-Donnxruntime_BUILD_UNIT_TESTS=$(usex test)
		-DFETCHCONTENT_FULLY_DISCONNECTED=ON
		-DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS
		-Donnxruntime_USE_TENSORRT=OFF
		-Donnxruntime_USE_CUDA=OFF
		-Donnxruntime_USE_ROCM=$(usex rocm ON OFF)
		-Donnxruntime_DISABLE_ABSEIL=ON
		-Donnxruntime_BUILD_FOR_NATIVE_MACHINE=ON
		-Donnxruntime_BUILD_SHARED_LIB=ON
		-DCMAKE_HIP_COMPILER=$(get_llvm_prefix)/bin/clang++
	)

	cmake_src_configure
}
