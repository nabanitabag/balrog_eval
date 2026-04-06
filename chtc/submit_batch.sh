#!/bin/bash
source .env

results_dir=results/eval_2.5_1.5_B
log_dir=results/eval_2.5_1.5_B/logs

mkdir -p ${results_dir}/logs

condor_submit balrog_eval.sub results_dir=$results_dir log_dir=$log_dir chtc_user=${CHTC_USER}