#!/bin/bash

function get_value {
    FP_SECTION_NAME=$1
    FP_PARAMETER_NAME=$2
    sed -nr "/^\[$FP_SECTION_NAME\]/ { :l /^$FP_PARAMETER_NAME[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" ./.env.ini
    unset FP_SECTION_NAME
    unset FP_PARAMETER_NAME
}

function set_compose_ports {
    sed -i '5,$ d' docker-compose.ports.yml
    for fp_service in $(echo $(get_value global services) | tr ',' "\n")
    do
	FP_PORT=$(get_value $fp_service port)
	sed -i "$ a \ \ \ \ \ \ \ -\ \"$FP_PORT:$FP_PORT\"" docker-compose.ports.yml
	unset FP_PORT
    done
}

#changing directory
cd "$(dirname "$0")"

#run docker if must been enabled, but disabled
if test $(get_value global enabled) -eq 1; then
    set_compose_ports
    docker-compose down && docker-compose up -d
else
    exit
fi

#remove rules
docker-compose exec openvpn sh -c 'iptables -F FORWARD'

for fp_rule_index in $(docker-compose exec openvpn sh -c 'iptables --line-numbers --list PREROUTING -t nat' | awk '$2=="DNAT" {print $1}')
do
    FP_RULE_INDEXES="$fp_rule_index $FP_RULE_INDEXES"
done

for fp_rule_index in $FP_RULE_INDEXES
do
    docker-compose exec openvpn sh -c "iptables -t nat -D PREROUTING $fp_rule_index"
done
unset FP_RULE_INDEXES

#add rules

for fp_service in $(echo $(get_value global services) | tr ',' "\n")
do
    FP_RULE_MACHINE_IP=$(get_value $fp_service machine_ip)
    FP_RULE_PORT=$(get_value $fp_service port)
    echo "[$fp_service] $FP_RULE_MACHINE_IP:$FP_RULE_PORT"
    docker-compose exec openvpn sh -c "iptables -A PREROUTING -t nat -i eth0 -p tcp --dport $FP_RULE_PORT -j DNAT --to $FP_RULE_MACHINE_IP:$FP_RULE_PORT"
    docker-compose exec openvpn sh -c "iptables -A FORWARD -p tcp -d $FP_RULE_MACHINE_IP --dport $FP_RULE_PORT -j ACCEPT"
    unset FP_RULE_MACHINE_IP
    unset FP_RULE_PORT
done

#list rules
echo "[forward rules]"
docker-compose exec openvpn sh -c 'iptables -v -L FORWARD -n --line-number'
echo "[prerouting rules]"
docker-compose exec openvpn sh -c 'iptables -t nat -v -L PREROUTING -n --line-number'
