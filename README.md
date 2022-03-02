# OpenVPN server for ARM

## Features
- Generate client certificates
- Forward ports to clients

## After clone
Copy all `*.example` files to files without `.example` suffix.  

## Generate client certificate
For create new client certificate you can run
```bash
./generate_cert.sh config/ my_client_1 192.168.255.10
```
Where:
- `config/` : path to config dir (relative this directory)
- `my_client_1` : certificate name
- `192.168.255.10` : ip address for client (192.168.255.0/24)

## Forward ports
Port can be forwarded if you create "service" and add it to '[global]'' section in `.env.ini` file.  
Example of `.env.ini`  
```ini
[global]
enabled=1
services=minecraft,ssh

[minecraft]
machine_ip=192.168.255.10
port=25565

[ssh]
machine_ip=192.168.255.11
port=22
```

#### [global]
This section has two parameters:
- `enabled` : need to run containers if `./forward_ports.sh` been runned
- `services` : comma separated list of enabled services

### [service]
This section describes a `service` entity (you can create few services without limit)  
Each service section has two parameters:  
- `machine_ip` : vpn client ip to forward port 
- `port` : port

After creating a `service` section you can add it to `global.services`
