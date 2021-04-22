#!bin/bash

. ./cmd.sh
[ -f path.sh ] && . ./path.sh

echo ============================================================================
echo "                Data & Lexicon & Language Preparation                     "
echo ============================================================================

utils/fix_data_dir.sh data/train
utils/fix_data_dir.sh data/test

utils/prepare_lang.sh data/local/lang '<oov>' data/local data/lang

utils/format_lm.sh data/lang data/local/lm/LM2.gz data/local/lang/lexicon.txt data/lang_test


echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training and Test set          "
echo ============================================================================

mfccdir=mfcc

steps/make_mfcc.sh --cmd "$train_cmd" --nj 3 data/train exp/make_mfcc/train $mfccdir
steps/compute_cmvn_stats.sh data/train exp/make_mfcc/train $mfccdir

steps/make_mfcc.sh --cmd "$train_cmd" --nj 1 data/test exp/make_mfcc/test $mfccdir
steps/compute_cmvn_stats.sh data/test exp/make_mfcc/test $mfccdir

utils/validate_data_dir.sh data/train
utils/fix_data_dir.sh data/train

utils/validate_data_dir.sh data/test
utils/fix_data_dir.sh data/test

echo ============================================================================
echo "                     Monophone training and alignment          "
echo ============================================================================

echo "Train monophones"
steps/train_mono.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" data/train data/lang exp/mono

echo "Align monophones"
steps/align_si.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" data/train data/lang exp/mono exp/mono_ali

echo ============================================================================
echo "           Triphone training and alignment              "
echo ============================================================================

echo "Train delta-based triphones"
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" 2000 10000 data/train data/lang exp/mono_ali exp/tri1


echo "Align delta-based triphones"
steps/align_si.sh --nj 3 --cmd "$train_cmd" data/train data/lang exp/tri1 exp/tri1_ali

echo "Train delta + delta-delta triphones"
steps/train_deltas.sh --cmd "$train_cmd" 2500 15000 data/train data/lang exp/tri1_ali exp/tri2a

echo "Align delta + delta-delta triphones"
steps/align_si.sh  --nj 3 --cmd "$train_cmd" --use-graphs true data/train data/lang exp/tri2a exp/tri2a_ali 

echo "Align delta + delta-delta triphones"
steps/align_si.sh  --nj 3 --cmd "$train_cmd" --use-graphs true data/train data/lang exp/tri2a exp/tri2a_ali 

echo "Train LDA-MLLT triphones"
steps/train_lda_mllt.sh --cmd "$train_cmd" 3500 20000 data/train data/lang exp/tri2a_ali exp/tri3a


echo "Align LDA-MLLT triphones with FMLLR"
steps/align_fmllr.sh --nj 3 --cmd "$train_cmd" data/train data/lang exp/tri3a exp/tri3a_ali

echo "Train SAT triphones"
steps/train_sat.sh  --cmd "$train_cmd" 4200 40000 data/train data/lang exp/tri3a_ali exp/tri4a 

echo "Align SAT triphones with FMLLR"
steps/align_fmllr.sh --nj 3 --cmd "$train_cmd" data/train data/lang exp/tri4a exp/tri4a_ali


echo "Hello: change it if not working
utils/mkgraph.sh data/lang_test exp/tri4a_ali exp/tri4a_ali/graph
steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" exp/tri4a_ali/graph data/test exp/tri4a_ali/decode
"









