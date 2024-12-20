# Zenon Network Setup Script

This script automates the setup, management, and restoration of both Zenon Network (`go-zenon`) and HyperQube (`hyperqube_z`) nodes. It handles dependencies installation, Go installation, node deployment, and service management. The script also offers additional options for restoring from a bootstrap, monitoring logs, and installing Grafana for visualizing data.

## Features

- **Multiple Node Support**: Deploy and manage both Zenon Network and HyperQube nodes
- **Automated Go Installation**: Installs Go 1.23.0 (or another version if changed) based on the system architecture
- **Automated Node Deployment**: Clones the repository, builds it, and sets it up as a service
- **Automated Dependencies Installation**: Installs `make`, `gcc`, and `jq` automatically without user intervention
- **Service Management**: Provides options to stop, start, and restart the services
- **Restore from Bootstrap**: Downloads and runs a script to restore the node from a bootstrap
- **Log Monitoring**: Allows you to monitor logs in real-time
- **Grafana Installation**: Optionally installs Grafana for monitoring metrics
- **Non-Interactive Installations**: Automatically selects default options during package installation to avoid any prompts

## Prerequisites

This script assumes you're running a Linux distribution that uses `apt` as a package manager (e.g., Ubuntu or Debian). You need to have `git` installed. You must also have superuser (root) privileges to execute this script.

## Usage

Clone the script or save it locally, then run it using a bash terminal:

```bash
sudo ./go-zenon.sh [OPTIONS]
```

### Options

- `--deploy`: Deploy and set up the Zenon Network
- `--deploy --hq [URL]`: Deploy and set up the HyperQube Network (optional custom repository URL)
- `--buildSource [URL]`: Build from a specific source repository
- `--restore`: Restore from a bootstrap
- `--restart`: Restart the service
- `--stop [--hq]`: Stop the node service (add --hq for HyperQube)
- `--start [--hq]`: Start the node service (add --hq for HyperQube)
- `--status [--hq]`: Monitor logs (add --hq for HyperQube)
- `--grafana`: Install Grafana for monitoring metrics
- `--help`: Display the help message

### Example Usage

#### Deploying Nodes

To deploy the Zenon Network:
```bash
sudo ./go-zenon.sh --deploy
```

To deploy HyperQube:
```bash
sudo ./go-zenon.sh --deploy --hq
```

To deploy HyperQube with a custom repository:
```bash
sudo ./go-zenon.sh --deploy --hq https://github.com/your-fork/hyperqube_z.git
```

#### Managing Services

Start Zenon service:
```bash
sudo ./go-zenon.sh --start
```

Start HyperQube service:
```bash
sudo ./go-zenon.sh --start --hq
```

Stop Zenon service:
```bash
sudo ./go-zenon.sh --stop
```

Stop HyperQube service:
```bash
sudo ./go-zenon.sh --stop --hq
```

Monitor Zenon logs:
```bash
sudo ./go-zenon.sh --status
```

Monitor HyperQube logs:
```bash
sudo ./go-zenon.sh --status --hq
```

### Default Configurations

#### Zenon Network
- Repository: https://github.com/zenon-network/go-zenon.git
- Branch: master
- Binary: znnd
- Service: go-zenon

#### HyperQube
- Repository: https://github.com/hypercore-one/hyperqube_z.git
- Branch: hyperqube_z
- Binary: hqzd
- Service: go-hyperqube

### Customizing the Script

You can adjust the Go version by modifying the `GO_VERSION` variable in the script. The default is `1.23.0`.

## Notes

- Ensure you run this script as root or use `sudo` for it to function properly
- The script is designed to be non-interactive when installing dependencies
- Be cautious when running the script, as it will automatically update and upgrade your system packages during the `apt-get` operations
- When no options are specified, the script defaults to deploying a Zenon Network node

---

This `README.md` provides an overview of how to use the script, its features, and specific commands for deployment and service management. Let me know if you need any further adjustments!
