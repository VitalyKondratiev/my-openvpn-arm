#!/bin/bash

function get_value {
    FP_SECTION_NAME=$1
    FP_PARAMETER_NAME=$2
    sed -nr "/^\[$FP_SECTION_NAME\]/ { :l /^$FP_PARAMETER_NAME[ ]*=/ { s/[^=]*=[ ]*//; p; q;}; n; b l;}" ./.env.ini
    unset FP_SECTION_NAME
    unset FP_PARAMETER_NAME
}

function run_on_router {
    local ES_COMMAND_POOL=("$@")
    local ES_COMMAND_SEQ=$(printf 'send "%s\\r"\nexpect "t(config)> "\n' "${@}")
local ES_SCRIPT=$(cat <<END
#!/usr/bin/expect
spawn telnet $::env(ROUTER_ADDRESS)
expect "Login: "
send "$::env(ROUTER_USERNAME)\r"
expect "Password: "
send "$::env(ROUTER_PASSWORD)\r"
expect "t(config)> "
${ES_COMMAND_SEQ}
send "exit\r"
interact
END
    )
    echo "$ES_SCRIPT" | docker-compose run expect-telnet expect
}

#changing directory
cd "$(dirname "$0")"

#run docker if must been enabled, but disabled
if ! test $(get_value global enabled) -eq 1; then
    exit
fi

ES_STATIC_ROUTES=$(run_on_router "show running-config" | grep 'ip static' | sed '/^[[:space:]]*$/d' | sed $'s/\r$//')
ES_OVPN_ROUTES=$(echo "$ES_STATIC_ROUTES" | grep -oP '^.*.!ovpn service:.*$')
echo "$ES_STATIC_ROUTES" > "$(pwd)/.routes"

#remove old rules
if [ ! -z "$ES_OVPN_ROUTES" ]
then

    echo "Rules to be removed:"
    echo "$ES_OVPN_ROUTES"
    echo

    eval "run_on_router $(echo "$ES_OVPN_ROUTES" | tr '\n' '\0' | xargs -0 printf '"no %s" ') | grep 'Network::StaticNat'" 

fi

#add new rules
ES_LAN_IPADDR="$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

ES_OVPN_NEW_ROUTES=""

for es_service in $(echo $(get_value global services) | tr ',' "\n")
do
    ES_RULE_PORT=$(get_value $es_service port)
    ES_OVPN_NEW_ROUTE=$(echo "ip static tcp PPTP0 $ES_RULE_PORT $ES_LAN_IPADDR $ES_RULE_PORT !ovpn service: $es_service")
    ES_OVPN_NEW_ROUTES=$(echo -e "${ES_OVPN_NEW_ROUTES}\n${ES_OVPN_NEW_ROUTE}")
    unset ES_OVPN_NEW_ROUTE
    unset ES_RULE_PORT
done

ES_OVPN_NEW_ROUTES=$(echo "$ES_OVPN_NEW_ROUTES" | sed '/^[[:space:]]*$/d' | sed $'s/\r$//')

if [ ! -z "$ES_OVPN_NEW_ROUTES" ]
then

    echo "Rules to be addded:"
    echo "$ES_OVPN_NEW_ROUTES"
    echo

    eval "run_on_router $(echo "$ES_OVPN_NEW_ROUTES" | tr '\n' '\0' | xargs -0 printf '"%s" ') | grep 'Network::StaticNat'" 

fi

run_on_router "system configuration save" | grep 'Core::ConfigurationSaver'
