# drone-trainer-setup #
## ROS+Gazebo 드론 PPO 학습 환경 설치 ##
#### <div style="text-align: right"> Intelligent Unmanned Systems Group </div> #### 

---

### __개요__ ###
ROS와 Gazebo 상에서 동작하는 쿼드로터를 PPO 알고리즘을 이용하여 학습하는 코드.

#### __폴더 구성__ ####

  * trainer/ : 드론 시뮬레이션의 인터페이스가 정의된 패키지와 학습 코드가 담겨있습니다.
    * dronesim/ : 드론 시뮬레이션 인터페이스 패키지
    * simenv.py : 학습을 위한을 위한 OpenAI Gym Env 클래스 정의
    * test_drone_sim.py : dronesim 패키지 활용 예제 코드
    * test_simenv.py : PPO 알고리즘을 이용한 학습 코드 (willowgarage 월드 기준)
  * quadrotor/ : 쿼드로터 ROS 패키지의 소스코드가 있습니다. 사용을 위해서는 빌드해야 합니다.
  * env-setup/ : Anaconda 가상환경을 생성할 때 이용하는 파일입니다.
  * dot-gazebo/ : 건물 모델 파일입니다. 내용물을 ~/.gazebo/에 저장하면 됩니다.
  * setup-drone-trainer.sh : 자동 설치 스크립트입니다.
  * run-multiple-ros-gazebo.sh : 여러 개의 시뮬레이션 인스턴스를 실행할 때 사용하는 스크립트입니다.
  
#### __시스템 요구 사항__ ####

  * Ubuntu 16.04 혹은 Ubuntu 18.04
  * Anaconda 혹은 Miniconda (Python 3 권장, [링크](https://www.anaconda.com/distribution/))

### __설치법__ ###

본 리포지토리는 여러 서브모듈로 구성되어있습니다. 클론 후 서브모듈 설정이 필요합니다.

    git clone https://github.com/yonsei-ius/drone-trainer-setup.git
    git submodule init && git submodule update

처음 설치하는 경우 자동 설치 스크립트를 실행하여 설치하는 것을 권장합니다.

    ./setup-drone-trainer.sh

자동 설치 스크립트는 다음과 같은 과정을 수행합니다. (참고: dot-gazebo에 있는 파일은 설치 스크립트에서 복사하지 않습니다.)

  1. 시스템 요구 사항 확인
  2. sudo 권한 체크 (root 사용자의 경우 건너뜀)
  3. ROS 시스템 패키지 설치
  4. Anaconda 가상환경 생성 (Python2, ROS를 위한 'ros', Python3, Ray를 위한 'ray', 총 두 개 생성)
  5. 쿼드로터 ROS 패키지 빌드 및 환경 설정

각 단계는 이전에 해당 단계를 수행한 적이 있는지 확인하고, 수행한 적이 있을 경우 건너뜁니다.
따라서 중간단계에서 실패하여 스크립트가 종료되었을 경우, 문제 해결 후 다시 스크립트를 실행하면 됩니다. 

설치 스크립트 실행 도중에 진행 여부를 묻는 경우가 있는데, 아래와 같이 ```-y``` 옵션을 이용하면 완전 자동으로 설치가 가능합니다.

    ./setup-drone-trainer.sh -y

### __학습 환경 실행__ ###

학습 환경의 실행을 위해서는 두 개의 터미널이 필요합니다. 아래 명령을 순차적으로 실행시켜 학습 환경을 실행합니다.

#### 1) ROS 환경 터미널 ####

    conda activate ros
    roslaunch hector_quadrotor_demo drone_simul.launch

#### 2) Ray 환경 터미널 

    conda activate ray
    python trainer/test_simenv.py

### __알려진 문제점__ ###

#### 1. Gazebo 처음 실행 시 검은 화면만 표시됨 ####

처음으로 Gazebo에서 드론 시뮬레이션을 수행할 경우 환경을 준비 중이라는 메시지만 표시되고 가제보에는 검은 화면만 표시되는 경우가 있습니다. 몇 번 터미널에서 종료 후 재시작하면 해결되는 것으로 확인되었습니다.

#### 2. Goal 상자의 위치가 변경될 때 Gazebo 속도 저하 ####

시뮬레이션 초기화 시 Goal 상자를 삭제 후 새로운 위치에 재생성할 경우, 시뮬레이션 속도가 순간적으로 저하되는 경우가 있습니다. 이는 Goal 상자를 생성할 때 파일 정보를 ROS 마스터에게 매번 새롭게 보내기 때문에 일어나는 문제로, 추후 수정 예정입니다. 