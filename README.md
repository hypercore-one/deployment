# Deployment

This script facilitates the deployment, management, and restoration of [Zenon Network](https://zenon.network) and [HyperQube](https://hyperqube.network) nodes. It provides an interactive TUI for ease of use and non-interactive commands for automation.

## Quick Start

Follow these steps on a Linux server:

1. Clone the repository
   ```bash
   git clone https://github.com/hypercore-one/deployment.git
   ```
2. Enter the directory
   ```bash
   cd deployment
   ```
3. Make the script executable (first run only)
   ```bash
   chmod u+x zenon.sh
   ```
4. Launch the interactive TUI (requires root privileges)
   ```bash
   sudo ./zenon.sh
   ```

## Requirements

- **OS**: Linux with `apt` available (Debian/Ubuntu family).
- **Architecture**: x86_64/amd64 only. Other architectures are currently not supported and the script will exit early.
- **Permissions**: Root/sudo access required for system service management and file operations.

## Features

- Interactive TUI via [gum](https://github.com/charmbracelet/gum)
- Deploy – build a node from source
- Backup & Restore – manually backup and restore the node, or schedule automatic backups
- Service Control – start, stop, and restart the node
- Resync Node – resynchronize the node from genesis
- Analytics – graphical dashboards for monitoring node performance and health via [Grafana](https://grafana.com)


## Interactive Usage

The interactive TUI is the recommended approach for most users:

| Action | Command | Notes |
|--------|---------|-------|
| Launch TUI | `sudo ./zenon.sh` or `sudo ./zenon.sh [zenon\|hyperqube]` | Launches interactive menu. `zenon` is default. |

For HyperQube usage, use `sudo ./zenon.sh hyperqube`.

## Non-Interactive Usage

For automation and scripting, use the following commands:

| Action | Command | Notes |
|--------|---------|-------|
| Deploy | `sudo ./zenon.sh --deploy [zenon\|hyperqube] [repo_url] [branch_name]` | `zenon` is default. `repo_url` and `branch_name` are optional. |
| Backup | `sudo ./zenon.sh --backup [zenon\|hyperqube] [--max-backups N] [--cadence DAYS] [--backup-hour HOUR]` | `zenon` is default. Creates backup snapshots. Use TUI for scheduling automated backups. |
| Restore | `sudo ./zenon.sh --restore [zenon\|hyperqube] [--backup-file FILE]` | `zenon` is default. Restores from backup. Prompts interactively if `FILE` is omitted. |
| Start Service | `sudo ./zenon.sh --start [zenon\|hyperqube]` | `zenon` is default. Starts the node service. |
| Stop Service | `sudo ./zenon.sh --stop [zenon\|hyperqube]` | `zenon` is default. Stops the node service. |
| Restart Service | `sudo ./zenon.sh --restart [zenon\|hyperqube]` | `zenon` is default. Restarts the node service. |
| Monitor Logs | `sudo ./zenon.sh --monitor [zenon\|hyperqube]` | `zenon` is default. Follows service logs in real-time. |
| Resync Node | `sudo ./zenon.sh --resync [zenon\|hyperqube]` | `zenon` is default. Resynchronizes node from genesis. |
| Analytics | `sudo ./zenon.sh --analytics` | Installs analytics stack (Grafana, Node Exporter, Prometheus). |
| Help | `./zenon.sh --help` | Displays comprehensive help information. |

## Configuration

<details>
<summary>Environment variables (from <code>lib/config.sh</code>)</summary>

### Core Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZNNSH_REPO_URL` | `https://github.com/zenon-network/go-zenon.git` | Git repository to clone |
| `ZNNSH_BRANCH_NAME` | `master` | Git branch or tag |
| `ZNNSH_DEBUG` | `false` | Enable debug mode |
| `ZNNSH_NODE_TYPE` | `zenon` | Node type (zenon or hyperqube) |
| `ZNNSH_BINARY_NAME` | `znnd` | Binary name for the node |
| `ZNNSH_SERVICE_NAME` | `go-zenon` | Systemd service name |

### Directory Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZNNSH_INSTALL_DIR` | `/usr/local/bin` | Installation directory for binaries |
| `ZNNSH_ZNN_DIR` | `/root/.znn` | Zenon data directory |
| `ZNNSH_HQZD_DIR` | `/root/.hqzd` | HyperQube data directory |
| `ZNNSH_BACKUP_DIR` | `/backup` | Directory to store backup archives |

### Backup Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZNNSH_MAX_BACKUPS` | `7` | Maximum number of backups to retain |
| `ZNNSH_BACKUP_CADENCE_DAYS` | `0` | Days between automated backups (0 = disabled) |
| `ZNNSH_BACKUP_HOUR` | `2` | Hour for scheduled backups (24-hour format) |
| `ZNNSH_MIN_FREE_SPACE_KB` | `15728640` | Minimum free space required (15 GB) |

### Analytics Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZNNSH_NODE_EXPORTER_VERSION` | `1.6.1` | Node Exporter version |
| `ZNNSH_PROMETHEUS_VERSION` | `2.47.0` | Prometheus version |
| `ZNNSH_INFINITY_PLUGIN_VERSION` | `2.10.0` | Grafana Infinity plugin version |
| `ZNNSH_GRAFANA_ADMIN_USER` | `admin` | Grafana admin username |
| `ZNNSH_GRAFANA_ADMIN_PASSWORD` | `admin` | Grafana admin password |

### Go and Build Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZNNSH_GO_VERSION` | `1.23.0` | Go language version |
| `ZNNSH_GUM_VERSION` | `0.16.1` | Gum TUI framework version |

### HyperQube Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZNNSH_HQZD_GENESIS_URL` | Default is set in `config.sh`, override at runtime | HyperQube genesis file URL |

See `lib/config.sh` for the complete list of configuration options.
</details>

To override variables at runtime, use `sudo ZNNSH_VARIABLE_NAME=value ./zenon.sh [COMMAND] [FLAGS]`.

## Directory Structure

```text
.
├── zenon.sh           # Entry-point CLI
├── lib/
│   ├── analytics.sh   # Analytics stack installation
│   ├── backup.sh      # Backup functionality
│   ├── build.sh       # Build from source
│   ├── config.sh      # Environment variables and configuration
│   ├── deploy.sh      # Deployment orchestration
│   ├── environment.sh # Library loader and initialization
│   ├── grafana.sh     # Grafana configuration
│   ├── help.sh        # Help system
│   ├── logging.sh     # Logging utilities
│   ├── menu.sh        # Interactive TUI
│   ├── monitor.sh     # Log monitoring
│   ├── restart.sh     # Service restart
│   ├── restore.sh     # Restore functionality
│   ├── resync.sh      # Node resynchronization
│   ├── start.sh       # Service start
│   ├── stop.sh        # Service stop
│   └── utils.sh       # Utility functions
├── dashboards/        # Grafana JSON exports
└── LICENSE
```

## ShellCheck

A project-wide `.shellcheckrc` can be committed to customize linting for all contributors and CI.

## License

This project is licensed under the GNU General Public License v3.0. See [`LICENSE`](LICENSE) for details.
