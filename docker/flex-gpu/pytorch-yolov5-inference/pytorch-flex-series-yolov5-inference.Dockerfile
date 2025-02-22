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
# for more information.

ARG BASE_IMAGE="intel/intel-extension-for-pytorch"
ARG BASE_TAG="xpu-flex"

FROM ${BASE_IMAGE}:${BASE_TAG}

WORKDIR /home/user/workspace/pytorch-flex-series-yolov5-inference 

RUN apt-get update && \
    apt-get install -y parallel 
RUN apt-get install -y pciutils

# RUN sudo apt-get update && \
RUN apt-get install -y --no-install-recommends --fix-missing numactl ffmpeg libsm6 libxext6

ARG PY_VERSION=3.10

RUN apt-get update && \
    apt-get install -y --no-install-recommends --fix-missing \
    build-essential \
    python${PY_VERSION}-dev

RUN pip install \
    matplotlib>=3.2.2 \
    numpy>=1.18.5 \
    opencv-python>=4.1.1 \
    Pillow>=7.1.2 \
    PyYAML>=5.3.1 \
    requests>=2.23.0 \
    scipy>=1.4.1 \
    tqdm>=4.64.0 \
    protobuf==3.20.1 \
    pandas>=1.1.4 \
    seaborn>=0.11.0

COPY models/object_detection/pytorch/yolov5/inference/gpu models/object_detection/pytorch/yolov5/inference/gpu
COPY quickstart/object_detection/pytorch/yolov5/inference/gpu/inference.sh quickstart/inference.sh

COPY LICENSE license/LICENSE
COPY third_party license/third_party
