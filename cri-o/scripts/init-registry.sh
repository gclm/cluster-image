#!/bin/bash
# Copyright © 2022 sealos.
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

source common.sh
# prepare registry storage as directory
cd $(dirname $0)

VOLUME=${1:-/var/lib/registry}
CONFIG=${2:-/etc/registry}
container=sealos-registry
htpasswd="$CONFIG/registry_htpasswd"
config="$CONFIG/registry_config.yml"

[ -d $VOLUME ] || mkdir $VOLUME
[ -d $CONFIG ] || mkdir $CONFIG

startRegistry() {
    n=1
    while (( $n <= 3 ))
    do
        echo "attempt to start registry"
        (nerdctl start $container && break) || (( n < 3))
        (( n++ ))
        sleep 3
    done
}

[ -f ../images/registry.tar  ] && ctr image import ../images/registry.tar
cp ../etc/registry_config.yml $config
cp -f ../cri/nerdctl /usr/bin/ && chmod a+x /usr/bin/nerdctl
[ -f ../etc/registry_htpasswd  ] && cp  ../etc/registry_htpasswd $htpasswd

## rm container if exist.

if [ "$(nerdctl ps --format='{{json .Names}}' | grep \"$container\")" ]; then
    nerdctl rm -f $container
fi

regArgs="-d --restart=always \
--net=host \
--name $container \
-v $VOLUME:/var/lib/registry "

if [ -f $config ]; then
    regArgs="$regArgs \
    -v $config:/etc/docker/registry/config.yml"
fi

if [ -f $htpasswd ]; then
    nerdctl run $regArgs \
            -v $htpasswd:/htpasswd \
            -e REGISTRY_AUTH=htpasswd \
            -e REGISTRY_AUTH_HTPASSWD_PATH=/htpasswd \
            -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" registry:2.7.1 || startRegistry
else
    nerdctl run $regArgs registry:2.7.1 || startRegistry
fi
logger "init registry success"
