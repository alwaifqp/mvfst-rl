#!/bin/bash -e

# Usage: ./train.sh [--num_env N]

# ArgumentParser
NUM_ENV=4
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --num_env )
      NUM_ENV="$2"
      shift 2;;
    * )    # Unknown option
      POSITIONAL+=("$1") # Save it in an array for later
      shift;;
  esac
done
set -- "${POSITIONAL[@]}" # Restore positional parameters

CUR_DIR=$(dirname "$0")
ROOT_DIR="$CUR_DIR"/..
TORCHBEAST_DIR="$ROOT_DIR"/third-party/torchbeast

LOG_DIR="/tmp/logs"
mkdir -p $LOG_DIR

module unload cuda
module unload cudnn
module unload NCCL
module load cuda/9.2
module load cudnn/v7.3-cuda.9.2
module load NCCL/2.2.13-1-cuda.9.2

export CUDA_HOME="/public/apps/cuda/9.2"
export CUDNN_INCLUDE_DIR="/public/apps/cudnn/v7.3/cuda/include"
export CUDNN_LIB_DIR="/public/apps/cudnn/v7.3/cuda/lib64"

PYTHONPATH=$PYTHONPATH:"$TORCHBEAST_DIR"

# Unix domain socket path for RL server address
SOCKET_PATH="/tmp/rl_server_path"
rm -f $SOCKET_PATH

# Start pantheon_env.py in the background
PANTHEON_LOG="$LOG_DIR"/pantheon.log
python3 $ROOT_DIR/train/pantheon_env.py \
  -v 1 \
  --num_env "$NUM_ENV" \
  > "$PANTHEON_LOG" 2>&1 &
PANTHEON_PID=$!
echo "Pantheon started with $NUM_ENV parallel environments (pid: $PANTHEON_PID). Logfile: $PANTHEON_LOG."

# Start the trainer
# TODO (viswanath): More params, also start pantheon_env.py
PYTHONPATH=$PYTHONPATH OMP_NUM_THREADS=1 python3 $ROOT_DIR/train/polybeast.py \
  --address "unix:$SOCKET_PATH"

echo "Done training, killing pantheon."
kill -9 "$PANTHEON_PID"
