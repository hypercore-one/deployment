#!/bin/bash

# Update package lists
sudo apt-get update

# Install required packages
sudo apt-get install -y apt-transport-https software-properties-common wget curl

# Install Node Exporter
NODE_EXPORTER_VERSION="1.6.1"
echo "Installing Node Exporter..."
wget -O node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter
sudo tee /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

# Install Prometheus
PROMETHEUS_VERSION="2.47.0"
echo "Installing Prometheus..."
wget -O prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus/
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus/
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml /etc/prometheus/
sudo useradd -rs /bin/false prometheus
sudo tee /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus/

[Install]
WantedBy=multi-user.target
EOF
sudo mkdir -p /var/lib/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz prometheus-${PROMETHEUS_VERSION}.linux-amd64

# Add Node Exporter job to Prometheus configuration
echo "Adding Node Exporter job to Prometheus configuration..."
sudo tee -a /etc/prometheus/prometheus.yml > /dev/null <<EOL

  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]
EOL

# Restart Prometheus to apply changes
sudo systemctl restart prometheus

# Install Grafana following the official instructions
echo "Installing Grafana..."
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com beta main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update
sudo apt-get install -y grafana

# Start and enable Grafana service
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Wait for Grafana to start
echo "Waiting for Grafana to start..."
until curl -s http://localhost:3000 > /dev/null; do
  sleep 5
done

# Configure Prometheus as the default data source
GRAFANA_ADMIN_USER="admin"
GRAFANA_ADMIN_PASSWORD="admin"
PROMETHEUS_URL="http://localhost:9090"

echo "Configuring Prometheus as the default data source..."
curl -X POST -H "Content-Type: application/json" \
  -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "'"$PROMETHEUS_URL"'",
    "access": "proxy",
    "isDefault": true
  }' \
  http://localhost:3000/api/datasources

# Fetch and prepare the Prometheus Node Exporter Dashboard (ID 1860)
DASHBOARD_JSON_URL="https://grafana.com/api/dashboards/1860/revisions/latest/download"
echo "Importing Prometheus Node Exporter Dashboard..."
curl -s $DASHBOARD_JSON_URL -o /tmp/node_exporter_dashboard.json

# Construct the final API request payload with the dashboard JSON
cat <<EOF > /tmp/import_dashboard.json
{
  "dashboard": $(cat /tmp/node_exporter_dashboard.json),
  "folderId": 0,
  "overwrite": true
}
EOF

# Import the dashboard using the Grafana API
curl -X POST -H "Content-Type: application/json" \
  -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD \
  -d @/tmp/import_dashboard.json \
  http://localhost:3000/api/dashboards/db

echo "Installation and configuration completed successfully."

