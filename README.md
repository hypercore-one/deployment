# Zenon Network Setup Script

This script automates the setup, management, and restoration of the Zenon Network (`go-zenon`) node. It handles dependencies installation, Go installation, Zenon deployment, and service management. The script also offers additional options for restoring from a bootstrap, monitoring logs, and installing Grafana for visualizing data.

## Features

- **Automated Go Installation**: Installs Go 1.23.0 (or another version if changed) based on the system architecture.
- **Automated Zenon Deployment**: Clones the `go-zenon` repository, builds it, and sets it up as a service.
- **Automated Dependencies Installation**: Installs `make`, `gcc`, and `jq` automatically without user intervention.
- **Zenon Service Management**: Provides options to stop, start, and restart the `go-zenon` service.
- **Restore from Bootstrap**: Downloads and runs a script to restore the node from a bootstrap.
- **Log Monitoring**: Allows you to monitor `znnd` logs in real-time.
- **Grafana Installation**: Optionally installs Grafana for monitoring Zenon metrics.
- **Non-Interactive Installations**: Automatically selects default options during package installation to avoid any prompts.

## Prerequisites

This script assumes you're running a Linux distribution that uses `apt` as a package manager (e.g., Ubuntu or Debian). You need to have `git` installed. You must also have superuser (root) privileges to execute this script.

## Usage

Clone the script or save it locally, then run it using a bash terminal:

```bash
sudo ./go-zenon.sh [OPTIONS]
```

### Options

- `--deploy`: Deploy and set up the Zenon Network.
- `--restore`: Restore `go-zenon` from a bootstrap.
- `--restart`: Restart the `go-zenon` service.
- `--stop`: Stop the `go-zenon` service.
- `--start`: Start the `go-zenon` service.
- `--status`: Monitor `znnd` logs.
- `--grafana`: Install Grafana for monitoring metrics.
- `--help`: Display the help message.

### Example Usage

#### Deploying Zenon Network

To deploy and set up the Zenon Network, run:

```bash
sudo ./go-zenon.sh --deploy
```

This will:
- Install required dependencies (`make`, `gcc`, `jq`).
- Download and install Go.
- Clone the `go-zenon` repository.
- Build the project.
- Set up and enable the `go-zenon` service.

#### Restoring from Bootstrap

To restore from a bootstrap, use:

```bash
sudo ./go-zenon.sh --restore
```

#### Monitoring Logs

To monitor the `znnd` logs, run:

```bash
sudo ./go-zenon.sh --status
```

#### Installing Grafana

To install Grafana for visualizing Zenon metrics:

```bash
sudo ./go-zenon.sh --grafana
```

### Customizing the Script

You can adjust the Go version or repository URL by modifying the following variables in the script:

- **Go version**: Set in the variable `GO_VERSION`. The default is `1.23.0`.
- **Repository URL**: By default, it uses `https://github.com/zenon-network/go-zenon.git`. You can input a different URL when prompted, or modify the script to always use a specific repository.

## Notes

- Ensure you run this script as root or use `sudo` for it to function properly.
- The script is designed to be non-interactive when installing dependencies, so you won't be prompted to select any options during the installation process.
- Be cautious when running the script, as it will automatically update and upgrade your system packages during the `apt-get` operations.

---

This `README.md` provides an overview of how to use the script, its features, and specific commands for deployment and service management. Let me know if you need any further adjustments!
