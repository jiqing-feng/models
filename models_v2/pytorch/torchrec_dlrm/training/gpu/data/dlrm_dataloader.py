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
#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

import argparse
import os
from typing import List

from torch import distributed as dist
from torch.utils.data import DataLoader
from torchrec.datasets.criteo import (
    CAT_FEATURE_COUNT,
    DAYS,
    DEFAULT_CAT_NAMES,
    DEFAULT_INT_NAMES,
    InMemoryBinaryCriteoIterDataPipe,
)
# This is for crop dataset
DAYS_MIN=1
from torchrec.datasets.random import RandomRecDataset

# OSS import
try:
    # pyre-ignore[21]
    # @manual=//ai_codesign/benchmarks/dlrm/torchrec_dlrm/data:multi_hot_criteo
    from data.multi_hot_criteo import MultiHotCriteoIterDataPipe

except ImportError:
    pass

# internal import
try:
    from .multi_hot_criteo import MultiHotCriteoIterDataPipe  # noqa F811
except ImportError:
    pass

STAGES = ["train", "val", "test"]


def _get_random_dataloader(
    args: argparse.Namespace,
    stage: str,
) -> DataLoader:
    attr = f"limit_{stage}_batches"
    num_batches = getattr(args, attr)
    if stage in ["val", "test"] and args.test_batch_size is not None:
        batch_size = args.test_batch_size
    else:
        batch_size = args.batch_size
    return DataLoader(
        RandomRecDataset(
            keys=DEFAULT_CAT_NAMES,
            batch_size=batch_size,
            hash_size=args.num_embeddings,
            hash_sizes=args.num_embeddings_per_feature
            if hasattr(args, "num_embeddings_per_feature")
            else None,
            manual_seed=args.seed if hasattr(args, "seed") else None,
            ids_per_feature=1,
            num_dense=len(DEFAULT_INT_NAMES),
            num_batches=num_batches,
        ),
        batch_size=None,
        batch_sampler=None,
        pin_memory=args.pin_memory,
        num_workers=0,
    )


def _get_in_memory_dataloader(
    args: argparse.Namespace,
    stage: str,
) -> DataLoader:
    if args.in_memory_binary_criteo_path is not None:
        dir_path = args.in_memory_binary_criteo_path
        sparse_part = "sparse.npy"
        datapipe = InMemoryBinaryCriteoIterDataPipe
    else:
        dir_path = args.synthetic_multi_hot_criteo_path
        sparse_part = "sparse_multi_hot.npz"
        datapipe = MultiHotCriteoIterDataPipe

    if args.dataset_name == "criteo_kaggle":
        # criteo_kaggle has no validation set, so use 2nd half of training set for now.
        # Setting stage to "test" will get the 2nd half of the dataset.
        # Setting root_name to "train" reads from the training set file.
        (root_name, stage) = ("train", "test") if stage == "val" else stage
        stage_files: List[List[str]] = [
            [os.path.join(dir_path, f"{root_name}_dense.npy")],
            [os.path.join(dir_path, f"{root_name}_{sparse_part}")],
            [os.path.join(dir_path, f"{root_name}_labels.npy")],
        ]
    # criteo_1tb code path uses below two conditionals
    elif stage == "train":
        if args.converge:
            stage_files: List[List[str]] = [
                [os.path.join(dir_path, f"day_{i}_dense.npy") for i in range(DAYS - 1)],
                [os.path.join(dir_path, "multihot", f"day_{i}_{sparse_part}") for i in range(DAYS - 1)],
                [os.path.join(dir_path, f"day_{i}_labels.npy") for i in range(DAYS - 1)],
            ]
        else:
            stage_files: List[List[str]] = [
                # for crop dataset
                [os.path.join(dir_path, f"day_{i}_dense.npy") for i in range(DAYS_MIN)],
                [os.path.join(dir_path, f"day_{i}_{sparse_part}") for i in range(DAYS_MIN)],
                [os.path.join(dir_path, f"day_{i}_labels.npy") for i in range(DAYS_MIN)],
            ]
    elif stage in ["val", "test"]:
        if args.converge:
            stage_files: List[List[str]] = [
                [os.path.join(dir_path, f"day_{DAYS-1}_dense.npy")],
                [os.path.join(dir_path, "multihot", f"day_{DAYS-1}_{sparse_part}")],
                [os.path.join(dir_path, f"day_{DAYS-1}_labels.npy")],
            ]
        else:
            stage_files: List[List[str]] = [
                [os.path.join(dir_path, f"day_{DAYS_MIN-1}_dense.npy")],
                [os.path.join(dir_path, f"day_{DAYS_MIN-1}_{sparse_part}")],
                [os.path.join(dir_path, f"day_{DAYS_MIN-1}_labels.npy")],
            ]
    if stage in ["val", "test"] and args.test_batch_size is not None:
        batch_size = args.test_batch_size
    else:
        batch_size = args.batch_size
    dataloader = DataLoader(
        datapipe(
            stage,
            *stage_files,  # pyre-ignore[6]
            batch_size=batch_size,
            #rank=dist.get_rank(),
            #world_size=dist.get_world_size(),
            # The rand and world_size set for custom dist-dlrm
            rank=0,
            world_size=1,
            drop_last=args.drop_last_training_batch if stage == "train" else False,
            shuffle_batches=args.shuffle_batches,
            shuffle_training_set=args.shuffle_training_set,
            shuffle_training_set_random_seed=args.seed,
            mmap_mode=args.mmap_mode,
            hashes=args.num_embeddings_per_feature
            if args.num_embeddings is None
            else ([args.num_embeddings] * CAT_FEATURE_COUNT),
        ),
        batch_size=None,
        num_workers=0,
        pin_memory=args.pin_memory,
        collate_fn=lambda x: x,
    )
    return dataloader


def get_dataloader(args: argparse.Namespace, backend: str, stage: str) -> DataLoader:
    """
    Gets desired dataloader from dlrm_main command line options. Currently, this
    function is able to return either a DataLoader wrapped around a RandomRecDataset or
    a Dataloader wrapped around an InMemoryBinaryCriteoIterDataPipe.

    Args:
        args (argparse.Namespace): Command line options supplied to dlrm_main.py's main
            function.
        backend (str): "nccl" or "gloo".
        stage (str): "train", "val", or "test".

    Returns:
        dataloader (DataLoader): PyTorch dataloader for the specified options.

    """
    stage = stage.lower()
    if stage not in STAGES:
        raise ValueError(f"Supplied stage was {stage}. Must be one of {STAGES}.")

    args.pin_memory = (
        (backend == "nccl") if not hasattr(args, "pin_memory") else args.pin_memory
    )

    if (
        args.in_memory_binary_criteo_path is None
        and args.synthetic_multi_hot_criteo_path is None
    ):
        return _get_random_dataloader(args, stage)
    else:
        return _get_in_memory_dataloader(args, stage)
