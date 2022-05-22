#!/bin/bash
#This installs on singular system
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
sudo apt-get install apt-transport-https unzip
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update && sudo apt-get install elasticsearch kibana
sudo /usr/share/elasticsearch/bin/elasticsearch-certutil ca --pem --out /tmp/ca.zip
sudo unzip /tmp/ca.zip -d /tmp
#Cert setup
echo 'Please insert if you want 1.) IP address 2.) DNS entry, 3.) Both for Kibana and elasticsearch certificates'
read -p ">> Option: " option1
if [ $option1 -eq 1 ];
then
	read -p ">> IP Address: " ipAddress
            INSTANCES=$(cat <<EOF
instances:
  - name: "elasticsearch"
    ip:
      - "${ipAddress}"
  - name: "kibana"
    ip:
      - "${ipAddress}"
EOF
)
echo "${ipAddress}" > /tmp/dns.txt
echo "${INSTANCES}" > /tmp/instances.yml
fi

if [ $option1 -eq 2 ];
then
	echo "Would you like seperate DNS entries for Elasticsearch and Kibana"
	read -p "[Y/n]: " seperate
	if [ $seperate == "n" ]
	then	
		read -p ">> DNS Entry: " DNSAddress
        INSTANCES_NON_SEPERATE=$(cat <<EOF
instances:
  - name: "elasticsearch"
    dns:
      - "${DNSAddress}"
  - name: "kibana"
    dns:
      - "${DNSAddress}"
EOF
)
echo "${DNSAddress}" > /tmp/dns.txt
echo "${INSTANCES_NON_SEPERATE}" > /tmp/instances.yml
	else
		read -p ">> Elasticsearch DNS Entry: " ElasticDNS
		read -p ">> Kibana DNS Entry: " KibanaDNS
        INSTANCES_SEPERATE=$(cat <<EOF
instances:
  - name: "elasticsearch"
    dns:
      - "${ElasticDNS}"
  - name: "kibana"
    dns:
      - "${KibanaDNS}"
EOF
)
echo "${ElasticDNS}" > /tmp/dns.txt
echo "${INSTANCES_SEPERATE}" > /tmp/instances.yml

    fi
fi
if [ $option1 -eq 3 ]
then
echo "Would you like seperate DNS entries for Elasticsearch and Kibana"
	read -p "[Y/n]: " seperate
	if [ $seperate == "n" ]
	then	
		read -p ">> DNS Entry: " DNSAddress
    read -p ">> IP Address" ipAddress
    INSTANCES_NON_SEPERATE=$(cat <<EOF
instances:
  - name: "elasticsearch"
    dns:
      - "${DNSAddress}"
    ip:
      - "${ipAddress}"
  - name: "kibana"
    dns:
      - "${DNSAddress}"
    ip:
      - "${ipAddress}"
EOF
)
echo "${ipAddress}" > /tmp/dns.txt
echo "${INSTANCES_NON_SEPERATE}" > /tmp/instances.yml
else
		read -p ">> Elasticsearch DNS Entry: " ElasticDNS
		read -p ">> Kibana DNS Entry: " KibanaDNS
    read -p ">> IP Address: " ipAddress
        INSTANCES_SEPERATE=$(cat <<EOF
instances:
  - name: "elasticsearch"
    dns:
      - "${ElasticDNS}"
    ip:
      - "${ipAddress}"
  - name: "kibana"
    dns:
      - "${KibanaDNS}"
    ip:
      - "${ipAddress}"
EOF
)
echo "${ipAddress}" > /tmp/dns.txt
echo "${INSTANCES_SEPERATE}" > /tmp/instances.yml
fi
fi

sudo /usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca-cert /tmp/ca/ca.crt --ca-key /tmp/ca/ca.key --pem -s --in /tmp/instances.yml --out /tmp/bundled.zip
sudo unzip /tmp/bundled.zip -d /tmp
sudo mkdir /etc/elasticsearch/certs/ca -p
sudo cp /tmp/ca/ca.crt /etc/elasticsearch/certs/ca
sudo cp /tmp/elasticsearch/elasticsearch.crt /etc/elasticsearch/certs
sudo cp /tmp/elasticsearch/elasticsearch.key /etc/elasticsearch/certs
sudo chown -R elasticsearch: /etc/elasticsearch/certs
sudo chmod -R 770 /etc/elasticsearch/certs

ELASTICSEARCH_CONFIG=$(cat <<EOF
# ======================== Elasticsearch Configuration =========================
node.name: node-1
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
network.host: 0.0.0.0
http.port: 9200
cluster.initial_master_nodes: ["node-1"]
# X-Pack Setting
xpack.security.enabled: true
# Transport layer
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.key: /etc/elasticsearch/certs/elasticsearch.key
xpack.security.transport.ssl.certificate: /etc/elasticsearch/certs/elasticsearch.crt
xpack.security.transport.ssl.certificate_authorities: [ "/etc/elasticsearch/certs/ca/ca.crt" ]
# HTTP layer
xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.verification_mode: certificate
xpack.security.http.ssl.key: /etc/elasticsearch/certs/elasticsearch.key
xpack.security.http.ssl.certificate: /etc/elasticsearch/certs/elasticsearch.crt
xpack.security.http.ssl.certificate_authorities: [ "/etc/elasticsearch/certs/ca/ca.crt" ]
EOF
)
sudo echo "${ELASTICSEARCH_CONFIG}" > /etc/elasticsearch/elasticsearch.yml
sudo mkdir /etc/kibana/certs/ca -p
sudo cp /tmp/ca/ca.crt /etc/kibana/certs/ca
sudo cp /tmp/kibana/kibana.crt /etc/kibana/certs
sudo cp /tmp/kibana/kibana.key /etc/kibana/certs
sudo chown -R kibana: /etc/kibana/certs
sudo chmod -R 770 /etc/kibana/certs
KIBANA_CONFIG=$(cat <<EOF
server.port: 5601
server.host: "0.0.0.0"
#server.name: "your-hostname"
elasticsearch.hosts: []
elasticsearch.username: "kibana_system"
elasticsearch.password: ""
elasticsearch.ssl.certificateAuthorities: ["/etc/kibana/certs/ca/ca.crt"]
elasticsearch.ssl.certificate: "/etc/kibana/certs/kibana.crt"
elasticsearch.ssl.key: "/etc/kibana/certs/kibana.key"
# These settings enable SSL for outgoing requests from the Kibana server to the browser.
server.ssl.enabled: true
server.ssl.certificate: "/etc/kibana/certs/kibana.crt"
server.ssl.key: "/etc/kibana/certs/kibana.key"
xpack.security.encryptionKey: "something_at_least_32_characters"
xpack.encryptedSavedObjects.encryptionKey: "something_at_least_32_characters"
logging:
  appenders:
    file:
      type: file
      fileName: /var/log/kibana/kibana.log
      layout:
        type: json
  root:
    appenders:
      - default
      - file
pid.file: /run/kibana/kibana.pid
EOF
)
sudo echo "${KIBANA_CONFIG}" > /etc/kibana/kibana.yml
sudo service elasticsearch start
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system -a -s <<< 'y' > /tmp/password.txt
sudo sed -i 's/elasticsearch.hosts: \[]/elasticsearch.hosts: \["https:\/\/'"$(cat /tmp/dns.txt)"':9200"]/g' /etc/kibana/kibana.yml
sudo sed -i 's/elasticsearch.password: ""/elasticsearch.password: "'$(cat /tmp/password.txt)'"/g' /etc/kibana/kibana.yml
sudo /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -a -s <<< 'y' > /tmp/password.txt
echo "Please note down the elastic password for logging in to the Kibana GUI"
cat /tmp/password.txt
echo "Elasticsearch Restarted!"
sudo service kibana start
echo "Kibana restarted"
sudo systemctl enable elasticsearch
sudo systemctl enable kibana
#End of cert setup
sudo mkdir /usr/share/elasticsearch/certs -p
sudo mv /tmp/ca /usr/share/elasticsearch/certs
sudo mv /tmp/elasticsearch /usr/share/elasticsearch/certs
sudo mv /tmp/kibana /usr/share/elasticsearch/certs
sudo rm /tmp/*.zip
sudo rm -rf ca
sudo rm -rf elasticsearch
sudo rm -rf kibana
sudo rm password.txt
sudo rm dns.txt
sudo rm instances.yml