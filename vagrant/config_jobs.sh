#!/usr/bin/env bash
# Copyright 2019 Tecnalia Research & Innovation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e # To fail on errors

cd ~

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

apt install -y python3 python3-all python3-pip python3-venv
pyvenv --without-pip venv
. venv/bin/activate
curl https://bootstrap.pypa.io/pip/3.5/get-pip.py | python3
pip3 install empy
pip3 install jenkinsapi
pip3 install rosdistro
pip3 install catkin_pkg
pip3 install ros_buildfarm

cd ~

#git clone --single-branch -b master https://github.com/ros-infrastructure/ros_buildfarm_config.git
cd ros_buildfarm_config
# Change the hostnames of the yaml files by fixed IP addresses
sed -i 's#\(jenkins_url: \)\(.*\)$*#\1http://192.168.50.10:8080#g' index.yaml
find . -type f -name '*.yaml' -exec sed -i 's#\([:space]*- http://\)\([a-z\.\-]*\)/\([a-zA-Z]*\)/\([a-zA-Z]*\)#\1192.168.50.11/\3/\4#g' {} \;
find . -type f -name '*.yaml' -exec sed -i 's#\(target_repository: http://\)\([a-z\.\-]*\)/\([a-zA-Z]*\)/\([a-zA-Z]*\)#\1192.168.50.11/\3/\4#g' {} \;
find . -type f -name '*.yaml' -exec sed -i 's#\(canonical_base_url: http://\)\([a-z\.\-]*\)/\([a-zA-Z]*\)#\1192.168.50.11/\3#g' {} \;
sed -i 's#^rosdistro_index_url: [[:print:]]*$#rosdistro_index_url: http://192.168.50.10:8082/index.yaml#g' index.yaml
docker run -d --restart unless-stopped --name buildfarm_config -p 8081:80 -v "$PWD":/usr/share/nginx/html:ro nginx:alpine

cd ~

git clone --single-branch -b master https://github.com/ros/rosdistro.git
cd rosdistro/
sed -i 's#\(distribution_cache: http://\)\([a-z\.\-]*\)#\1192.168.50.11#g' index.yaml
docker run -d --restart unless-stopped --name rosdistro -p 8082:80 -v "$PWD":/usr/share/nginx/html:ro nginx:alpine

generate_all_jobs.py --commit http://192.168.50.10:8081/index.yaml
