#!/bin/bash

#
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

cores_per_socket=$(lscpu |grep 'Core(s) per socket:' |sed 's/[^0-9]//g')


if [ -z "${OUTPUT_DIR}" ]; then
  echo "The required environment variable OUTPUT_DIR has not been set"
  exit 1
fi

# Create the output directory in case it doesn't already exist
mkdir -p ${OUTPUT_DIR}

if [ -z "${DATASET_DIR}" ]; then
  echo "The required environment variable DATASET_DIR has not been set"
  exit 1
fi

if [ ! -d "${DATASET_DIR}" ]; then
  echo "The DATASET_DIR '${DATASET_DIR}' does not exist"
  exit 1
fi

if [ -z "${PRECISION}" ]; then
  echo "The required environment variable PRECISION has not been set"
  echo "Please set PRECISION to fp32, fp16, bfloat16 or int8"
  exit 1
fi

if [ $PRECISION != "fp32" ] && [ $PRECISION != "int8" ] &&
   [ $PRECISION != "bfloat16" ] && [ $PRECISION != "fp16"]; then
  echo "The specified precision '${PRECISION}' is unsupported."
  echo "Supported precisions are: fp32, fp16, bfloat16 and int8"
  exit 1
fi

if [ ! -z "${IN_GRAPH}" ]; then
    if [ ! -f ${IN_GRAPH} ]; then
        echo "The frozen graph could not be found"
        exit 1
    fi
else
    echo "The required environment variable IN_GRAPH has not been set"
    echo "Set it to the path for the frozen graph"
    exit 1
fi

if [ -z "${WARMUP_STEPS}" ]; then
  echo "Setting WARMUP_STEPS to 10"
  WARMUP_STEPS="10"
fi

# If batch size env is not mentioned, then the workload will run with the default batch size.
if [ -z "${BATCH_SIZE}" ]; then
  BATCH_SIZE="56"
  echo "Running with default batch size of ${BATCH_SIZE}"
fi

source "${MODEL_DIR}/quickstart/common/utils.sh"
_command python benchmarks/launch_benchmark.py \
         --model-name=distilbert_base \
         --precision=${PRECISION} \
         --mode=inference \
         --framework=tensorflow \
         --in-graph=${IN_GRAPH} \
         --data-location=${DATASET_DIR} \
         --accuracy-only \
         --batch-size=${BATCH_SIZE} \
         --output-dir=${OUTPUT_DIR} \
         --num-intra-threads=${cores_per_socket} \
         --num-inter-threads=1 \
         --warmup-steps=${WARMUP_STEPS} \
         $@

