# Copyright (c) 2023 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

MODEL_DIR=${MODEL_DIR-$PWD}
if [ ! -e "${MODEL_DIR}/models/recommendation/pytorch/torchrec_dlrm/dlrm_main.py"  ]; then
    echo "Could not find the script of dlrm_s_pytorch.py. Please set environment variable '\${MODEL_DIR}'."
    echo "From which the dlrm_s_pytorch.py exist at the: \${MODEL_DIR}/models/recommendation/pytorch/torchrec_dlrm/dlrm_main.py"
    exit 1
fi
MODEL_SCRIPT=${MODEL_DIR}/models/recommendation/pytorch/torchrec_dlrm/dlrm_main.py

echo "PRECISION: ${PRECISION}"
echo "OUTPUT_DIR: ${OUTPUT_DIR}"

if [ -z "${OUTPUT_DIR}" ]; then
  echo "The required environment variable OUTPUT_DIR has not been set"
  exit 1
fi

# Create the output directory in case it doesn't already exist
mkdir -p ${OUTPUT_DIR}
LOG=${OUTPUT_DIR}/dlrm_training_performance_log/${PRECISION}
rm -rf ${LOG}
mkdir -p ${LOG}

ARGS=""
if [[ $PRECISION == "bf16" ]]; then
    ARGS="$ARGS --dtype bf16"
    echo "running bf16 path"
elif [[ $PRECISION == "fp32" ]]; then
    echo "running fp32 path"
    ARGS="$ARGS --dtype fp32"
elif [[ $PRECISION == "bf32" ]]; then
    echo "running bf32 path"
    ARGS="$ARGS --dtype bf32"
elif [[ $PRECISION == "fp16" ]]; then
    echo "running fp16 path"
    ARGS="$ARGS --dtype fp16"
else
    echo "The specified PRECISION '${PRECISION}' is unsupported."
    echo "Supported PRECISIONs are: fp32, bf32, fp16, bf16"
    exit 1
fi

if [[ $ENABLE_TORCH_PROFILE == "true" ]]; then
  ARGS="$ARGS --profile"
fi

BATCH_SIZE=${BATCH_SIZE:-5120}
if [[ $DIST == "1" ]]; then
  source ${MODEL_DIR}/quickstart/recommendation/pytorch/torchrec_dlrm/training/cpu/distributed_setup.sh
  launcher_arg=$launcher_dist_args
  ARGS="$ARGS --ipex-dist-merged-emb-adagrad --distributed-training "
  BATCH_SIZE=`expr $BATCH_SIZE \* 3`
else
  NODE_LIST=${NODE_LIST:-"0"}
  launcher_arg=" --nodes-list $NODE_LIST "
  ARGS="$ARGS --ipex-merged-emb-adagrad"
fi

export launcher_cmd="-m intel_extension_for_pytorch.cpu.launch --enable_tcmalloc ${launcher_arg}"
if [[ $PLOTMEM == "true" ]]; then
pip install memory_profiler matplotlib
export mrun_cmd="mprof run --python -o ${MEMLOG}"
unset launcher_arg
fi

if [[ $CONVERGENCE == "1" ]]; then
  export TOTAL_TRAINING_SAMPLES=4195197692
  export VAL_FREQ=$((TOTAL_TRAINING_SAMPLES / (BATCH_SIZE * 20)))
  ARGS="$ARGS --validation_auroc 0.80275 --validation_freq_within_epoch $VAL_FREQ --log-freq 100 --print_progress "
  if [ -z "${ONE_HOT_DATASET_DIR}" ]; then
    echo "CONVERGENCE test need set ONE_HOT_DATASET_DIR"
    exit 1
  fi
else
 ARGS="$ARGS --limit_train_batches 300 --log-freq 10 "
fi

COMMON_ARGS=" --embedding_dim 128 \
              --dense_arch_layer_sizes 512,256,128 \
              --over_arch_layer_sizes 1024,1024,512,256,1 \
              --num_embeddings_per_feature 40000000,39060,17295,7424,20265,3,7122,1543,63,40000000,3067956,405282,10,2209,11938,155,4,976,14,40000000,40000000,40000000,590152,12973,108,36 \
              --epochs 1 \
              --pin_memory \
              --mmap_mode \
              --batch_size $BATCH_SIZE \
              --interaction_type=dcn \
              --dcn_num_layers=3 \
              --dcn_low_rank_dim=512 \
              --adagrad \
              --learning_rate 0.004 \
              --multi_hot_distribution_type uniform \
              --multi_hot_sizes 3,2,1,2,6,1,1,1,1,7,3,8,1,6,9,5,1,1,1,12,100,27,10,3,1,1 \
              $ARGS "

LOG_0="${LOG}/throughput.log"

BATCH_SIZE=${BATCH_SIZE:-32768}
TORCH_INDUCTOR=${TORCH_INDUCTOR:-"0"}
if [[ "0" == ${TORCH_INDUCTOR} ]];then
  $mrun_cmd python $launcher_cmd $MODEL_SCRIPT $COMMON_ARGS --ipex-optimize 2>&1 | tee $LOG_0
else
  $mrun_cmd python $launcher_cmd $MODEL_SCRIPT $COMMON_ARGS --inductor 2>&1 | tee $LOG_0
fi
wait

if [[ $PLOTMEM == "true" ]]; then
mprof plot ${MEMLOG} -o ${MEMPIC}
fi

throughput=$(grep 'Throughput:' ${LOG}/throughput.log |sed -e 's/.*Throughput//;s/[^0-9.]//g' |awk '
BEGIN {
        sum = 0;
        i = 0;
      }
      {
        sum = sum + $1;
        i++;
      }
END   {
sum = sum / i;
        printf("%.3f", sum);
}')
echo ""dlrm-v2";"training throughput";${PRECISION};${BATCH_SIZE};${throughput}" | tee -a ${OUTPUT_DIR}/summary.log
