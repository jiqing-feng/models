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
if [ ! -e "${MODEL_DIR}/models/recommendation/pytorch/memrec_dlrm/product/memrec.py"  ]; then
    echo "Could not find the script of memrec.py. Please set environment variable '\${MODEL_DIR}'."
    echo "From which the memrec.py exist at the: \${MODEL_DIR}/models/recommendation/pytorch/dlrm/product/memrec.py"
    exit 1
fi
MODEL_SCRIPT=${MODEL_DIR}/models/recommendation/pytorch/memrec_dlrm/product/memrec.py

echo "PRECISION: ${PRECISION}"
echo "DATASET_DIR: ${DATASET_DIR}"
echo "OUTPUT_DIR: ${OUTPUT_DIR}"

if [ -z "${OUTPUT_DIR}" ]; then
  echo "The required environment variable OUTPUT_DIR has not been set"
  exit 1
fi

if [ -z "${DATASET_DIR}" ]; then
  echo "The required environment variable DATASET_DIR has not been set"
  exit 1
fi

if [ ! -d "${DATASET_DIR}" ]; then
  echo "The DATASET_DIR '${DATASET_DIR}' does not exist"
  exit 1
fi


# Create the output directory in case it doesn't already exist
mkdir -p ${OUTPUT_DIR}
LOG=${OUTPUT_DIR}/memrec_inference_performance_log/${PRECISION}
rm -rf ${LOG}
mkdir -p ${LOG}

ARGS=""
if [[ $PRECISION == "fp32" ]]; then
    echo "running fp32 path"
else
    echo "The specified PRECISION '${PRECISION}' is unsupported."
    echo "Supported PRECISIONs are: fp32"
    exit 1
fi

export OMP_NUM_THREADS=1
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | awk '{print $4}'`
SOCKETS=`lscpu | grep "Socket(s)" | awk '{print $2}'`
NUMA_NODES=`lscpu | grep "NUMA node(s)" | awk '{print $3}'`
NUMA_NODES_PER_SOCKETS=`expr $NUMA_NODES / $SOCKETS`
CORES_PER_NUMA_NODE=`expr $CORES_PER_SOCKET / $NUMA_NODES_PER_SOCKETS`

LOG_0="${LOG}/throughput.log"

python3 -m intel_extension_for_pytorch.cpu.launch --throughput_mode --enable_jemalloc $MODEL_SCRIPT \
--raw-data-file=${DATASET_DIR}/day --processed-data-file=${DATASET_DIR}/terabyte_processed.npz \
--data-set=terabyte \
--memory-map --mlperf-bin-loader --round-targets=True --learning-rate=1.0 \
--arch-mlp-bot=13-512-256-128 --arch-mlp-top=1024-1024-512-256-1 \
--arch-sparse-feature-size=128 --max-ind-range=40000000  \
--numpy-rand-seed=727  --inference-only --num-batches=1000 \
--print-freq=10 --print-time --test-mini-batch-size=128 --share-weight-instance=$CORES_PER_NUMA_NODE \
--learning-rate=0.50  --D 75000 --K 1 --dw 75000 --kw 1 --arch-mlp-bot-sparse 128 \

$ARGS |tee $LOG_0
wait

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
echo ""dlrm";"throughput";${PRECISION};128;${throughput}" | tee -a ${OUTPUT_DIR}/summary.log
