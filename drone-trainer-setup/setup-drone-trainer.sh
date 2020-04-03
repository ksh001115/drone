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

function sudo_check(){
  _msg 0 "Sudo privileges are required for installation."
  sudo -v
  _msg 1 "Privilege check failed."
}

function yes_or_no(){

  if [ -z ${AUTO+x} ]; then
    echo -n "$1 (yes/no) "
    read ans
  else
    ans="y"
  fi
}

function sys_conf(){
  OS_NAME=$(head /etc/os-release -n 1 | awk -F '=' '{print $2}' | tr -d '"')
  OS_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | tr -d '"')

  if [ $OS_VERSION != "16.04" ] && [ $OS_VERSION != "18.04" ] || [ $OS_NAME != "Ubuntu" ]; then
    false
    _msg 1 "Your OS is not supported. (REQUIRED: Ubuntu 16.04, Ubuntu 18.04)"
  elif [ $OS_VERSION == "16.04" ]; then
    ROS_DIST="kinetic"
    OS_CODENAME="xenial"
  elif [ $OS_VERSION == "18.04" ]; then
    ROS_DIST="melodic"
    OS_CODENAME="bionic"
  fi

  echo "Host OS: $OS_NAME $OS_VERSION, Required ROS Version: $ROS_DIST"

  if [ $USER != "root" ]; then
    SUDO="sudo"
    sudo_check
  else
    _msg 2 "root user detected. Skipping privilege check."
  fi

  conda -V > /dev/null 2>&1
  _msg 1 "Please check if anaconda is installed. (REQUIRED: Anaconda available at https://www.anaconda.com/distribution/ )"
  conda activate >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    _CONDA_BASE=$(dirname $(dirname $(which conda)))
    . $_CONDA_BASE/etc/profile.d/conda.sh
  fi

}

function check_missing_packages(){
  dpkg -l | grep "$1" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    ROS_PKGS="$1 $ROS_PKGS"
  fi
}

function setup_ros(){
  # Install ROS
  _msg 0 "Checking if ros-$ROS_DIST-desktop-full is installed..."
  dpkg -l | grep "ros-$ROS_DIST-desktop-full" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "ros-$ROS_DIST-desktop-full already installed."
  else
    _msg 2 "ros-$ROS_DIST-desktop-full is not installed."
    yes_or_no "Do you want to install the package now?"
    case $ans in
      y|Y|YES|yes|Yes)
	_msg 0 "Installing ros-$ROS_DIST-desktop-full"
	grep "ros.org" /etc/apt/sources.list.d/ros-latest.list >/dev/null 2>&1
	if [ $? -ne 0 ]; then
	  _msg 0 "Setting up sources.list and apt keys"
	  $_CMD $SUDO sh -c "echo \"deb http://packages.ros.org/ros/ubuntu "$OS_CODENAME" main\" > /etc/apt/sources.list.d/ros-latest.list"
	  $_CMD $SUDO apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
	  _msg 1 "Failed to add apt-key."
	fi
	$_CMD $SUDO apt update
	$_CMD $SUDO apt install $AUTO ros-$ROS_DIST-desktop-full
	_msg 1 "Failed to install ROS packages."
	;;
      *)
	_msg 2 "You have canceled the installation of ros-$ROS_DIST-desktop-full."
	_msg 2 "The system may not have the required packages."
	;;
    esac
    unset ans
  fi

  _msg 0 "Checking if additional packages are installed..."
  # ROS Packages
  pkgs="geographic-info joy hardware-interface controller-interface gazebo-ros-control teleop-twist-keyboard"
  for pkg in $pkgs
  do
    check_missing_packages "ros-$ROS_DIST-$pkg"
  done
  # Non-ROS Packages
  pkgs="qt4-default xvfb x11-xserver-utils"
  for pkg in $pkgs
  do
    check_missing_packages "$pkg"
  done

  if [ ! -z ${ROS_PKGS+x} ]; then
    _msg 0 "Additional package installation is required to proceed."
    yes_or_no "Do you want to install the package now?"
    case $ans in
      y|Y|YES|yes|Yes)
	$_CMD $SUDO apt update
	$_CMD $SUDO apt install $AUTO $ROS_PKGS
	_msg 1 "Failed to install ROS packages."
	;;
      *)
	false
	_msg 1 "Unable to install required packages."
	;;
    esac
    unset ans
  else
    _msg 0 "All required ROS packages are installed."
  fi 

  if [ ! -f "/etc/ros/rosdep/sources.list.d/20-default.list" ]; then
    _msg 0 "Updating ROS dependency..."
    $_CMD $SUDO rosdep init
    _msg 1 "rosdep init failed."
    $_CMD rosdep update
    _msg 1 "rosdep update failed."
    _msg 0 "ROS dependency update complete."
  fi
  
  gazebo --version >/dev/null 2>&1
  if [ -f ~/.ignition/fuel/config.yaml ]; then
    $_CMD sed -i 's/ignitionfuel/ignitionrobotics/g' ~/.ignition/fuel/config.yaml
  fi

}

function setup_conda_env(){

  conda env list | grep $1 >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    _msg 0 "The conda environment '$1' is already set up."
  else
    _msg 0 "Creating a new conda environment '$1'..."
     $_CMD conda env create -f "env-setup/$1.yml"
    _msg 1 "Failed to create the conda environment."
     conda activate "$1"
     $_CMD cp -a env-setup/"$1"/* ${CONDA_PREFIX}/
     conda deactivate
  fi
  
  echo -n "Testing..."
  conda activate "$1"
  $_CMD python -c "$2" >/dev/null 2>&1
  _test=$?
  conda deactivate
  if [ $_test -ne 0 ]; then
    echo
    false
    _msg 1 "Test Failed. Cannot import required python packages. Please remove conda env '$1' and retry."
  fi
  echo "Done"
  unset _test

}

function check_gpu(){
  
  which nvidia-smi >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    conda activate ray
    conda list | grep tensorflow-gpu >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      _msg 0 "NVIDIA GPU detected. Installing tensorflow-gpu..."
      $_CMD conda remove -y tensorflow
      _msg 1 "Failed to remove tensorflow."
      $_CMD conda install -y tensorflow-gpu=1.13.1
      _msg 1 "Failed to install tensorflow-gpu."
      conda list | grep tensorflow-gpu >/dev/null 2>&1
      _msg 1 "Failed to install tensorflow-gpu."
    fi
    conda deactivate
  fi
}

function build_quadrotor(){

  _msg 0 "Building hector_quadrotor ROS package..."
  conda activate ros
  cd quadrotor
  if [ -d build ]; then
    _msg 0 "Found a directory named 'build'. It looks like you built it previously."
    yes_or_no "Do you want to build the quadrotor package now?"
    case $ans in
      y|Y|YES|yes|Yes)
      	 $_CMD catkin_make clean
	 $_CMD catkin_make
	_test=$?
	;;
      *)
	_msg 2 "You have canceled build of quarotor package."
	_msg 2 "You can build it manually by executing 'catkin_make' in directory 'quadrotor'"
	;;
    esac
    unset ans
  else
     $_CMD catkin_make
    _test=$?
  fi
  cd ..
  conda deactivate
  
  if [ ! -z ${_test+x} ] && [ $_test -ne 0 ]; then
    false
    _msg 1 "Failed to build quadrotor package."
  fi
  _msg 0 "hector_quadrotor build complete."

}

function add_setup_bash(){

  conda activate $1
  _SETUP_SH="$CONDA_PREFIX/etc/conda/activate.d/setup.sh"
  if [ -z ${_CMD+x} ]; then
    _OUT="$_SETUP_SH"
  else
    _OUT="/dev/stdout"
  fi

  grep 'quadrotor/devel/setup.bash' $_SETUP_SH >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    _msg 2 "quadrotor/devel/setup.bash is already registered. Update to the latest version."
    $_CMD sed -i '/quadrotor\/devel\/setup.bash/d' $_SETUP_SH
    _msg 1 "Failed to edit conda activate script."
    if [ $1 == "ray" ]; then
      $_CMD sed -i '/site-packages/d' $_SETUP_SH
      _msg 1 "Failed to edit conda activate script."
    fi
  fi

  echo "source $(pwd)/setup.bash" >> $_OUT
  _msg 1 "Failed to edit conda activate script."
  if [ $1 == "ray" ]; then
    echo "export PYTHONPATH=\"\$CONDA_PREFIX/lib/python3.6/site-packages:\$PYTHONPATH\"" >> "$_OUT"
    _msg 1 "Failed to edit conda activate script."
  fi
  conda deactivate

}


_msg "Installation process started."
while [ $# -gt 0 ]
do
  case $1 in
    -y|--yes)
      _msg 2 "-y is set. The installation will proceed automatically."
      AUTO="-y"
      ;;
    -D|--debug)
      _msg 2 "Set to debug mode. Some commands will be echoed instead of running."
      _CMD="echo"
      ;;
    -h|--help)
      echo "Usage: setup-drone-trainer [-h|--help] [-y]"
      echo
      echo " -h | --help    display this help and exit"
      echo " -y | --yes     automatic yes to prompts"             
      exit
      ;;
    *)
      false
      _msg 1 "Unknown option."
      ;;
  esac
  shift
done

sys_conf

setup_ros

_msg "Setting up conda virtual environment..."
setup_conda_env ray "import ray; import tensorflow; ray.init()"
check_gpu
setup_conda_env ros "import rosinstall; import em;"
_msg "All conda environments are set up."

build_quadrotor
yes_or_no "Do you want setup.bash to run automatically when conda environment is activated?"
case $ans in
  y|Y|YES|yes|Yes)
    _msg 0 "Setting 'quadrotor/devel/setup.bash' to run automatically when conda environment is activated..."
    cd quadrotor/devel/
    add_setup_bash ray
    add_setup_bash ros
    cd ../..
    ;;
  *)
    _msg 2 "setup.bash is set to run manually."
    _msg 2 "Please run 'source $(pwd)/quadrotor/devel/setup.bash' after the conda activate"
    ;;
esac
_msg 0 "Copying indoor environment model files..."
mkdir -p ~/.gazebo
cp -a dot-gazebo/models ~/.gazebo/
_msg 1 "Cannot copy indoor environment model files. Check your permission"


_msg "Installation of drone-trainer complete."



