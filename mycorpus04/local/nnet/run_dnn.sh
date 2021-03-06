#!/bin/bash

# Copyright 2018 (author: Haris Bin Zia)
# Apache 2.0

. ./path.sh
. ./cmd.sh

mfcc_fmllr_dir=mfcc_fmllr
baseDir=exp/tri3
alignDir=exp/tri3_ali
dnnDir=exp/tri3_dnn_2048x5
align_dnnDir=exp/tri3_dnn_2048x5_ali
dnnLatDir=exp/tri3_dnn_2048x5_denlats
dnnMPEDir=exp/tri3_dnn_2048x5_smb

trainTr90=data/train_tr90
trainCV=data/train_cv10 

steps/nnet/make_fmllr_feats.sh --nj 1 --cmd $train_cmd \
  --transform-dir $baseDir/decode data/test_fmllr data/test \
  $baseDir $mfcc_fmllr_dir/log_test $mfcc_fmllr_dir || exit 1;

steps/nnet/make_fmllr_feats.sh --nj 1 --cmd $train_cmd \
  --transform-dir $alignDir data/train_fmllr data/train \
  $baseDir $mfcc_fmllr_dir/log_train $mfcc_fmllr_dir || exit 1;
                            
utils/subset_data_dir_tr_cv.sh  data/train_fmllr $trainTr90 $trainCV || exit 1;

(tail --pid=$$ -F $dnnDir/train_nnet.log 2>/dev/null)& 
$cuda_cmd $dnnDir/train_nnet.log \
steps/train_nnet.sh --hid-dim 2048 --hid-layers 5 --learn-rate 0.008 \
  $trainTr90 $trainCV data/lang $alignDir $alignDir $dnnDir || exit 1;

steps/decode_nnet.sh --nj 1 --cmd $decode_cmd --config conf/decode_dnn.config \
  --nnet $dnnDir/final.nnet --acwt 0.08 $baseDir/graph data/test_fmllr $dnnDir/decode || exit 1;

steps/nnet/align.sh --nj 1 --cmd $train_cmd data/train_fmllr data/lang \
  $dnnDir $align_dnnDir || exit 1;

steps/nnet/make_denlats.sh --nj 1 --cmd $train_cmd --config conf/decode_dnn.config --acwt 0.1 \
  data/train_fmllr data/lang $dnnDir $dnnLatDir || exit 1;

steps/nnet/train_mpe.sh --cmd $cuda_cmd --num-iters 6 --acwt 0.1 --do-smbr true \
  data/train_fmllr data/lang $dnnDir $align_dnnDir $dnnLatDir $dnnMPEDir || exit 1;

for n in 6 5 4 3 2 1; do
  steps/decode_nnet.sh --nj 1 --cmd $train_cmd --config conf/decode_dnn.config \
    --nnet $dnnMPEDir/$n.nnet --acwt 0.08 \
    $baseDir/graph data/test_fmllr $dnnMPEDir/decode_it$n || exit 1;
done

