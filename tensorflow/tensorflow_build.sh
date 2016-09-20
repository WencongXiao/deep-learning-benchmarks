#!/bin/bash

sudo rm -rf /tmp/tensorflow_pkg/
sudo apt-get install -y python-pip python-dev python-numpy swig python-dev python-wheel
sudo rm -rf tensorflow
git clone https://github.com/tensorflow/tensorflow 
cd tensorflow
git reset --hard bc64f05d4090262025a95438b42a54bfdc5bcc80

sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
# Hack to silently agree license agreement
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
sudo apt-get install -y oracle-java8-installer

sudo apt-get install pkg-config zip g++ zlib1g-dev
wget https://github.com/bazelbuild/bazel/releases/download/0.3.1/bazel-0.3.1-installer-linux-x86_64.sh
chmod +x bazel-0.3.1-installer-linux-x86_64.sh
sudo ./bazel-0.3.1-installer-linux-x86_64.sh --prefix=/

sudo ./configure
bazel build -c opt --config=cuda //tensorflow/tools/pip_package:build_pip_package
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
sudo /usr/bin/yes | pip uninstall tensorflow
sudo pip install /tmp/tensorflow_pkg/tensorflow*

cd ..
