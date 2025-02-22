#!/bin/bash

#
# Copyright (c) 2021 Intel Corporation
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

#export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX
ARGS=""
precision=fp32

if [[ "$PRECISION" == *"avx"* ]]; then
    unset DNNL_MAX_CPU_ISA
fi

if [[ "$PRECISION" == "bf16" ]]
then
    precision=bf16
    ARGS="$ARGS --bf16"
    echo "### running bf16 mode"
elif [[ "$PRECISION" == "fp16" ]]
then
    precision=fp16
    ARGS="$ARGS --fp16_cpu"
    echo "### running fp16 mode"

elif [[ "$PRECISION" == "int8" || "$PRECISION" == "avx-int8" ]]
then
    precision=int8
    ARGS="$ARGS --int8 --int8_bf16"
    echo "### running int8 mode"
elif [[ "$PRECISION" == "bf32" ]]
then
    precision=bf32
    ARGS="$ARGS --bf32"
    echo "### running bf32 mode"
elif [[ "$PRECISION" == "fp32" || "$PRECISION" == "avx-fp32" ]]
then
    precision=fp32
    echo "### running fp32 mode"
elif [[ "$PRECISION" == "int8-fp32" ]]
then
    precision=int8
    ARGS="$ARGS --int8_fp32"
    echo "### running int8-fp32 mode"
else
    echo "Please set PRECISION to : fp32, int8, bf32, bf26, avx-int8 or avx-fp32"
fi

rm -f ${OUTPUT_DIR}/accuracy_log*
INT8_CONFIG=${INT8_CONFIG:-"configure.json"}
BATCH_SIZE=${BATCH_SIZE:-8}
EVAL_DATA_FILE=${EVAL_DATA_FILE:-"${PWD}/squad1.1/dev-v1.1.json"}
FINETUNED_MODEL=${FINETUNED_MODEL:-bert_squad_model}
OUTPUT_DIR=${OUTPUT_DIR:-"${PWD}"}
EVAL_SCRIPT=${EVAL_SCRIPT:-"./transformers/examples/legacy/question-answering/run_squad.py"}
work_space=${work_space:-"${OUTPUT_DIR}"}

TORCH_INDUCTOR=${TORCH_INDUCTOR:-"0"}
if [ ${WEIGHT_SHAREING} ]; then
  CORES=`lscpu | grep Core | awk '{print $4}'`
  SOCKETS=`lscpu | grep Socket | awk '{print $2}'`
  TOTAL_CORES=`expr $CORES \* $SOCKETS`
  CORES_PER_INSTANCE=$CORES
  INSTANCES=`expr $TOTAL_CORES / $CORES_PER_INSTANCE`
  LAST_INSTANCE=`expr $INSTANCES - 1`
  INSTANCES_PER_SOCKET=`expr $INSTANCES / $SOCKETS`

  numa_node_i=0
  start_core_i=0
  end_core_i=`expr $start_core_i + $CORES_PER_INSTANCE - 1`
  LOG_0="${OUTPUT_DIR}/accuracy_log_${PRECISION}.log"

  echo "Running Bert_Large inference throughput with runtime extension enabled."
  STREAM_PER_INSTANCE=$CORES_PER_INSTANCE

  #export OMP_NUM_THREADS=`expr $BATCH_SIZE \/ $STREAM_PER_INSTANCE`
  BATCH_SIZE=$STREAM_PER_INSTANCE
  ARGS="$ARGS --use_multi_stream_module"
  ARGS="$ARGS --num_streams $STREAM_PER_INSTANCE"
  ARGS="$ARGS --instance_number $numa_node_i"

  numactl -C $start_core_i-$end_core_i --membind=$numa_node_i python $EVAL_SCRIPT $ARGS --model_type bert --model_name_or_path ${FINETUNED_MODEL}  --do_eval --do_lower_case --predict_file $EVAL_DATA_FILE  --per_gpu_eval_batch_size $BATCH_SIZE --learning_rate 3e-5 --num_train_epochs 2.0 --max_seq_length 384 --doc_stride 128 --output_dir ./tmp --tokenizer_name bert-large-uncased-whole-word-masking-finetuned-squad --use_jit --ipex --int8_config ${INT8_CONFIG} \
  2>&1 | tee $LOG_0
elif [[ "0" == ${TORCH_INDUCTOR} ]];then
  python -m intel_extension_for_pytorch.cpu.launch --log_path=${OUTPUT_DIR} --log_file_prefix="accuracy_log" $EVAL_SCRIPT $ARGS --model_type bert --model_name_or_path ${FINETUNED_MODEL}  --do_eval --do_lower_case --predict_file $EVAL_DATA_FILE  --per_gpu_eval_batch_size $BATCH_SIZE --learning_rate 3e-5 --num_train_epochs 2.0 --max_seq_length 384 --doc_stride 128 --output_dir ./tmp --tokenizer_name bert-large-uncased-whole-word-masking-finetuned-squad --use_jit --ipex --int8_config ${INT8_CONFIG} 2>&1 | tee $LOG_0
else
  python -m intel_extension_for_pytorch.cpu.launch --log_path=${OUTPUT_DIR} --log_file_prefix="accuracy_log" $EVAL_SCRIPT $ARGS --model_type bert --model_name_or_path ${FINETUNED_MODEL}  --do_eval --do_lower_case --predict_file $EVAL_DATA_FILE  --per_gpu_eval_batch_size $BATCH_SIZE --learning_rate 3e-5 --num_train_epochs 2.0 --max_seq_length 384 --doc_stride 128 --output_dir ./tmp --tokenizer_name bert-large-uncased-whole-word-masking-finetuned-squad --inductor --int8_config ${INT8_CONFIG} 2>&1 | tee $LOG_0
fi


accuracy=$(grep 'Results:' ${OUTPUT_DIR}/accuracy_log*|awk -F ' ' '{print $12}' | awk -F ',' '{print $1}')
echo ""BERT";"f1";${precision}; ${BATCH_SIZE};${accuracy}" | tee -a ${OUTPUT_DIR}/summary.log


