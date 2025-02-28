Kaibo's dMRI pipeline
=====================

Dependencies
------------
* DIPY
* AMICO
* FSL
* FreeSurfer

You can install the dependencies by running the following command in a terminal:

    pip install dipy dmri-amico

For [FSL](https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FslInstallation.html) and [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall), please refer to their respective installation instructions.

Usage
-----
Before running the pipeline, organize your data in the following structure:

    data/
    ├── subid.nii
    ├── subid.bval
    ├── subid.bvec
    └── subid.json

where `subid.nii` is the dMRI data, `subid.bval` and `subid.bvec` are the b-values and b-vectors, and `subid.json` is the JSON file containing the acquisition parameters.

Then, run the pipeline with the following command:

    bash fit.sh data subid.nii subid.bval subid.bvec subid.json

The pipeline will output the following folders

    data/
    ├── dti/
    ├── dki/
    └── noddi/

where `dti/`, `dki/`, and `noddi/` contain the results of the DTI, DKI, and NODDI fits, respectively.

Internally, the pipeline performs the following steps:

1. Denoise using MP-PCA
2. Motion Correction using `eddy`
3. Skull stripping using `mri_synthstrip`
4. DTI, DKI fitting using DIPY and NODDI fitting using AMICO
