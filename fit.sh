#!/bin/bash

set -e

usage() {
    echo "----------------------------------------------------------------------"
    echo "Kaibo's dMRI pipeline"
    echo "Fits DTI, DKI, and NODDI"
    echo
    echo "Usage: $0 <folder> <image> <bvals> <bvecs> <json> [options]"
    echo
    echo "Options:"
    echo "  -1           run step 1: dwidenoise"
    echo "  -2           run step 2: dwifslpreproc"
    echo "  -3           run step 3: mri_synthstrip"
    echo "  -4 model     run step 4: fit"
    echo "               expect model to be one of dti, dki, noddi, all"
    echo "  -h, --help"
    echo "----------------------------------------------------------------------"
    echo "Script written by:"
    echo "----------------------------------------------------------------------"
    echo "Kaibo Tang"
    echo "Department of Biostatistics"
    echo "University of North Carolina at Chapel Hill"
    echo "Contact: ktang@unc.edu"
    echo "----------------------------------------------------------------------"
    echo
    exit 0
}

if [ "$#" -lt 2 ]; then
    usage
fi

if [ "$#" -lt 5 ]; then
    echo "Error: missing arguments"
    usage
fi

# positional arguments
folder=$1
image=${folder}/$2
bvals=${folder}/$3
bvecs=${folder}/$4
json=${folder}/$5
shift 5

# flags
run_step1=false
run_step2=false
run_step3=false
run_step4=false

# model
model=""

while getopts '1234:h' opt; do
    case "$opt" in
        1)
            run_step1=true
            ;;
        2)
            run_step2=true
            ;;
        3)
            run_step3=true
            ;;
        4)
            run_step4=true
            if [ "$OPTARG" != "dti" ] && [ "$OPTARG" != "dki" ] && [ "$OPTARG" != "noddi" ] && [ "$OPTARG" != "all" ]; then
                echo "Error: unknown model"
                usage
            fi
            model="$OPTARG"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option: -$OPTARG"
            usage
            ;;
    esac
done

# derived
b0=${folder}/b0.nii
masked=${folder}/masked.nii
mask=${folder}/mask.nii
denoised=${folder}/denoised.nii
corrected=${folder}/corrected.nii
final_bvals=${folder}/final.bval
final_bvecs=${folder}/final.bvec
scheme=${folder}/final.scheme

# show configs
echo "----------------------------------------------------------------------"
echo "Original data"
echo "----------------------------------------------------------------------"
echo "Folder: ${folder}"
echo "Image: ${image}"
echo "b-values: ${bvals}"
echo "b-vectors: ${bvecs}"
echo "JSON: ${json}"
echo
echo "----------------------------------------------------------------------"
echo "Derived data"
echo "----------------------------------------------------------------------"
echo "Brain mask: ${mask}"
echo "Denoised image: ${denoised}"
echo "Corrected image: ${corrected}"
echo "Final b-values: ${final_bvals}"
echo "Final b-vectors: ${final_bvecs}"
echo "Acquisition scheme: ${scheme}"
echo
echo "----------------------------------------------------------------------"
echo "Pipeline"
echo "----------------------------------------------------------------------"
if ${run_step1}; then
    echo "-> Step 1: dwidenoise"
fi
if ${run_step2}; then
    echo "-> Step 2: dwifslpreproc"
fi
if ${run_step3}; then
    echo "-> Step 3: mri_synthstrip"
fi
if ${run_step4}; then
    echo "-> Step 4: fit"
    echo "   Model: ${model}"
fi
echo


# step 1: dwidenoise
step1() {
    dwidenoise ${image} ${denoised} -nthreads 16
}

# step 2: dwifslpreproc (assume no reversed phase encoding)
step2() {
    ped=$(jq -r ".PhaseEncodingDirection" ${json})
    trt=$(jq -r ".TotalReadoutTime" ${json} | awk '{print $1 / 2000}')
    if [ ${ped} == j- ]; then
        echo "Phase encoding direction: A->P"
    elif [ ${ped} == j ]; then
        echo "Phase encoding direction: P->A"
    elif [ ${ped} == i- ]; then
        echo "Phase encoding direction: L->R"
    elif [ ${ped} == i ]; then
        echo "Phase encoding direction: R->L"
    else
        echo "Unknown phase encoding direction"
        exit 1
    fi
    echo "Effective total readout time: ${trt} s"
    dwifslpreproc ${denoised} ${corrected} -rpe_none -pe_dir ${ped} -readout_time ${trt} -fslgrad ${bvecs} ${bvals} -export_grad_fsl ${final_bvecs} ${final_bvals} -eddy_options " --slm=linear" -nthreads 16 
}

# step 3: mri_synthstrip (assume first volume is b0)
step3() {
    fslroi ${image} ${b0} 0 1
    gunzip -c ${b0}.gz > ${b0}
    mri_synthstrip -i ${b0} -o ${masked} -m ${mask} -g > /dev/null
    rm ${b0}.gz ${b0} ${masked}
    fslmaths ${mask} -dilM ${mask}
}

# step 4a: DTI
step4a() {
    dti_path=${folder}/dti
    mkdir -p ${dti_path}
    dipy_fit_dti ${corrected} ${final_bvals} ${final_bvecs} ${mask} --save_metrics "fa" "md" "ad" "rd" "rgb" --out_dir ${folder}/dti
}

# step 4b: DKI
step4b() {
    dki_path=${folder}/dki
    mkdir -p ${dki_path}
    dipy_fit_dki ${corrected} ${final_bvals} ${final_bvecs} ${mask} --save_metrics "fa" "md" "ad" "rd" "mk" "ak" "rk" "rgb" --out_dir ${folder}/dki
}

# step 4c: NODDI
step4c() {
    noddi_path=${folder}/noddi
    mkdir -p ${noddi_path}
    python ./noddi.py ${noddi_path} ${corrected} ${final_bvals} ${final_bvecs} ${mask} ${scheme}
    rm -r ${scheme} ${folder}/kernels
}

echo "----------------------------------------------------------------------"
echo Run
echo "----------------------------------------------------------------------"
if ${run_step1}; then
    echo "-> Step 1: dwidenoise"
    step1
    echo
fi

if ${run_step2}; then
    echo "-> Step 2: dwifslpreproc"
    step2
    echo
fi

if ${run_step3}; then
    echo "-> Step 3: mri_synthstrip"
    step3
    echo
fi

if ${run_step4}; then
    echo "-> Step 4: fit"
    if [ "${model}" == "dti" ]; then
        echo "   Model: dti"
        step4a
        echo
    elif [ "${model}" == "dki" ]; then
        echo "   Model: dki"
        step4b
        echo
    elif [ "${model}" == "noddi" ]; then
        echo "   Model: noddi"
        step4c
        echo
    elif [ "${model}" == "all" ]; then
        echo "   Model: dti"
        step4a
        echo
        echo "   Model: dki"
        step4b
        echo
        echo "   Model: noddi"
        step4c
        echo
    fi
fi
