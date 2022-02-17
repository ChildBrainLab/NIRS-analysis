# NIRS-analysis

# EmoGrow DBDOS Neural Synchrony
## About
This repository contains the scripts for the EmoGrow DBDOS neural synchrony analysis. Everything is included in the `run_analysis_*` scripts. Here are some things to note:

* Dependencies: [nirs-toolbox](https://bitbucket.org/huppertt/nirs-toolbox/src/default/), [nirs-toolbox-addons](https://bitbucket.org/lcbd/nirs-toolbox-addons/src/master/), [EmoGrow](https://bitbucket.org/lcbd/emogrow/src/master/)

* Configuration of paths to NIRS/demographics data is specified on the first few lines of the `run_analysis_*` scripts.

* The script was tested on revision 783 (02/19/19) of nirs-toolbox

* The script saves the output of each step, so several GB of disk space will be used. You can disable this by commenting out specific calls to `save`.

* The analysis uses the `nirs.sFC.ar_corr_full` function from `nirs-toolbox-addons` repository. This function performs the full robust correlation, rather than the pseudo-robust correlation used in `nirs.sFC.ar_corr`. It also skips the outlier downweighting since we're already doing motion correction during preprocessing.

* Skipping probe registration will not effect the figures, but it will numerically change the results of the Beer-Lambert Law (due to source-detector distances changing). So do not skip probe registration.

