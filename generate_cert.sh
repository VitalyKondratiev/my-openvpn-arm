#!/bin/bash

GC_CONF_DIR=$1
GC_CLIENT=$2
GC_IP_ADDRESS=$3

test -z "$GC_CONF_DIR" && echo 'First parameter must be a valid relative directory path' && exit
test -z "$GC_CLIENT" && echo 'Second parameter must be a string (certificate name)' && exit
(echo "$GC_IP_ADDRESS" | grep -Eq ^192\.168\.255\.[0-9]{1\,2}$) || (echo 'Third parameter must be a valid IP address' && exit)

if test ! -f $(pwd)/$GC_CONF_DIR/openvpn.conf; then
    docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --rm giggio/openvpn-arm ovpn_genconfig -u tcp://46.165.33.220
fi

if test ! -d $(pwd)/$GC_CONF_DIR/pki; then
    docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --rm -it giggio/openvpn-arm ovpn_initpki nopass
fi

# generate client
docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --rm -it giggio/openvpn-arm easyrsa build-client-full $GC_CLIENT nopass
docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --rm giggio/openvpn-arm ovpn_getclient $GC_CLIENT > $GC_CLIENT.ovpn

# set static ip to client
docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --rm giggio/openvpn-arm sh -c 'grep -Fq "client-config-dir" /etc/openvpn/openvpn.conf || sed -i "$ a client-config-dir /etc/openvpn/ccd" /etc/openvpn/openvpn.conf'
docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --rm giggio/openvpn-arm sh -c 'grep -Fq "topology" /etc/openvpn/openvpn.conf || sed -i "$ a topology subnet" /etc/openvpn/openvpn.conf'
docker run -v $(pwd)/$GC_CONF_DIR:/etc/openvpn --env GC_IP_ADDRESS=$GC_IP_ADDRESS --env GC_CLIENT=$GC_CLIENT --rm giggio/openvpn-arm sh -c 'echo "ifconfig-push $GC_IP_ADDRESS 255.255.0.0" >> /etc/openvpn/ccd/$GC_CLIENT'
