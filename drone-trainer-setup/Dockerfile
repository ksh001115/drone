
# CPU-only 도커 이미지
FROM ubuntu:18.04
# CPU+GPU 도커 이미지
# FROM nvidia/cuda:10.0-cudnn7-runtime-ubuntu18.04

ENV PATH /opt/conda/bin:$PATH
ENV DISPLAY :99

RUN sed -i -e 's/archive.ubuntu.com/mirror.kakao.com/g' /etc/apt/sources.list && \
    apt update --fix-missing && \
    apt upgrade -y && \
    apt install -y build-essential cmake git vim tmux curl htop xvfb unzip

RUN cd $HOME && \
    curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -L -o miniconda.sh && \
    /bin/bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh && \
    conda init

COPY . /drone-trainer
RUN cd drone-trainer && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime && \
    /bin/bash ./setup-drone-trainer.sh -y && \
    echo "export ROS_HOSTNAME=localhost" >> ~/.bashrc && \
    echo "export OMP_NUM_THREADS=1; OPENBLAS_NUM_THREADS=1;" >> ~/.bashrc

RUN TINI_VERSION=`curl https://github.com/krallin/tini/releases/latest | grep -o "/v.*\"" | sed 's:^..\(.*\).$:\1:'` && \
    curl -L "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini_${TINI_VERSION}.deb" > tini.deb && \
    dpkg -i tini.deb && \
    rm tini.deb

ENTRYPOINT ["/usr/bin/tini", "--"]

CMD ["/bin/bash"]
