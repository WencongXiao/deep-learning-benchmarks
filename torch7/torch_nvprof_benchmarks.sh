#!/bin/bash

source $(pwd)'/torch/install/bin/torch-activate'
echo $PATH
which th

CMBS=16
CNB=70

RMBS=128
RNB=70

FMBS=8192
FNB=70

for i in "$@"
do
case $i in
    -cm=*|--cnn_mini_batch_size=*)
    CMBS="${i#*=}"
    shift # past argument=value
    ;;
    -cn=*|--cnn_num_batch=*)
    CNB="${i#*=}"
    shift # past argument=value
    ;;

    -rm=*|--rnn_mini_batch_size=*)
    RMBS="${i#*=}"
    shift # past argument=value
    ;;
    -rn=*|--rnn_num_batch=*)
    RNB="${i#*=}"
    shift # past argument=value
    ;;

    -fm=*|--fcn_mini_batch_size=*)
    fMBS="${i#*=}"
    shift # past argument=value
    ;;
    -fn=*|--fcn_num_batch=*)
    FNB="${i#*=}"
    shift # past argument=value
    ;;

    --default)
    DEFAULT=YES
    shift # past argument with no value
    ;;
    *)
            # unknown option
    ;;
esac
done


sudo rm -f torch_prof_output_fcn5.log
sudo rm -f torch_prof_output_fcn8.log


nvprof th benchmark_full.lua -arch fcn5 -batchSize ${FMBS} -nIterations ${FNB} -deviceId 0 2>&1 | tee torch_prof_output_fcn5.log
nvprof th benchmark_full.lua -arch fcn8 -batchSize ${FMBS} -nIterations ${FNB} -deviceId 0 2>&1 | tee torch_prof_output_fcn8.log


