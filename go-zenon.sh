#!/bin/bash -e

# Large ASCII Art for Zenon Network
echo "
  ______  ______   _   _    ____    _   _             _     
 |___  / |  ____| | \ | |  / __ \  | \ | |           | |    
    / /  | |__    |  \| | | |  | | |  \| |      ___  | |__  
   / /   |  __|   | . \` | | |  | | | . \` |     / __| | '_ \ 
  / /__  | |____  | |\  | | |__| | | |\  |  _  \__ \ | | | |
 /_____| |______| |_| \_|  \____/  |_| \_| (_) |___/ |_| |_|
                                                            
 00110011 00110010 00110001
  _   _      _                      _             __   __  __                            _                   
 | \ | |    | |                    | |           / _| |  \/  |                          | |                  
 |  \| | ___| |___      _____  _ __| | __   ___ | |_  | \  / | ___  _ __ ___   ___ _ __ | |_ _   _ _ __ ___  
 | . \` |/ _ \ __\ \ /\ / / _ \| '__| |/ /  / _ \|  _| | |\/| |/ _ \| '_ \` _ \ / _ \ '_ \| __| | | | '_ \` _ \ 
 | |\  |  __/ |_ \ V  V / (_) | |  |   <  | (_) | |   | |  | | (_) | | | | | |  __/ | | | |_| |_| | | | | | |
 |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\  \___/|_|   |_|  |_|\___/|_| |_| |_|\___|_| |_|\__|\__,_|_| |_| |_|

"
# Check architecture and OS
if [[ "$(uname -m)" != "x86_64" ]]; then
    echo "Error: This script only supports x86_64 architecture."
    exit 1
fi

# Function to check and rename existing directories
rename_existing_dir() {
    local dir_name=$1
    if [ -d "$dir_name" ]; then
        local timestamp=$(date +"%Y%m%d%H%M%S")
        mv "$dir_name" "${dir_name}-${timestamp}"
        echo "Renamed existing '$dir_name' to '${dir_name}-${timestamp}'."
    fi
}

# Function to install Go
install_go() {
    echo "Checking for existing Go installation..."

    # Check and rename existing go directory
    rename_existing_dir "go"

    echo "Downloading and installing Go..."
    local go_url="https://golang.org/dl/go1.20.3.linux-amd64.tar.gz"
    curl -fsSLo "go.tar.gz" "$go_url"
    tar -C . -xzf "go.tar.gz"
    rm "go.tar.gz"
    echo "Go installed successfully."
}

# Function to install dependencies
install_dependencies() {
    echo "Updating system and installing dependencies..."

    # Automatically select default options using -y
    apt-get update -y && apt-get upgrade -y

    # Check if make is installed
    if ! command -v make &> /dev/null; then
        echo "make could not be found"
        echo "Installing make..."
        apt-get install -y make
    fi

    # Check if gcc is installed
    if ! command -v gcc &> /dev/null; then
        echo "gcc could not be found"
        echo "Installing gcc..."
        apt-get install -y gcc
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "jq could not be found"
        echo "Installing jq..."
        apt-get install -y jq
    fi
}

# Function to stop go-zenon if running
stop_znnd_if_running() {
    if systemctl is-active --quiet go-zenon; then
        echo "Stopping go-zenon service..."
        systemctl stop go-zenon
        echo "go-zenon service stopped."
    else
        echo "go-zenon service is not running."
    fi
}

# Function to get branches of a GitHub repo using git ls-remote
get_branches() {
    local repo_url=$1
    branches=$(git ls-remote --heads "$repo_url" | awk '{print $2}' | sed 's|refs/heads/||')
}

# Function to display branches and get user selection
select_branch() {
    local branches=("$@")
    echo "Available branches:"
    select branch in "${branches[@]}"; do
        if [ -n "$branch" ]; then
            echo "You selected branch: $branch"
            selected_branch="$branch"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

# Function to clone and build go-zenon
clone_and_build_go_zenon() {
    stop_znnd_if_running

    echo "Enter the GitHub repository URL (default: https://github.com/zenon-network/go-zenon.git):"
    read -r repo_url

    # Use default URL if none is provided
    repo_url=${repo_url:-"https://github.com/zenon-network/go-zenon.git"}

    # Default branch to master if using the default URL
    if [ "$repo_url" == "https://github.com/zenon-network/go-zenon.git" ]; then
        branch="master"
    else
        # Get branches
        get_branches "$repo_url"

        # Convert branches to array
        branches_array=($branches)

        # Check if there are any branches
        if [ ${#branches_array[@]} -eq 0 ]; then
            echo "No branches found. Exiting."
            exit 1
        fi

        # Prompt user to select a branch
        select_branch "${branches_array[@]}"
        branch=$selected_branch
    fi

    echo "Checking for existing go-zenon directory..."
    # Check and rename existing go-zenon directory
    rename_existing_dir "go-zenon"

    # Clone the repository
    echo "Cloning branch '$branch' from repository '$repo_url'..."
    git clone -b "$branch" "$repo_url" go-zenon

    echo "Clone completed."

    cd go-zenon

    # Build the project using the full path to the Go binary
    GO111MODULE=on ../go/bin/go build -o build/znnd ./cmd/znnd
    cp build/znnd /usr/local/bin/
}

# Function to create the go-zenon service
create_service() {
    echo "Checking if go-zenon.service is already set up..."

    if systemctl is-active --quiet go-zenon; then
        echo "go-zenon.service is already active. Skipping setup."
        return
    fi

    if [ -e /etc/systemd/system/go-zenon.service ]; then
        echo "go-zenon.service already exists, but it's not active. Setting it up..."
    else
        echo "Creating go-zenon.service..."
        cat << EOF > /etc/systemd/system/go-zenon.service
[Unit]
Description=znnd service
After=network.target
[Service]
LimitNOFILE=32768
User=root
Group=root
Type=simple
SuccessExitStatus=SIGKILL 9
ExecStart=/usr/local/bin/znnd
ExecStop=/usr/bin/pkill -9 znnd
Restart=on-failure
TimeoutStopSec=10s
TimeoutStartSec=10s
[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable go-zenon.service
    echo "go-zenon.service is set up."
}

# Function to start go-zenon service
start_service() {
    echo "Starting go-zenon service..."
    systemctl start go-zenon
    echo "go-zenon started successfully."
}

# Function to deploy go-zenon
deploy_go_zenon() {
    error_string=("Error: This command has to be run with superuser"
      "privileges (under the root user on most systems).")
    if [[ $(id -u) -ne 0 ]]; then echo "${error_string[@]}" >&2; exit 1; fi

    install_dependencies
    install_go
    clone_and_build_go_zenon
    create_service
    start_service
}

# Function to restore go-zenon from bootstrap
restore_go_zenon() {
    echo "Restoring go-zenon from bootstrap..."
    # Download and run the restore.sh script
    wget -O temp_restore.sh "https://gist.githubusercontent.com/0x3639/05c6e2ba6b7f0c2a502a6bb4da6f4746/raw/ff4343433b31a6c85020c887256c0fd3e18f01d9/restore.sh"
    chmod +x temp_restore.sh
    ./temp_restore.sh

    # Cleanup the temporary restore script
    rm temp_restore.sh
}

# Function to restart go-zenon
restart_go_zenon() {
    echo "Restarting go-zenon..."
    systemctl restart go-zenon
    echo "go-zenon restarted successfully."
}

# Function to stop go-zenon
stop_go_zenon() {
    echo "Stopping go-zenon..."
    systemctl stop go-zenon
    echo "go-zenon stopped successfully."
}

# Function to start go-zenon
start_go_zenon() {
    echo "Starting go-zenon..."
    systemctl start go-zenon
    echo "go-zenon started successfully."
}

# Function to monitor znnd logs
monitor_logs() {
    echo "Monitoring znnd logs. Press Ctrl+C to stop."
    tail -f /var/log/syslog | grep znnd
}

show_help() {
    echo "A script to automate the setup, management, and restoration of the Zenon Network."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --deploy            Deploy and set up the Zenon Network"
    echo "  --restore           Restore go-zenon from bootstrap"
    echo "  --restart           Restart the go-zenon service"
    echo "  --stop              Stop the go-zenon service"
    echo "  --start             Start the go-zenon service"
    echo "  --status            Monitor znnd logs"
    echo "  --help              Display this help message"
    echo
}

# Check for flags
if [[ $# -eq 0 ]]; then
    deploy_go_zenon
else
    while [[ "$1" != "" ]]; do
        case $1 in
            --deploy )
                deploy_go_zenon
                exit
                ;;
            --restore )
                restore_go_zenon
                exit
                ;;
            --restart )
                restart_go_zenon
                exit
                ;;
            --stop )
                stop_go_zenon
                exit
                ;;
            --start )
                start_go_zenon
                exit
                ;;
            --status )
                monitor_logs
                exit
                ;;
            --help )
                show_help
                exit
                ;;
            * )
                echo "Invalid option: $1"
                echo "Usage: $0 [--deploy] [--restore] [--restart] [--stop] [--start] [--status] [--help]"
                exit 1
        esac
        shift
    done
fi
