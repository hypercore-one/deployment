#!/bin/bash

# Set environment to noninteractive to prevent prompts during apt-get operations
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update

# Install required packages
apt-get install -y apt-transport-https software-properties-common wget curl

# Install Node Exporter
NODE_EXPORTER_VERSION="1.6.1"
echo "Installing Node Exporter..."
wget -q -O node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
useradd -rs /bin/false node_exporter
tee /etc/systemd/system/node_exporter.service > /dev/null << EOF
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
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

# Install Prometheus
PROMETHEUS_VERSION="2.47.0"
echo "Installing Prometheus..."
wget -q -O prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus/
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus/
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml /etc/prometheus/
useradd -rs /bin/false prometheus
tee /etc/systemd/system/prometheus.service > /dev/null << EOF
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
mkdir -p /var/lib/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz prometheus-${PROMETHEUS_VERSION}.linux-amd64

# Add Node Exporter job to Prometheus configuration
echo "Adding Node Exporter job to Prometheus configuration..."
tee -a /etc/prometheus/prometheus.yml > /dev/null <<EOL

  - job_name: "node"
    static_configs:
      - targets: ["localhost:9100"]
EOL

# Restart Prometheus to apply changes
systemctl restart prometheus

# Install Grafana
echo "Installing Grafana..."
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor |  tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" |  tee -a /etc/apt/sources.list.d/grafana.list > /dev/null
apt-get update
apt-get install -y grafana

# Start and enable Grafana service
systemctl start grafana-server
systemctl enable grafana-server

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
PROM_DASHBOARD_JSON_URL="https://grafana.com/api/dashboards/1860/revisions/latest/download"
echo "Importing Prometheus Node Exporter Dashboard..."
curl -s $PROM_DASHBOARD_JSON_URL -o /tmp/node_exporter_dashboard.json

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

# Install Infinity Datasource Plugin
INFINITY_PLUGIN_VERSION="2.10.0"
echo "Installing Infinity Datasource plugin..."
grafana-cli plugins install yesoreyeram-infinity-datasource $INFINITY_PLUGIN_VERSION
chown -R grafana:grafana /var/lib/grafana/plugins
systemctl restart grafana-server

# Wait for Grafana to start
echo "Waiting for Grafana to start..."
until curl -s http://localhost:3000 > /dev/null; do
  sleep 5
done

# Configure the Infinity datasource
echo "Configuring Infinity data source..."
curl -X POST -H "Content-Type: application/json" \
  -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD \
  -d '{
    "name": "yesoreyeram-infinity-datasource",
    "type": "yesoreyeram-infinity-datasource",
    "access": "proxy"
  }' \
  http://localhost:3000/api/datasources

# Get the current repository URL and branch.
GITHUB_REPO=$(git config --get remote.origin.url | sed 's/.*github.com[:\/]\(.*\)\.git/\1/')
GITHUB_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Construct the URL to download the dashboard
ZNND_DASHBOARD_JSON_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/dashboards/znnd.json"
echo "Importing znnd Dashboard from branch ${GITHUB_BRANCH} of repo ${GITHUB_REPO}..."
curl -s $ZNND_DASHBOARD_JSON_URL -o /tmp/znnd_dashboard.json

# Construct the final API request payload with the dashboard JSON
cat <<EOF > /tmp/import_znnd_dashboard.json
{
  "dashboard": $(cat /tmp/znnd_dashboard.json),
  "folderId": 0,
  "overwrite": true,
  "inputs": [{
              "name": "DS_YESOREYERAM-INFINITY-DATASOURCE",
              "type":"datasource",
              "pluginId": "yesoreyeram-infinity-datasource",
              "value": "yesoreyeram-infinity-datasource"}]
}
EOF

# Import the dashboard using the Grafana API
# api/dashboards/import is undocumented
curl -X POST -H "Content-Type: application/json" \
  -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD \
  -d @/tmp/import_znnd_dashboard.json \
  http://localhost:3000/api/dashboards/import

echo "Installation and configuration completed successfully."
