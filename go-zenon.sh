#!/bin/bash -e

# Large ASCII Art for Zenon Network
cat << 'EOF'
 ______                             _                                                                       
|___  /                            | |                                                                      
   / /  ___ _ __   ___  _ __    ___| |__                                                                    
  / /  / _ \ '_ \ / _ \| '_ \  / __| '_ \                                                                   
./ /__|  __/ | | | (_) | | | |_\__ \ | | |                                                                  
\_____/\___|_| |_|\___/|_| |_(_)___/_| |_|                                                                  

 _   _      _                      _             __  ___  ___                           _                   
| \ | |    | |                    | |           / _| |  \/  |                          | |                  
|  \| | ___| |___      _____  _ __| | __   ___ | |_  | .  . | ___  _ __ ___   ___ _ __ | |_ _   _ _ __ ___  
| . ` |/ _ \ __\ \ /\ / / _ \| '__| |/ /  / _ \|  _| | |\/| |/ _ \| '_ ` _ \ / _ \ '_ \| __| | | | '_ ` _ \ 
| |\  |  __/ |_ \ V  V / (_) | |  |   <  | (_) | |   | |  | | (_) | | | | | |  __/ | | | |_| |_| | | | | | |
\_| \_/\___|\__| \_/\_/ \___/|_|  |_|\_\  \___/|_|   \_|  |_/\___/|_| |_| |_|\___|_| |_|\__|\__,_|_| |_| |_|
EOF

# Global variables
BUILD_SOURCE=false
BUILD_SOURCE_URL=""

# Check architecture and OS
ARCH=$(uname -m)
GO_URL=""
GO_VERSION=1.23.0

if [[ "$ARCH" == "x86_64" ]]; then
    GO_URL="https://go.dev/dl/go$GO_VERSION.linux-amd64.tar.gz"
fi

# ARM Support TODO
# if [[ "$ARCH" == "arm64" ]]; then
#     GO_URL="https://go.dev/dl/go$GO_VERSION.linux-arm64.tar.gz"
# fi

if [[ "$GO_URL" == "" ]]; then
    echo "Error: $ARCH architecture is not supported."
    exit 1
fi

# Node configuration
DEFAULT_ZENON_REPO="https://github.com/zenon-network/go-zenon.git"
DEFAULT_ZENON_BRANCH="master"
DEFAULT_ZENON_BINARY="znnd"
DEFAULT_ZENON_SERVICE="go-zenon"

DEFAULT_HYPERQUBE_REPO="https://github.com/hypercore-one/hyperqube_z.git"
DEFAULT_HYPERQUBE_BRANCH="hyperqube_z"
DEFAULT_HYPERQUBE_BINARY="hqzd"
DEFAULT_HYPERQUBE_SERVICE="go-hyperqube"

# Active configuration (will be set based on flags)
ACTIVE_NODE_TYPE="zenon"  # default node type will always be zenon
ACTIVE_REPO=""
ACTIVE_BRANCH=""
ACTIVE_BINARY=""
ACTIVE_SERVICE=""
CUSTOM_REPO_URL=""

# Function to set active configuration
set_node_config() {
    local node_type=$1
    
    case $node_type in
        "zenon")
            ACTIVE_REPO=$DEFAULT_ZENON_REPO
            ACTIVE_BRANCH=$DEFAULT_ZENON_BRANCH
            ACTIVE_BINARY=$DEFAULT_ZENON_BINARY
            ACTIVE_SERVICE=$DEFAULT_ZENON_SERVICE
            ;;
        "hyperqube")
            ACTIVE_REPO=$DEFAULT_HYPERQUBE_REPO
            ACTIVE_BRANCH=$DEFAULT_HYPERQUBE_BRANCH
            ACTIVE_BINARY=$DEFAULT_HYPERQUBE_BINARY
            ACTIVE_SERVICE=$DEFAULT_HYPERQUBE_SERVICE
            ;;
    esac

    # Override repo URL if custom URL provided
    if [ -n "$CUSTOM_REPO_URL" ]; then
        ACTIVE_REPO=$CUSTOM_REPO_URL
    fi
}

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
    curl -fsSLo "go.tar.gz" "$GO_URL"
    tar -C . -xzf "go.tar.gz"
    rm "go.tar.gz"
    echo "Go installed successfully."
}

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."

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

# Function to stop node service if running
stop_node_if_running() {
    if systemctl is-active --quiet $ACTIVE_SERVICE; then
        echo "Stopping $ACTIVE_SERVICE service..."
        systemctl stop $ACTIVE_SERVICE
        echo "$ACTIVE_SERVICE service stopped."
    else
        echo "$ACTIVE_SERVICE service is not running."
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

# Function to clone and build node
clone_and_build_node() {
    stop_node_if_running

    if [ "$BUILD_SOURCE" = false ]; then
        repo_url=$ACTIVE_REPO
        branch=$ACTIVE_BRANCH
    else
        # If BUILD_SOURCE_URL is empty, prompt for repo URL
        if [ -z "$CUSTOM_REPO_URL" ]; then
            echo "Enter the GitHub repository URL (default: $ACTIVE_REPO):"
            read -r repo_url
            repo_url=${repo_url:-$ACTIVE_REPO}
        else
            repo_url=$CUSTOM_REPO_URL
        fi

        get_branches "$repo_url"
        branches_array=($branches)

        if [ ${#branches_array[@]} -eq 0 ]; then
            echo "No branches found. Exiting."
            exit 1
        fi

        select_branch "${branches_array[@]}"
        branch=$selected_branch
    fi

    local repo_dir="${ACTIVE_SERVICE}"
    echo "Checking for existing $repo_dir directory..."
    rename_existing_dir "$repo_dir"

    echo "Cloning branch '$branch' from repository '$repo_url'..."
    git clone -b "$branch" "$repo_url" "$repo_dir"
    echo "Clone completed."

    cd "$repo_dir"

    # Build the project
    GO111MODULE=on ../go/bin/go build -o "build/$ACTIVE_BINARY" "./cmd/$ACTIVE_BINARY"
    cp "build/$ACTIVE_BINARY" /usr/local/bin/
}

# Function to create the node service
create_service() {
    echo "Checking if $ACTIVE_SERVICE.service is already set up..."

    if systemctl is-active --quiet $ACTIVE_SERVICE; then
        echo "$ACTIVE_SERVICE.service is already active. Skipping setup."
        return
    fi

    if [ -e /etc/systemd/system/$ACTIVE_SERVICE.service ]; then
        echo "$ACTIVE_SERVICE.service already exists, but it's not active. Setting it up..."
    else
        echo "Creating $ACTIVE_SERVICE.service..."
        cat << EOF > /etc/systemd/system/$ACTIVE_SERVICE.service
[Unit]
Description=$ACTIVE_BINARY service
After=network.target
[Service]
LimitNOFILE=32768
User=root
Group=root
Type=simple
SuccessExitStatus=SIGKILL 9
ExecStart=/usr/local/bin/$ACTIVE_BINARY
ExecStop=/usr/bin/pkill -9 $ACTIVE_BINARY
Restart=on-failure
TimeoutStopSec=10s
TimeoutStartSec=10s
[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable $ACTIVE_SERVICE.service
    echo "$ACTIVE_SERVICE.service is set up."
}

# Function to start node service
start_node() {
    local node_type=${1:-"zenon"}  # Default to zenon if no argument
    set_node_config "$node_type"
    echo "Starting $ACTIVE_SERVICE service..."
    systemctl start $ACTIVE_SERVICE
    echo "$ACTIVE_SERVICE started successfully."
}

# Function to modify HyperQube config
modify_hyperqube_config() {
    local config_file="/root/.hqzd/config.json"
    
    if [ ! -f "$config_file" ]; then
        echo "The config.json file does not exist. You should create it."
        return 1
    fi

    echo "Modifying HyperQube config.json..."
    # Use jq to modify the ListenPort
    jq '.Net.ListenPort = 45995' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
    echo "Updated ListenPort to 45995 in config.json"
}

# Function to deploy node
deploy_node() {
    error_string=("Error: This command has to be run with superuser"
      "privileges (under the root user on most systems).")
    if [[ $(id -u) -ne 0 ]]; then echo "${error_string[@]}" >&2; exit 1; fi

    install_dependencies
    install_go
    clone_and_build_node
    create_service
    
    # If this is a HyperQube deployment, modify the config
    if [ "$ACTIVE_NODE_TYPE" = "hyperqube" ]; then
        modify_hyperqube_config
    fi
    
    start_node "$ACTIVE_NODE_TYPE"
}

# Function to restore node from bootstrap
restore_node() {
    echo "Restoring $ACTIVE_SERVICE from bootstrap..."
    # Download and run the restore.sh script
    wget -O $ACTIVE_SERVICE_restore.sh "https://gist.githubusercontent.com/0x3639/05c6e2ba6b7f0c2a502a6bb4da6f4746/raw/ff4343433b31a6c85020c887256c0fd3e18f01d9/restore.sh"
    chmod +x $ACTIVE_SERVICE_restore.sh
    ./$ACTIVE_SERVICE_restore.sh

    # Cleanup the temporary restore script
    rm $ACTIVE_SERVICE_restore.sh
}

# Function to restart node
restart_node() {
    echo "Restarting $ACTIVE_SERVICE..."
    systemctl restart $ACTIVE_SERVICE
    echo "$ACTIVE_SERVICE restarted successfully."
}

# Function to stop node
stop_node() {
    local node_type=${1:-"zenon"}  # Default to zenon if no argument
    set_node_config "$node_type"
    echo "Stopping $ACTIVE_SERVICE..."
    systemctl stop $ACTIVE_SERVICE
    echo "$ACTIVE_SERVICE stopped successfully."
}

# Function to monitor logs
monitor_logs() {
    local node_type=${1:-"zenon"}  # Default to zenon if no argument
    set_node_config "$node_type"
    echo "Monitoring $ACTIVE_BINARY logs. Press Ctrl+C to stop."
    tail -f /var/log/syslog | grep $ACTIVE_BINARY
}

# Function to install Grafana
install_grafana() {
    echo "Installing Grafana..."

    # Get the current repository URL and branch
    GITHUB_REPO=$(git config --get remote.origin.url | sed 's/.*github.com[:\/]\(.*\)\.git/\1/')
    GITHUB_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Construct the URL for the grafana.sh script
    GRAFANA_SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/grafana.sh"

    wget -O grafana.sh "$GRAFANA_SCRIPT_URL"
    chmod +x grafana.sh
    ./grafana.sh
    echo "Grafana installed successfully."
}

show_help() {
    echo "A script to automate the setup, management, and restoration of Network Nodes."
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --deploy              Deploy and set up the Zenon Network"
    echo "  --deploy --hq [URL]   Deploy and set up the HyperQube Network. Optional URL to override default repo."
    echo "  --buildSource [URL]   Build from a specific source repository"
    echo "  --restore             Restore go-zenon from bootstrap"
    echo "  --restart             Restart the go-zenon service"
    echo "  --stop [--hq]         Stop the node service (add --hq for HyperQube)"
    echo "  --start [--hq]        Start the node service (add --hq for HyperQube)"
    echo "  --status [--hq]       Monitor node logs (add --hq for HyperQube)"
    echo "  --grafana             Install Grafana"
    echo "  --help                Display this help message"
    echo
}

# Check for flags
if [[ $# -eq 0 ]]; then
    set_node_config "zenon"
    deploy_node
else
    while [[ "$1" != "" ]]; do
        case $1 in
            --deploy )
                shift
                if [[ "$1" == "--hq" ]]; then
                    ACTIVE_NODE_TYPE="hyperqube"
                    shift
                    if [[ "$1" != "" && "$1" != -* ]]; then
                        CUSTOM_REPO_URL="$1"
                        shift
                    fi
                fi
                set_node_config $ACTIVE_NODE_TYPE
                deploy_node
                exit
                ;;
            --buildSource )
                BUILD_SOURCE=true
                shift
                if [[ "$1" != "" && "$1" != -* ]]; then
                    BUILD_SOURCE_URL="$1"
                    shift
                fi
                set_node_config "zenon"  # Explicitly set to zenon
                deploy_node
                exit
                ;;
            --restore )
                restore_node
                exit
                ;;
            --restart )
                restart_node
                exit
                ;;
            --stop )
                shift
                if [[ "$1" == "--hq" ]]; then
                    stop_node "hyperqube"
                else
                    stop_node "zenon"
                fi
                exit
                ;;
            --start )
                shift
                if [[ "$1" == "--hq" ]]; then
                    start_node "hyperqube"
                else
                    start_node "zenon"
                fi
                exit
                ;;
            --status )
                shift
                if [[ "$1" == "--hq" ]]; then
                    monitor_logs "hyperqube"
                else
                    monitor_logs "zenon"
                fi
                exit
                ;;
            --grafana )
                install_grafana
                exit
                ;;
            --help )
                show_help
                exit
                ;;
            * )
                echo "Invalid option: $1"
                echo "Usage: $0 [--deploy] [--buildSource [URL]] [--restore] [--restart] [--stop] [--start] [--status] [--grafana] [--help]"
                exit 1
        esac
    done
fi
