# Round-3 reproduction commands

Run from a fresh MATLAB session with the clean project as the only user-code root:

```matlab
cd('D:\matlabfile\C1_PhysicalCommunication_Clean');
startup_C1;
addpath(fullfile(pwd,'c1_final_evidence_round3','experiments','ablation'));
addpath(fullfile(pwd,'c1_final_evidence_round3','experiments'));
runC1IndependentSeed20(pwd);
```

If a checkpoint exists after an interruption, resume it with:

```matlab
runC1IndependentSeed20(pwd, ...
    fullfile(pwd,'c1_final_evidence_round3','experiments','independent_seed_20261009'), ...
    struct('resume',true));
```

The runner creates `independent_seed_checkpoint.mat` after each physical packet and refuses to overwrite a nonempty output directory unless resume mode is explicit. It records the MATLAB version and SHA256 values of the round-3 estimator, packet builder, receiver, and metric functions.

This is a CPU-compatible MATLAB implementation. No GPU-specific code or parameter change is required; a GPU can only be used if the user later provides an independently verified acceleration path.
