# TensorFlow ResNet50_v1.5 Inference

## Description

This document has instructions for running ResNet50 V1.5 Inference with INT8,FP32 and FP16 precisions using Intel® Extension for TensorFlow on Intel® Max Series GPU.

## Datasets

Download and preprocess the ImageNet dataset using the [instructions here](/datasets/imagenet/README.md).After running the conversion script you should have a directory with the ImageNet dataset in the TF records format.

Set the `DATASET_DIR` to point to the TF records directory when running ResNet50 v1.5. The folder that contains the `val` directory should be set as the `DATASET_DIR`
(for example: `export DATASET_DIR=/home/<user>/imagenet`).

## Quick Start Scripts

| Script name | Description |
|-------------|-------------|
| `batch_inference` | Runs ResNet50 V1.5 batch inference for the precision set on x4 OAM |
| `accuracy` | Measures model accuracy for the precision set |
| `online_inference` | Runs ResNet50 V1.5 online inference for the precision set |

Requirements:
* Host machine has Intel® Data Center Max Series 1550 x4 OAM GPU
* Follow instructions to install GPU-compatible driver [647](https://dgpu-docs.intel.com/releases/stable_647_21_20230714.html)
* Docker

### Docker pull command:

```
docker pull intel/image-recognition:tf-max-gpu-resnet50v1-5-inference
```
The ResNet50 v1.5 inference container includes scripts,model and libraries need to run int8,fp32,fp16 inference. To run the quickstart scripts using this container, you'll need to provide volume mounts for the ImageNet dataset. For running accuracy test, you will need to provide the `DATASET_DIR` to point to the pre-processed ImageNet Dataset. For batch and online inference, the script uses dummy data. You will need to provide an output directory where log files will be written. 

```
export PRECISION=<provide int8,fp32 or fp16 precision>
export OUTPUT_DIR=<path to output directory>
export DATASET_DIR=<path to the preprocessed imagenet dataset>
IMAGE_NAME=intel/image-recognition:tf-max-gpu-resnet50v1-5-inference
DOCKER_ARGS="--rm -it"
export SCRIPT=batch_inference.sh 
export FROZEN_GRAPH=/workspace/tf-max-series-resnet50v1-5-inference/pretrained_models/resnet50v1_5-frozen_graph-${PRECISION}-gpu.pb
export GPU_TYPE=max_series
export NUM_OAM=<provide 4 for number of OAM Modules supported by the platform>

docker run \
  --privileged \
  --device=/dev/dri \
  --ipc=host \
  --privileged \
  --env PRECISION=${PRECISION} \
  --env GPU_TYPE=${GPU_TYPE} \
  --env NUM_OAM=${NUM_OAM} \
  --env OUTPUT_DIR=${OUTPUT_DIR} \
  --env DATASET_DIR=${DATASET_DIR} \
  --env FROZEN_GRAPH=${FROZEN_GRAPH} \
  --env http_proxy=${http_proxy} \
  --env https_proxy=${https_proxy} \
  --env no_proxy=${no_proxy} \
  --volume ${OUTPUT_DIR}:${OUTPUT_DIR} \
  --volume ${DATASET_DIR}:${DATASET_DIR} \
  ${DOCKER_ARGS} \
  $IMAGE_NAME \
  /bin/bash quickstart/$SCRIPT
  ```
