#!/usr/bin/env bash


export PREV_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
export PREV_LIBRARY_PATH="$LIBRARY_PATH"
export PREV_PKG_CONFIG_PATH="$PKG_CONFIG_PATH"
export PREV_CMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH"
export PREV_PYTHONPATH="$PYTHONPATH"

OS_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | tr -d '"')
if [ $OS_VERSION == "16.04" ]; then
  ROS_DIST="kinetic"
elif [ $OS_VERSION == "18.04" ]; then
  ROS_DIST="melodic"
fi

CATKIN_SHELL=bash
ROS_BASE_DIR="/opt/ros/$ROS_DIST"
_CATKIN_SETUP_DIR=$(builtin cd "$ROS_BASE_DIR" > /dev/null && pwd)
. "$_CATKIN_SETUP_DIR/setup.sh"
