# BALROG Inference Baseline — Quick Start

## What This Does
Serves Qwen2.5-0.5B-Instruct with vLLM and runs BALROG's eval.py on BabyAI.
No Verlog, no PPO training, no parquet generation. Just inference.

## Why Start Here
1. Confirms BALROG + vLLM work on CHTC
2. Gets your zero-shot baseline numbers
3. 10x simpler than Verlog (no Ray trainer, no FSDP, no critic model)
4. Resource-light: 32GB RAM, 1 small GPU, ~30 min runtime

## Setup

### Step 1: Upload files to CHTC
```bash
scp balrog_eval.sh balrog_eval.sub nbag@ap2001.chtc.wisc.edu:~/Verlog/chtc/
```

### Step 2: Upload BALROG to staging (if not already there)
```bash
# On your Mac:
cd /path/to/repos
tar --exclude='.git' --no-xattrs -czvf BALROG.tar.gz BALROG
scp BALROG.tar.gz nbag@ap2001.chtc.wisc.edu:/staging/nbag/
```
If you don't have BALROG cloned, the script will install it from GitHub directly.

### Step 3: Submit
```bash
# On CHTC:
cd ~/Verlog/chtc
mkdir -p results/eval/logs
condor_submit balrog_eval.sub \
    results_dir=results/eval \
    log_dir=results/eval/logs \
    chtc_user=nbag
```

### Step 4: Monitor
```bash
condor_q
tail -f results/eval/logs/0.out
```

## Expected Output
BALROG will report per-task scores (0 or 100 for BabyAI) and an average.
A 0.5B model zero-shot will likely score low — that's fine, it's your baseline.

## After This Works
- Try Qwen2.5-1.5B-Instruct (change MODEL in the script)
- Add MiniHack: change envs="babyai" to envs="babyai,minihack"
  (requires fixing the NLE build — add `pip install cmake ninja` before BALROG install)
- Add your time-aware wrapper to BALROG's env code
- Eventually return to Verlog/verl for training once you have baselines

## Troubleshooting
- **BALROG install fails on NLE**: Expected. BabyAI doesn't need NLE.
  The script handles this gracefully.
- **vLLM server won't start**: Check 0.err for CUDA errors.
  Try reducing gpu-memory-utilization to 0.6.
- **eval.py not found**: BALROG may not be in the right directory.
  Check if the script found BALROG from staging or GitHub.
