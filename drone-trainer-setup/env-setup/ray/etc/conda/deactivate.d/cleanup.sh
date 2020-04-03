#!/bin/bash

function restore_env(){
  if [ -z ${!1} ]
  then
    unset $2
  else
    export $2="${!1}"
  fi
  unset $1
}

OS_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | tr -d '"')
if [ $OS_VERSION == "16.04" ]; then
  ROS_DIST="kinetic"
elif [ $OS_VERSION == "18.04" ]; then
  ROS_DIST="melodic"
fi

export PATH=$(echo $PATH | sed -e 's/\/opt\/ros\/'"$ROS_DIST"'\/bin\://g')
restore_env PREV_LD_LIBRARY_PATH LD_LIBRARY_PATH
restore_env PREV_LIBRARY_PATH LIBRARY_PATH
restore_env PREV_PKG_CONFIG_PATH PKG_CONFIG_PATH
restore_env PREV_CMAKE_PREFIX_PATH CMAKE_PREFIX_PATH
restore_env PREV_PYTHONPATH PYTHONPATH

for ros_env in ${!ROS*}
do
  unset $ros_env
done


