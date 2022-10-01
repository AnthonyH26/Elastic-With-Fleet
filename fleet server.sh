#!/bin/bash
echo "Please ensure you have set the default settings for Elasticsearch in the web UI first"
sudo apt install elastic-agent -y
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca --pem -s --out /tmp/fleet_ca.zip
sudo mkdir /usr/share/elasticsearch/certs/fleet -p
sudo unzip /tmp/fleet_ca.zip -d /usr/share/elasticsearch/certs/fleet
echo 'Please insert if you want 1.) IP address 2.) DNS entry, 3.) Both for fleet server certificates'
read -p ">> Option: " option1
if [ $option1 -eq 1 ];
then
	read -p ">> IP Address: " ipAddress
            INSTANCES=$(cat <<EOF
instances:
  - name: "fleet-server"
    ip:
      - "${ipAddress}"
EOF
)
echo "${INSTANCES}" > /tmp/fleet_instances.yml
fi

if [ $option1 -eq 2 ];
then

read -p ">> DNS Entry: " DNSAddress
INSTANCES_NON_SEPERATE=$(cat <<EOF
instances:
  - name: "fleet-server"
    dns:
      - "${DNSAddress}"
EOF
)
echo "${INSTANCES_NON_SEPERATE}" > /tmp/fleet_instances.yml
fi
if [ $option1 -eq 3 ]
then
		read -p ">> DNS Entry: " DNSAddress
    read -p ">> IP Address" ipAddress
    INSTANCES_NON_SEPERATE=$(cat <<EOF
instances:
  - name: "fleet-server"
    dns:
      - "${DNSAddress}"
    ip:
      - "${ipAddress}"
EOF
)
echo "${INSTANCES_NON_SEPERATE}" > /tmp/fleet_instances.yml
fi
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca-cert /usr/share/elasticsearch/certs/fleet/ca/ca.crt --ca-key /usr/share/elasticsearch/certs/fleet/ca/ca.key --pem -s --in /tmp/fleet_instances.yml --out /tmp/fleet_server.zip
sudo unzip /tmp/fleet_server.zip -d /usr/share/elasticsearch/certs/fleet
sudo cp /usr/share/elasticsearch/certs/fleet/ca/ca.crt /usr/local/share/ca-certificates/elastic-fleet.crt
sudo update-ca-certificates
echo "Please enter the fleet server that was also entered into the Web UI including the port and http/https"
read -p ">> Fleet Server Address: " fleetAddress
echo "Please enter the Elasticsearch Address entered into the Web UI including the port and http/https"
read -p ">> Elasticsearch Server Address: " elasticAddress
echo "Please enter the service token given from the web UI"
read -p ">> Service Token: " serviceToken
FLEET_STARTUP=$(cat <<EOF
sudo elastic-agent enroll --url=$fleetAddress \
  --fleet-server-es=$elasticAddress \
  --fleet-server-service-token=$serviceToken \
  --fleet-server-policy=fleet-server-policy \
  --certificate-authorities=/usr/share/elasticsearch/certs/fleet/ca/ca.crt \
  --fleet-server-es-ca=/usr/share/elasticsearch/certs/elasticsearch/elasticsearch.crt \
  --fleet-server-cert=/usr/share/elasticsearch/certs/fleet/fleet-server/fleet-server.crt \
  --fleet-server-cert-key=/usr/share/elasticsearch/certs/fleet/fleet-server/fleet-server.key
EOF
)

$FLEET_STARTUP
echo "Starting Agent service!"
sudo service elastic-agent start
echo "Agent started, please check in the Web UI"
sudo systemctl enable elastic-agent