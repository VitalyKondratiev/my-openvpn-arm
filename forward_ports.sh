#!/bin/bash

function get_value {
    FP_SECTION_NAME=$1
    FP_PARAMETER_NAME=$2
    sed -nr "/^\[$FP_SECTION_NAME\]/ { :l /^$FP_PARAMETER_NAME[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" ./.env.ini
    unset FP_SECTION_NAME
    unset FP_PARAMETER_NAME
}

function set_compose_ports {
    sed -i "3s/\w*:/$FP_VPN_TYPE:/g" docker-compose.ports.yml
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

FP_VPN_TYPE=$(get_value global type)

set_compose_ports

#check if docker running
if [ $(docker-compose ps -q | wc -l) -eq 0 ]; then
    FP_DOCKER_RUNNING=0
else
    docker-compose down
    FP_DOCKER_RUNNING=1
fi

FP_RULES="iptables -F FORWARD"

#remove rules
for fp_rule_index in $(docker-compose run $FP_VPN_TYPE sh -c 'iptables --line-numbers --list PREROUTING -t nat' | awk '$2=="DNAT" {print $1}' | sort -r)
do
    FP_NEW_RULE_REMOVE=$(echo "iptables -t nat -D PREROUTING $fp_rule_index")
    FP_RULES=$(echo -e "${FP_RULES} && ${FP_NEW_RULE_REMOVE}")
done

#add rules

for fp_service in $(echo $(get_value global services) | tr ',' "\n")
do
    FP_RULE_MACHINE_IP=$(get_value $fp_service machine_ip)
    FP_RULE_PORT=$(get_value $fp_service port)
    echo "[$fp_service] $FP_RULE_MACHINE_IP:$FP_RULE_PORT"
    FP_NEW_RULE_PREROUTING=$(echo "iptables -A PREROUTING -t nat -i eth0 -p tcp --dport $FP_RULE_PORT -j DNAT --to $FP_RULE_MACHINE_IP:$FP_RULE_PORT")
    FP_NEW_RULE_FORWARD=$(echo "iptables -A FORWARD -p tcp -d $FP_RULE_MACHINE_IP --dport $FP_RULE_PORT -j ACCEPT")
    FP_RULES=$(echo -e "${FP_RULES} && ${FP_NEW_RULE_PREROUTING} && ${FP_NEW_RULE_FORWARD}")
    unset FP_RULE_MACHINE_IP
    unset FP_RULE_PORT
    unset FP_NEW_RULE_PREROUTING
    unset FP_NEW_RULE_FORWARD
done

#save rules to external file
docker-compose run $ sh -c "$FP_RULES && iptables-save > /usr/local/share/.rules" 2> /dev/null

#add executor to end of WG PostUp
[ -f ./config_wg/wg0.conf ] && cat ./config_wg/wg0.conf | grep -i '^PostUp.*MASQUERADE' && sed -i '/^PostUp =.*MASQUERADE$/ s/$/; sh \/entrypoint.sh/' ./config_wg/wg0.conf

#restart if needed
[ "$FP_DOCKER_RUNNING" -eq 1 ] && docker-compose up -d
