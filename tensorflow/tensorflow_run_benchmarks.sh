#!/bin/bash

CMBS=16
CNB=100

RMBS=128
RNB=100

FMBS=64
FNB=100

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

sudo rm -f output_alexnet.log
sudo rm -f output_resnet.log
sudo rm -f output_fcn5.log
sudo rm -f output_fcn8.log
sudo rm -f output_lstm32.log
sudo rm -f output_lstm64.log

python cnn/alexnet/alexnet.py  -e 4 -b ${CMBS} -i ${CNB} -d 0  2>&1 | tee output_alexnet.log
python cnn/resnet/resnet.py -e 4 -b ${CMBS} -i ${CNB} -d 0 2>&1 | tee output_resnet.log
python fcn/fcn5/fcn5.py -e 4 -b ${FMBS} -i ${FNB} -d 0 2>&1 | tee output_fcn5.log
python fcn/fcn8/fcn8.py -e 4 -b ${FMBS} -i ${FNB} -d 0 2>&1 | tee output_fcn8.log
python rnn/lstm/lstm.py --mini_batch_size ${RMBS} --num_batches ${RNB} --seqlen 32 --numlayer 2 --hiddensize 256 --device 0 --data_path ../data 2>&1 | tee output_lstm32.log
python rnn/lstm/lstm.py --mini_batch_size ${RMBS} --num_batches ${RNB} --seqlen 64 --numlayer 2 --hiddensize 256 --device 0 --data_path ../data 2>&1 | tee output_lstm64.log