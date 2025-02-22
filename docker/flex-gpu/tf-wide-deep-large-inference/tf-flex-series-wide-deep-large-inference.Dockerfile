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
# ============================================================================
#
# THIS IS A GENERATED DOCKERFILE.
#
# This file was assembled from multiple pieces, whose use is documented
# throughout. Please refer to the TensorFlow dockerfiles documentation
# for more information

<<<<<<<< HEAD:quickstart/recommendation/pytorch/torchrec_dlrm/training/gpu/setup.sh
apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing numactl

pip install -r models/recommendation/pytorch/torchrec_dlrm/training/gpu/requirements.txt
pip install -e git+https://github.com/mlperf/logging#egg=mlperf-logging
========
ARG TF_BASE_IMAGE="intel/intel-extension-for-tensorflow"
ARG TF_BASE_TAG="xpu"

FROM ${TF_BASE_IMAGE}:${TF_BASE_TAG}

WORKDIR /workspace/tf-flex-series-wide-deep-large-inference/models

RUN apt-get update && \
    apt-get install -y --no-install-recommends parallel pciutils numactl
    
COPY models_v2/tensorflow/wide_deep_large_ds/inference/gpu . 

COPY LICENSE license/LICENSE
COPY third_party license/third_party
>>>>>>>> r3.1:docker/flex-gpu/tf-wide-deep-large-inference/tf-flex-series-wide-deep-large-inference.Dockerfile
