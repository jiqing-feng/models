#!/usr/bin/env bash
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

MODELS=${MODELS-$PWD}

if [ -z "${OUTPUT_DIR}" ]; then
  echo "The required environment variable OUTPUT_DIR has not been set"
  exit 1
fi

# Create the output directory in case it doesn't already exist
mkdir -p ${OUTPUT_DIR}

if [ -z "${PRECISION}" ]; then
  echo "The required environment variable PRECISION has not been set"
  echo "Please set PRECISION to either fp32, bfloat16, or fp16."
  exit 1
fi
if [ $PRECISION != "fp32" ] && [ $PRECISION != "bfloat16" ] &&
   [ $PRECISION != "fp16" ]; then
  echo "The specified precision '${PRECISION}' is unsupported."
  echo "Supported precisions is: fp32, bfloat16, fp16"
  exit 1
fi

MODE="inference"

# If batch size env is not mentioned, then the workload will run with the default batch size.
BATCH_SIZE="${BATCH_SIZE:-"1"}"

source "${MODELS}/quickstart/common/utils.sh"
_command python ${MODELS}/benchmarks/launch_benchmark.py \
  --model-name=stable_diffusion \
  --precision ${PRECISION} \
  --mode=${MODE} \
  --framework tensorflow \
  --output-dir ${OUTPUT_DIR} \
  --batch-size ${BATCH_SIZE} \
  $@ \
