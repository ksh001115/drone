1. 도커 이미지 빌드하고 .bashrc에 다음 내용 추가해줘야됨

export ROS_HOSTNAME=localhost
export OMP_NUM_THREADS=1; OPENBLAS_NUM_THREADS=1;

2. gpu용 이미지는 cuda용 베이스 이미지에서 빌드하고 ray용 conda 환경에서 기존 conda remove로 텐서플로우 삭제 후 conda install로 텐서플로우 GPU 설치 해야됨