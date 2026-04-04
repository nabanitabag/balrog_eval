#!/bin/bash
# Transfer balrog-eval files to CHTC
# Run from: balrog-eval/ (the project root)
source .env

USER=${CHTC_USER}
HOSTNAME="ap2001.chtc.wisc.edu"

if [ -z "$USER" ]; then
    echo "ERROR: CHTC_USER not set. Check your .env file."
    exit 1
fi

# Establish persistent SSH connection (one Duo push for everything)
echo "Establishing SSH connection..."
ssh -o ControlMaster=auto \
    -o ControlPath=~/.ssh/control-%r@%h:%p \
    -o ControlPersist=10m \
    -fN ${USER}@${HOSTNAME}

SSH_OPTS="-o ControlPath=~/.ssh/control-%r@%h:%p"

# ============================================
# 1. Package and upload BALROG to staging
# ============================================
if [ -d "../BALROG" ]; then
    echo "=== Packaging BALROG ==="
    tar --exclude='.git' --no-xattrs -czvf /tmp/BALROG.tar.gz -C .. BALROG
    echo "=== Uploading BALROG to staging ==="
    scp ${SSH_OPTS} /tmp/BALROG.tar.gz ${USER}@${HOSTNAME}:/staging/${USER}/
    rm /tmp/BALROG.tar.gz
else
    echo "WARNING: ../BALROG not found — skipping staging upload."
    echo "  The eval script will install BALROG from GitHub instead."
fi

# ============================================
# 2. Create project directory and sync files
# ============================================
echo "=== Creating balrog-eval directory on CHTC ==="
ssh ${SSH_OPTS} ${USER}@${HOSTNAME} "mkdir -p ~/balrog-eval/results/eval/logs"

echo "=== Uploading project files ==="
rsync -avz -e "ssh ${SSH_OPTS}" \
    --include='.env' \
    --include='balrog_eval.sh' \
    --include='balrog_eval.sub' \
    --exclude='*' \
    ./ ${USER}@${HOSTNAME}:~/balrog-eval/

# ============================================
# 3. Upload data.tar.gz if it exists
# ============================================
if [ -f ~/data.tar.gz ]; then
    echo "=== Uploading data.tar.gz ==="
    scp ${SSH_OPTS} ~/data.tar.gz ${USER}@${HOSTNAME}:~/
fi

# Close SSH connection
ssh -O exit ${SSH_OPTS} ${USER}@${HOSTNAME} 2>/dev/null

echo ""
echo "============================================"
echo "Done! Transferred at $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "Next steps on CHTC:"
echo "  ssh ${USER}@${HOSTNAME}"
echo "  cd ~/balrog-eval"
echo "  condor_submit balrog_eval.sub results_dir=results/eval log_dir=results/eval/logs chtc_user=${USER}"
echo "============================================"