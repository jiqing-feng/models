# Running SSD-MobileNet Inference on Intel® Data Center GPU Flex Series using Intel® Extension for TensorFlow*

## Overview

This document has instructions for running SSD-MobileNet inference using Intel®  Extension for TensorFlow* with Intel® Data Center GPU Flex Series.

## Requirements
| Item | Detail |
| ------ | ------- |
| Host machine  | Intel® Data Center GPU Flex Series  |
| Drivers | GPU-compatible drivers need to be installed:[Download Driver 602](https://dgpu-docs.intel.com/installation-guides/ubuntu/ubuntu-jammy-dc.html#step-1-add-package-repository)
| Software | Docker* Installed |

## Get Started

## Download Datasets

Download and preprocess the COCO dataset using the [instructions here](https://github.com/IntelAI/models/blob/master/datasets/coco/README.md).
After running the conversion script you should have a directory with the
COCO dataset in the TF records format.

Set the `DATASET_DIR` to point to the TF records directory when running SSD-MobileNet.

## Quick Start Scripts

| Script name | Description |
|:-------------:|:-------------:|
| `online_inference` | Runs online inference for int8 precision on Flex series 170 | 
| `batch_inference` | Runs batch inference for int8 precision on Flex series 170 |
| `accuracy` | Measures the model accuracy for int8 precision on Flex series 170 |
| `flex_multi_card_online_inference` | Runs online inference for int8 precision on Flex series 140 |
| `flex_multi_card_batch_inference` | Runs batch inference for int8 precision on Flex series 140 |
## Run Using Docker

### Set up Docker Image

```
docker pull intel/object-detection:tf-flex-gpu-ssd-mobilenet-inference
```
### Run Docker Image
The SSD-MobileNet inference container includes scripts,model and libraries need to run int8 inference. To run the inference quickstart scripts using this container, you'll need to provide volume mounts for the COCO dataset for running `accuracy.sh` script. For `online_inference.sh` and `batch_inference.sh` dummy dataset will be used. You will need to provide an output directory where log files will be written. 

**Note:** The Default batch size for Flex series 140 is 256 for batch inference and 1024 for Flex series 170. Additionally, add `--cap-add=SYS_NICE` to the `docker run` command for executing `flex_multi_card_online_inference.sh` and `flex_multi_card_batch_inference.sh` on Flex series 140

```
export PRECISION=int8
export OUTPUT_DIR=<path to output directory>
export DATASET_DIR=<path to the preprocessed coco dataset>
export BATCH_SIZE=<inference batch size.Default is 1024 for Flex Series 170 and 256 for Flex Series 140>
IMAGE_NAME=intel/object-detection:tf-flex-gpu-ssd-mobilenet-inference
DOCKER_ARGS="--rm -it"

docker run \
  --privileged \
  --device=/dev/dri \
  --ipc=host \
  --env PRECISION=${PRECISION} \
  --env BATCH_SIZE=${BATCH_SIZE} \
  --env OUTPUT_DIR=${OUTPUT_DIR} \
  --env DATASET_DIR=${DATASET_DIR} \
  --env http_proxy=${http_proxy} \
  --env https_proxy=${https_proxy} \
  --env no_proxy=${no_proxy} \
  --volume ${OUTPUT_DIR}:${OUTPUT_DIR} \
  --volume ${DATASET_DIR}:${DATASET_DIR} \
  ${DOCKER_ARGS} \
  ${IMAGE_NAME} \
  /bin/bash quickstart/<script name>.sh
```

## Documentation and Sources

[GitHub* Repository](https://github.com/IntelAI/models/tree/master/dockerfiles/model_containers)

## Support
Support for Intel® Extension for TensorFlow* is found via the [Intel® AI Analytics Toolkit.](https://www.intel.com/content/www/us/en/developer/tools/oneapi/ai-analytics-toolkit.html#gs.qbretz) Additionally, the Intel® Extension for TensorFlow* team tracks both bugs and enhancement requests using [GitHub issues](https://github.com/intel/intel-extension-for-tensorflow/issues). Before submitting a suggestion or bug report, please search the GitHub issues to see if your issue has already been reported.

## License Agreement

LEGAL NOTICE: By accessing, downloading or using this software and any required dependent software (the “Software Package”), you agree to the terms and conditions of the software license agreements for the Software Package, which may also include notices, disclaimers, or license terms for third party software included with the Software Package. Please refer to the [license file](https://github.com/IntelAI/models/tree/master/third_party) for additional details.
