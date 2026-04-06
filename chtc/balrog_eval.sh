#!/bin/bash
# =============================================================
# BALROG Inference Baseline on CHTC
# Serves Qwen2.5-0.5B with vLLM, evaluates on BabyAI via BALROG
# =============================================================
source .env
pid=$1

touch results_${pid}.tar.gz

export HOME=$_CONDOR_SCRATCH_DIR
export HF_HOME=$_CONDOR_SCRATCH_DIR/hf_home
export TRANSFORMERS_CACHE=$_CONDOR_SCRATCH_DIR/models
export CUDA_VISIBLE_DEVICES=0
export VLLM_USAGE_DISABLE=1
export USER=${CHTC_USER}

# ========================================
# 1. Install BALROG (skip NLE to avoid build failures)
# ========================================
echo "=== Installing BALROG ==="
pip install gymnasium minigrid

# Install BALROG from staging if available, otherwise from GitHub
if [ -f "/staging/${USER}/BALROG.tar.gz" ]; then
    cp "/staging/${USER}/BALROG.tar.gz" .
    tar -xzf BALROG.tar.gz && rm BALROG.tar.gz
    cd BALROG
    # Install without NLE/MiniHack to avoid C build failures
    pip install -e ".[babyai]" 2>/dev/null || pip install -e . --no-deps
    cd ..
else
    pip install git+https://github.com/balrog-ai/BALROG.git
fi

echo "=== BALROG installed ==="

# ========================================
# 2. Serve the model with vLLM (background)
# ========================================
MODEL=Qwen/Qwen2.5-1.5B-Instruct
PORT=8080

echo "=== Starting vLLM server for ${MODEL} ==="
vllm serve ${MODEL} \
    --port ${PORT} \
    --gpu-memory-utilization 0.9 \
    --max-model-len 16384 \
    --dtype auto &

VLLM_PID=$!

# Wait for server to be ready
echo "Waiting for vLLM server to start..."
for i in $(seq 1 120); do
    if curl -s http://127.0.0.1:${PORT}/health > /dev/null 2>&1; then
        echo "vLLM server ready after ${i}s"
        break
    fi
    if ! kill -0 $VLLM_PID 2>/dev/null; then
        echo "ERROR: vLLM server crashed during startup"
        wait $VLLM_PID
        exit 1
    fi
    sleep 1
done

# ========================================
# 3. Run BALROG evaluation on BabyAI
# ========================================
echo "=== Running BALROG eval on BabyAI ==="
cd BALROG 2>/dev/null || cd $HOME

# Bypass CHTC squid proxy for local connections
export no_proxy=localhost,127.0.0.1
export NO_PROXY=localhost,127.0.0.1

python eval.py \
    agent.type=naive \
    agent.max_image_history=0 \
    agent.max_text_history=16 \
    eval.num_workers=4 \
    client.client_name=vllm \
    client.model_id=${MODEL} \
    client.base_url=http://127.0.0.1:${PORT}/v1 \
    envs.names="babyai" \
    2>&1 | tee balrog_eval.log

EVAL_EXIT=$?
echo "=== Eval finished with exit code ${EVAL_EXIT} ==="

# ========================================
# 4. Package results
# ========================================
kill $VLLM_PID 2>/dev/null
wait $VLLM_PID 2>/dev/null

RESULTS_DIR=$(find $HOME -type d -name "results" -path "*/BALROG/*" 2>/dev/null | head -1)
EVAL_LOG=$(find $HOME -name "balrog_eval.log" 2>/dev/null | head -1)

echo "Results dir: $RESULTS_DIR"
echo "Eval log: $EVAL_LOG"

cd $HOME
tar -czvf results_${pid}.tar.gz \
    ${RESULTS_DIR:+$(basename $RESULTS_DIR --relative-to=$HOME)} \
    ${EVAL_LOG:+$(basename $EVAL_LOG)} \
    2>/dev/null

# Simplest approach: just tar everything we care about by name
find . -name "summary.json" -o -name "*.csv" -o -name "eval.log" -o -name "balrog_eval.log" | \
    tar -czvf results_${pid}.tar.gz -T -

touch results_${pid}.tar.gz
echo "=== Done ==="