import amico
import sys


if __name__ == "__main__":
    folder = sys.argv[1]
    image = sys.argv[2]
    bvals = sys.argv[3]
    bvecs = sys.argv[4]
    mask = sys.argv[5]
    scheme = sys.argv[6]

    amico.setup()
    ae = amico.Evaluation(output_path=folder)
    ae.set_config('DTI_fit_method', 'WLS')
    amico.util.fsl2scheme(bvals, bvecs, scheme)
    ae.load_data(image, scheme, mask)
    ae.set_model("NODDI")
    ae.generate_kernels(regenerate=True)
    ae.load_kernels()
    ae.fit()
    ae.save_results()
