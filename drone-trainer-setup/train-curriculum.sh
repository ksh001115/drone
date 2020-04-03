#!/bin/bash

function _msg(){
  case $1 in
    2)
      echo -e "\033[33m[WARN] $2\033[0m"
      ;;
    1)
      if [ $? -ne 0 ]; then
	echo -e "\033[31m[ERROR] $2\033[0m"
	exit 1
      fi 
      ;;
    0)
      echo "[INFO] "$2
      ;;
    *)
      if [ $# == 1 ]; then
	echo "[INFO] "$1
      fi
      ;;
  esac
} 

function _check_conda(){
  conda -V > /dev/null 2>&1
  _msg 1 "Please check if anaconda is installed. (REQUIRED: Anaconda available at https://www.anaconda.com/distribution/ )"
  conda activate >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    _CONDA_BASE=$(dirname $(dirname $(which conda)))
    . $_CONDA_BASE/etc/profile.d/conda.sh
  fi
}

function _check_x(){
  xset q >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    _msg 2 "Cannot find running X display server."
    pgrep Xvfb > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      _msg 2 "Xvfb process is running but cannot access to it. Restarting Xvfb..."
      kill $(pgrep Xvfb)
    else
      _msg 2 "Starting Xvfb..."
    fi
    Xvfb $DISPLAY -screen 0 1920x1080x24 &
    _msg 1 "Failed to start Xvfb."
  fi
}

function _quit_ros(){
  PID_LIST=$(pgrep 'roslaunch')
  if [ $? -eq 0 ]; then
    kill $PID_LIST
    KILLED=0
    while [ $KILLED -eq 0 ];do
      sleep 1;
      pgrep 'roslaunch' > /dev/null 2>&1
      KILLED=$?
    done
  fi
}

function _check_sim_status(){
  HOSTNAME="localhost"
  URI_BASE="http://$HOSTNAME:"
  GZ_PORT_BASE="18200"
  ROS_PORT_BASE="18300"

  if [ -z ${NUM_WORKERS+x} ]; then
    NUM_WORKERS=1
  fi

  CHECK=1

  while [ $CHECK -gt 0 ]; do
    CHECK=0
    for ((index=0;index<$NUM_WORKERS;index++))
    do
      ROS_PORT=$((ROS_PORT_BASE+index))
      ROS_URI=$URI_BASE$ROS_PORT
      env ROS_MASTER_URI=$ROS_URI rostopic list | grep /clock >/dev/null 2>&1
      RETURN_1=$?
      env ROS_MASTER_URI=$ROS_URI rosservice call /gazebo/get_world_properties >/dev/null 2>&1
      RETURN_2=$?
      CHECK=$((CHECK+RETURN_1+RETURN_2))
    done
  done
}

function _train() {
  DO_LOOP=1
  while [ $DO_LOOP -eq 1 ]; do

    _msg 0 "Starting drone simulation process..."
    _check_x
    conda activate ros
    ./run-multiple-ros-gazebo.sh
    sleep 10
    _check_sim_status
    conda deactivate 

    _msg 0 "Starting python training process..."
    conda activate ray
    python trainer/ppo-train-drone.py
    if [ $? -ne 0 ]; then
      _msg 2 "The training process will be restarted automatically in 5 secs." 
      _msg 2 "Ctrl-C to cancel restart."
      sleep 5
      if [ $? -ne 0 ]; then
	DO_LOOP=0
      fi
    else
      DO_LOOP=0
    fi
    conda deactivate 
  done
}

_check_conda

_msg 0 "Training bash script started."	

mkdir -p trainer/checkpoint
mkdir -p trainer/curriculum

NUM_OF_STAGES=3
START_STAGE=1

sed -i "/WORLDS_JSON_NAME\ =/c\WORLDS_JSON_NAME = 'curriculum/worlds_1.json'" trainer/ppo-train-drone.py

for ((stage=$START_STAGE;stage<$((NUM_OF_STAGES+1));stage++))
do
  _msg 0 "Training Stage $stage..."
  sed -i "s/curriculum\/worlds_[0-9]/curriculum\/worlds_$stage/g" trainer/ppo-train-drone.py
  _msg 1 "Failed to edit ppo-train-drone.py. Please check your permissions."
  _train
done

sed -i "/WORLDS_JSON_NAME\ =/c\WORLDS_JSON_NAME = 'worlds.json'" trainer/ppo-train-drone.py


_quit_ros

