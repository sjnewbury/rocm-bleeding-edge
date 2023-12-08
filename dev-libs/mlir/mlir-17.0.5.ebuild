# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

ROCM_VERSION=5.7.1

PYTHON_COMPAT=( python3_{8..11} )
inherit rocm cuda cmake-multilib llvm llvm.org python-any-r1

DESCRIPTION="Multi-Level Intermediate Representation (library only)"
HOMEPAGE="https://mlir.llvm.org/"

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="${LLVM_MAJOR}/${LLVM_SOABI}"
KEYWORDS=""
IUSE="debug test cuda rocm vulkan spirv"
RESTRICT="!test? ( test )"

DEPEND="
	~sys-devel/llvm-${PV}:${LLVM_MAJOR}=[debug=,${MULTILIB_USEDEP}]
	dev-util/hip
	vulkan? ( media-libs/vulkan-loader[${MULTILIB_USEDEP}] )
	spirv? ( dev-util/glslang[${MULTILIB_USEDEP}] )
	$(python_gen_any_dep '
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/pybind11[${PYTHON_USEDEP}]
	')
"
RDEPEND="
	${DEPEND}
"
BDEPEND="
	${PYTHON_DEPS}
	>=dev-util/cmake-3.16
"

LLVM_COMPONENTS=( mlir cmake )
LLVM_TEST_COMPONENTS=( llvm/{include,utils/unittest} )
llvm.org_set_globals

pkg_setup() {
	LLVM_MAX_SLOT=${LLVM_MAJOR} llvm_pkg_setup
	python-any-r1_pkg_setup
	export ROCM_PATH=/usr
}

python_check_deps() {
	python_has_version "dev-python/numpy[${PYTHON_USEDEP}]"
}

check_distribution_components() {
	if [[ ${CMAKE_MAKEFILE_GENERATOR} == ninja ]]; then
		local all_targets=() my_targets=() l
		cd "${BUILD_DIR}" || die

		while read -r l; do
			if [[ ${l} == install-*-stripped:* ]]; then
				l=${l#install-}
				l=${l%%-stripped*}

				case ${l} in
					# meta-targets
					mlir-libraries|distribution)
						continue
						;;
					# static libraries
					MLIR*)
						continue
						;;
				esac

				all_targets+=( "${l}" )
			fi
		done < <(${NINJA} -t targets all)

		while read -r l; do
			my_targets+=( "${l}" )
		done < <(get_distribution_components $"\n")

		local add=() remove=()
		for l in "${all_targets[@]}"; do
			if ! has "${l}" "${my_targets[@]}"; then
				add+=( "${l}" )
			fi
		done
		for l in "${my_targets[@]}"; do
			if ! has "${l}" "${all_targets[@]}"; then
				remove+=( "${l}" )
			fi
		done

		if [[ ${#add[@]} -gt 0 || ${#remove[@]} -gt 0 ]]; then
			eqawarn "get_distribution_components() is outdated!"
			eqawarn "   Add: ${add[*]}"
			eqawarn "Remove: ${remove[*]}"
		fi
		cd - >/dev/null || die
	fi
}

get_distribution_components() {
	local sep=${1-;}
	local vulkan_deps=(
		MLIRGPUToVulkanTransforms
	)
	local spirv_deps=(
		MLIRArithToSPIRV
		MLIRComplexToSPIRV
		MLIRControlFlowToSPIRV
		MLIRFuncToSPIRV
		MLIRGPUToSPIRV
		MLIRMathToSPIRV
		MLIRMemRefToSPIRV
		MLIRSCFToSPIRV
		MLIRSPIRVToLLVM
		MLIRTensorToSPIRV
		MLIRUBToSPIRV
		MLIRVectorToSPIRV
		MLIRSPIRVDialect
		MLIRSPIRVModuleCombiner
		MLIRSPIRVConversion
		MLIRSPIRVTransforms
		MLIRSPIRVUtils
		MLIRSPIRVDeserialization
		MLIRSPIRVSerialization
		MLIRSPIRVBinaryUtils
		MLIRSPIRVTranslateRegistration
	)
	local unsorted_deps=(
		MLIRSparseTensorRuntime
		MLIRSparseTensorEnums

		# required by MLIR-C (TODO: split out according to USEflags)
		MLIRSupport
		MLIRArithDialect
		MLIRAsyncDialect
		MLIRAsyncTransforms
		MLIRPass
		MLIRControlFlowDialect
		MLIRMathDialect
		MLIRMemRefDialect
		MLIRGPUTransforms
		MLIRLLVMDialect
		MLIRLinalgDialect
		MLIRLinalgTransforms
		MLIRMLProgramDialect
		MLIRSCFDialect
		MLIRShapeDialect
		MLIRSparseTensorDialect
		MLIRSparseTensorTransforms
		MLIRFuncDialect
		MLIRTensorDialect
		MLIRTransformDialect
		MLIRQuantDialect
		MLIRPDLDialect
		MLIRVectorDialect
		MLIRAffineToStandard
		MLIRAMDGPUToROCDL
		MLIRArithAttrToLLVMConversion
		MLIRArithToLLVM
		MLIRArmNeon2dToIntr
		MLIRAsyncToLLVM
		MLIRBufferizationToMemRef
		MLIRComplexToLibm
		MLIRComplexToLLVM
		MLIRComplexToStandard
		MLIRControlFlowToLLVM
		MLIRFuncToLLVM
		MLIRGPUToGPURuntimeTransforms
		MLIRGPUToNVVMTransforms
		MLIRGPUToROCDLTransforms
		MLIRIndexToLLVM
		MLIRLinalgToLLVM
		MLIRLinalgToStandard
		MLIRLLVMCommonConversion
		MLIRMathToFuncs
		MLIRMathToLibm
		MLIRMathToLLVM
		MLIRMemRefToLLVM
		MLIRNVGPUToNVVM
		MLIRNVVMToLLVM
		MLIROpenACCToSCF
		MLIROpenMPToLLVM
		MLIRPDLToPDLInterp
		MLIRReconcileUnrealizedCasts
		MLIRSCFToControlFlow
		MLIRSCFToGPU
		MLIRSCFToOpenMP
		MLIRShapeToStandard
		MLIRTensorToLinalg
		MLIRTosaToArith
		MLIRTosaToLinalg
		MLIRTosaToSCF
		MLIRTosaToTensor
		MLIRUBToLLVM
		MLIRVectorToArmSME
		MLIRVectorToGPU
		MLIRVectorToLLVM
		MLIRVectorToSCF
		MLIRInferTypeOpInterface
		MLIRBytecodeWriter
		MLIRIR
		MLIRParser
		MLIRAffineAnalysis
		MLIRAffineDialect
		MLIRAffineTransforms
		MLIRAffineTransformOps
		MLIRAffineUtils
		MLIRAMDGPUDialect
		MLIRAMDGPUTransforms
		MLIRAMDGPUUtils
		MLIRAMXDialect
		MLIRAMXTransforms
		MLIRArithValueBoundsOpInterfaceImpl
		MLIRArithTransforms
		MLIRArithUtils
		MLIRArmNeonDialect
		MLIRArmSMEDialect
		MLIRArmSMETransforms
		MLIRArmSMEUtils
		MLIRArmSVEDialect
		MLIRArmSVETransforms
		MLIRBufferizationDialect
		MLIRBufferizationTransformOps
		MLIRBufferizationTransforms
		MLIRComplexDialect
		MLIRDLTIDialect
		MLIREmitCDialect
		MLIRFuncTransforms
		MLIRGPUDialect
		MLIRGPUTransformOps
		MLIRIndexDialect
		MLIRIRDL
		MLIRLinalgTransformOps
		MLIRLinalgUtils
		MLIRLLVMIRTransforms
		MLIRNVVMDialect
		MLIRROCDLDialect
		MLIRMathTransforms
		MLIRMemRefTransformOps
		MLIRMemRefTransforms
		MLIRMemRefUtils
		MLIRNVGPUDialect
		MLIRNVGPUUtils
		MLIRNVGPUTransformOps
		MLIRNVGPUTransforms
		MLIROpenACCDialect
		MLIROpenMPDialect
		MLIRPDLInterpDialect
		MLIRQuantUtils
		MLIRSCFTransformOps
		MLIRSCFTransforms
		MLIRSCFUtils
		MLIRShapeOpsTransforms
		MLIRSparseTensorPipelines
		MLIRSparseTensorUtils
		MLIRTensorInferTypeOpInterfaceImpl
		MLIRTensorTilingInterfaceImpl
		MLIRTensorTransforms
		MLIRTensorTransformOps
		MLIRTensorUtils
		MLIRTosaDialect
		MLIRTosaTransforms
		MLIRTransformPDLExtension
		MLIRTransformDialectTransforms
		MLIRTransformDialectUtils
		MLIRUBDialect
		MLIRVectorTransforms
		MLIRVectorTransformOps
		MLIRVectorUtils
		MLIRX86VectorDialect
		MLIRX86VectorTransforms
		MLIRTargetCpp
		MLIRArmNeonToLLVMIRTranslation
		MLIRArmSMEToLLVMIRTranslation
		MLIRArmSVEToLLVMIRTranslation
		MLIRAMXToLLVMIRTranslation
		MLIRBuiltinToLLVMIRTranslation
		MLIRGPUToLLVMIRTranslation
		MLIRLLVMIRToLLVMTranslation
		MLIRLLVMToLLVMIRTranslation
		MLIRNVVMToLLVMIRTranslation
		MLIROpenACCToLLVMIRTranslation
		MLIROpenMPToLLVMIRTranslation
		MLIRROCDLToLLVMIRTranslation
		MLIRX86VectorToLLVMIRTranslation
		MLIRTargetLLVMIRExport
		MLIRToLLVMIRTranslationRegistration
		MLIRTargetLLVMIRImport
		MLIRFromLLVMIRTranslationRegistration
		MLIRFuncInlinerExtension
		MLIRFuncAllExtensions
		MLIRTransforms
		MLIRExecutionEngine

		# Dependencies of above libraries
		MLIRAnalysis
		MLIRAsmParser
		MLIRBytecodeOpInterface
		MLIRBytecodeReader
		MLIRCallInterfaces
		MLIRCastInterfaces
		MLIRControlFlowInterfaces
		MLIRCopyOpInterface
		MLIRDataLayoutInterfaces
		MLIRDestinationStyleOpInterface
		MLIRDialect
		MLIRDialectUtils
		MLIRExecutionEngineUtils
		MLIRInferIntRangeCommon
		MLIRInferIntRangeInterface
		MLIRLoopLikeInterface
		MLIRMaskableOpInterface
		MLIRMaskingOpInterface
		MLIRMemorySlotInterfaces
		MLIRParallelCombiningOpInterface
		MLIRPresburger
		MLIRRewrite
		MLIRRuntimeVerifiableOpInterface
		MLIRShapedOpInterfaces
		MLIRSideEffectInterfaces
		MLIRTilingInterface
		MLIRTransformUtils
		MLIRTranslateLib
		MLIRValueBoundsOpInterface
		MLIRVectorInterfaces
		MLIRViewLikeInterface
	)

	local out=(
		mlir-cmake-exports
		mlir-headers

		# shared libs
		MLIR-C
		mlir_async_runtime
		mlir_c_runner_utils
		mlir_float16_utils
		mlir_runner_utils

		${vulkan_deps[@]}
		${spirv_deps[@]}
		${unsorted_deps[@]}
		
		# tools
		mlir-cpu-runner
		mlir-linalg-ods-yaml-gen
		mlir-lsp-server
		mlir-opt
		mlir-pdll-lsp-server
		mlir-reduce mlir-translate
		tblgen-lsp-server

		# required libraries for tools
		MLIRJitRunner
		MLIRLspServerLib
		MLIRLspServerSupportLib
		MLIROptLib
		MLIRDebug
		MLIRObservers
		MLIRPluginsLib

		# utilities
		mlir-pdll
		mlir-tblgen

		# required libraries for utilities
		MLIRPDLLAST
		MLIRPDLLCodeGen
		MLIRPDLLODS
	)

	printf "%s${sep}" "${out[@]}"
}

multilib_src_configure() {
	local mycmakeargs=(
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr/lib/llvm/${LLVM_MAJOR}"
		-DAMDGPU_TARGETS="$(get_amdgpu_flags)"
		-DBUILD_SHARED_LIBS=ON
		-DMLIR_BUILD_MLIR_C_DYLIB=ON
		-DMLIR_LINK_MLIR_DYLIB=ON
		-DMLIR_INCLUDE_TESTS=$(usex test)
		-DLLVM_DISTRIBUTION_COMPONENTS=$(get_distribution_components)
		# this enables installing mlir-tblgen and mlir-pdll
		-DLLVM_BUILD_UTILS=ON

		-DPython3_EXECUTABLE="${PYTHON}"

		# tools are skipped for now, until upstream updates dylib API
		# to allow dynamic linking, see:
		# https://discourse.llvm.org/t/trying-to-get-mlir-link-mlir-dylib-implemented/66086
		-DLLVM_BUILD_TOOLS=ON
		-DMLIR_ENABLE_CUDA_RUNNER=$(usex cuda ON OFF)
		-DMLIR_ENABLE_ROCM_RUNNER=$(usex rocm ON OFF)
		-DMLIR_ENABLE_SPIRV_CPU_RUNNER=$(usex spirv ON OFF)
		-DMLIR_ENABLE_VULKAN_RUNNER=$(usex vulkan ON OFF)
		-DMLIR_ENABLE_BINDINGS_PYTHON=ON
		-DMLIR_INSTALL_AGGREGATE_OBJECTS=ON
	)
	use test && mycmakeargs+=(
		-DLLVM_EXTERNAL_LIT="${EPREFIX}/usr/bin/lit"
		-DLLVM_LIT_ARGS="$(get_lit_flags)"
	)

	# LLVM_ENABLE_ASSERTIONS=NO does not guarantee this for us, #614844
	use debug || local -x CPPFLAGS="${CPPFLAGS} -DNDEBUG"
	cmake_src_configure

	# we currently don't install all available components
	#check_distribution_components
}

multilib_src_compile() {
	cmake_build distribution
}

multilib_src_test() {
	# respect TMPDIR!
	local -x LIT_PRESERVES_TMP=1
	cmake_build check-mlir
}

multilib_src_install() {
	DESTDIR=${D} cmake_build install-distribution
}
