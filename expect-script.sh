#!/bin/bash

cd "$(dirname "$0")"

ES_LAN_IPADDR="$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"

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

ES_STATIC_ROUTES=$(run_on_router "show running-config" | grep 'ip static' | sed '/^[[:space:]]*$/d' | sed $'s/\r$//')
ES_OVPN_ROUTES=$(echo "$ES_STATIC_ROUTES" | grep -oP '^.*.!ovpn service:.*$')
echo "$ES_STATIC_ROUTES" > "$(pwd)/.routes"

if [ ! -z "$ES_OVPN_ROUTES" ]
then

    echo "Rules to be removed:"
    echo "$ES_OVPN_ROUTES"
    echo

    eval "run_on_router $(echo "$ES_OVPN_ROUTES" | tr '\n' '\0' | xargs -0 printf '"no %s" ') | grep 'Network::StaticNat'" 

fi

run_on_router "system configuration save" | grep 'Core::ConfigurationSaver'
