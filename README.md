Kaibo's dMRI pipeline
=====================


Dependencies
------------
* DIPY
* AMICO
* FSL
* FreeSurfer
* jq

You can install the dependencies by running the following command in a terminal:
```bash
pip install dipy dmri-amico
```

For [FSL](https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FslInstallation.html) and [FreeSurfer](https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall), please refer to their respective installation instructions.

To install `jq`, run the following command:
```bash
sudo apt-get install jq
```

or
```bash
brew install jq
```


Usage
-----

    ----------------------------------------------------------------------
    Kaibo's dMRI pipeline
    Fits DTI, DKI, and NODDI

    Usage: ./fit.sh <folder> <image> <bvals> <bvecs> <json> [options]

    Options:
    -1           run step 1: dwidenoise
    -2           run step 2: dwifslpreproc
    -3           run step 3: mri_synthstrip
    -4 model     run step 4: fit
                expect model to be one of dti, dki, noddi, all
    -h, --help
    ----------------------------------------------------------------------
    Script written by:
    ----------------------------------------------------------------------
    Kaibo Tang
    Department of Biostatistics
    University of North Carolina at Chapel Hill
    Contact: ktang@unc.edu
    ----------------------------------------------------------------------

Before running the pipeline, organize your data in the following structure:

    data/
    ├── subid.nii
    ├── subid.bval
    ├── subid.bvec
    └── subid.json

where `subid.nii` is the dMRI data, `subid.bval` and `subid.bvec` are the b-values and b-vectors, and `subid.json` is the JSON file containing the acquisition parameters.

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


Example
-------
To run the full pipeline and fit all models, run the following command:
```bash
bash ./fit.sh data subid.nii subid.bval subid.bvec subid.json -1234 all
```

To only run denoising, motion correction, and skull stripping, run the following command:
```bash
bash ./fit.sh data subid.nii subid.bval subid.bvec subid.json -123
```

To only fit the DTI model, run the following command:
```bash
bash ./fit.sh data subid.nii subid.bval subid.bvec subid.json -4 dti
```
