#!/bin/bash

args=()

usage() {
    echo
    echo "Kaibo's dMRI pipeline"
    echo "Fits DTI, DKI, and NODDI"
    echo
    echo "Usage: $0 <folder> <image> <bvals> <bvecs> <json> [options] [-h]"
    echo
    echo "Options:"
    echo "  -h, --help"
    echo 
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

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            ;;
        *)
            args+=("$1")
            ;;
    esac
    shift
done

# original
folder=${args[0]}
image=${folder}/${args[1]}
bvals=${folder}/${args[2]}
bvecs=${folder}/${args[3]}
json=${folder}/${args[4]}

# derived
b0=${folder}/b0.nii
masked=${folder}/masked.nii
mask=${folder}/mask.nii
denoised=${folder}/denoised.nii
corrected=${folder}/corrected.nii
final_bvals=${folder}/final.bval
final_bvecs=${folder}/final.bvec
scheme=${folder}/final.scheme


# step 1: dwidenoise
step1() {
    dwidenoise ${image} ${denoised} -nthreads 16
}

# step 2: dwifslpreproc (assume no reversed phase encoding)
step2() {
    ped=$(jq -r ".PhaseEncodingDirection" ${json})
    trt=$(jq -r ".TotalReadoutTime" ${json} | awk '{print $1 / 2}')
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

echo 
echo "Step 1: dwidenoise"
time step1

echo
echo "Step 2: dwifslpreproc"
time step2

echo
echo "Step 3: mri_synthstrip"
time step3

echo
echo "Step 4a: DTI"
time step4a

echo
echo "Step 4b: DKI"
time step4b

echo
echo "Step 4c: NODDI"
time step4c
