#! /bin/bash


LOG_DIR="./logs"
mkdir -p $LOG_DIR

HOSTNAME="localhost"
URI_BASE="http://$HOSTNAME:"
GZ_PORT_BASE="18200"
ROS_PORT_BASE="18300"

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

_quit_ros

if [ -z ${NUM_WORKERS+x} ]; then
  NUM_WORKERS=1
fi

for ((index=0;index<$NUM_WORKERS;index++))
do
  GZ_PORT=$((GZ_PORT_BASE+index))
  GZ_URI=$URI_BASE$GZ_PORT
  ROS_PORT=$((ROS_PORT_BASE+index))
  # WORLD_NAME=$((index+2))drone_simul
  # WORLD_NAME=2drone_simul
  WORLD_NAME=mydrone_simul
  LAUNCHFILE=$WORLD_NAME.launch
  LOGFILE=$LOG_DIR/SIM-$(date +%y%m%d-%H%M%S)-GZ-$GZ_PORT-ROS-$ROS_PORT-$WORLD_NAME.log
  env GAZEBO_MASTER_URI=$GZ_URI ROS_HOSTNAME=$HOSTNAME roslaunch -p $ROS_PORT hector_quadrotor_demo $LAUNCHFILE > $LOGFILE 2>&1 &
done

