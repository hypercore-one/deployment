#!/usr/bin/env bash

install_dependencies() {
    info_log "Installing dependencies..."

    if ! command -v make &> /dev/null; then
        info_log "Make could not be found. Installing make..."
        apt install -y make
    fi

    if ! command -v gcc &> /dev/null; then
        info_log "gcc could not be found. Installing gcc..."
        apt install -y gcc
    fi

    if ! command -v jq &> /dev/null; then
        info_log "jq could not be found. Installing jq..."
        apt install -y jq
    fi
}

install_go() {

    local go_bin="$ZNNSH_DEPLOYMENT_DIR/go/bin/go"
    local desired_version="go$ZNNSH_GO_VERSION"

    if [[ -x "$go_bin" ]]; then
        local current_version
        current_version="$("$go_bin" version | awk '{print $3}')"
        if [[ "$current_version" == "$desired_version" ]]; then
            info_log "Go $ZNNSH_GO_VERSION already installed – skipping download."
            return 0
        else
            info_log "Found Go version $current_version, expected $desired_version – re-installing."
            rename_existing_dir "go"
        fi
    fi

    info_log "Downloading and installing Go..."
    curl -fLo "go.tar.gz" --connect-timeout 30 --max-time 300 "$ZNNSH_GO_URL" || {
        error_log "Failed to download Go from $ZNNSH_GO_URL"
        return 1
    }
    tar -C . -xzf "go.tar.gz"
    rm "go.tar.gz"
    success_log "Go installed successfully."
}

get_branches() {
    local repo_url=$1
    local branches
    
    info_log "Fetching branches from $repo_url"
    
    branches=$(gum spin --spinner meter --spinner.foreground 46 --title "Fetching branches..." -- \
        bash -c "git ls-remote --heads '$repo_url' | awk '{print \$2}' | sed 's|refs/heads/||'")
    
    if [ -z "$branches" ]; then
        error_log "No branches found or unable to connect to repository"
        return 1
    fi
    
    echo "$branches"
    return 0
}

select_branch() {
    local branches=("$@")

    selected_branch=$(printf "%s\n" "${branches[@]}" | gum choose \
        --header="$(gum style --foreground 242 --padding "1 1" "SELECT A BRANCH:")" \
        --cursor.foreground="46" \
        --selected.foreground="46")
    local choose_status=$?

    if [[ $choose_status -ne 0 || -z "$selected_branch" ]]; then
        error_log "Branch selection cancelled. Aborting."
        return 1
    else
        success_log "You selected branch: $selected_branch"
    fi
}

clone_and_build() {
    local repo_url=${1:-"$ZNNSH_REPO_URL"}
    local branch=${2:-"$ZNNSH_BRANCH_NAME"}
    local node_dir="${ZNNSH_DEFAULT_NODE_CONFIG[${ZNNSH_NODE_TYPE}_service]}"
    local build_title="==== BUILD: ${ZNNSH_NODE_TYPE^} Network from Source ===="
    
    gum spin --spinner meter --spinner.foreground 46 --title "Stopping $ZNNSH_SERVICE_NAME in case it is running..." -- bash -c "stop_node_if_running"

    if [ "$ZNNSH_INTERACTIVE_MODE" = true ]; then

        gum style \
            --border-foreground 239 \
            --foreground 239 \
            "$build_title"
        
        if [[ "$ZNNSH_NODE_TYPE" == "zenon" ]]; then
            repo_options=(
                "zenon-network → https://github.com/zenon-network/go-zenon.git"
                "hypercore-one → https://github.com/hypercore-one/go-zenon.git"
                "custom → Provide a custom repository URL"
            )
        elif [[ "$ZNNSH_NODE_TYPE" == "hyperqube" ]]; then
            repo_options=(
                "hypercore-one → https://github.com/hypercore-one/hyperqube_z.git"
                "custom → Provide a custom repository URL"
            )
        fi
        repo_choice=$(printf "%s\n" "${repo_options[@]}" | gum choose \
            --header="$(gum style --foreground 242 --padding "1 1" "SELECT A REPOSITORY:")" \
            --cursor.foreground="46" \
            --selected.foreground="46")
        local repo_choose_status=$?

        if [[ $repo_choose_status -ne 0 || -z "$repo_choice" ]]; then
            error_log "Repository selection cancelled. Aborting."
            return 1
        fi

        local repo_type
        repo_type=$(echo "$repo_choice" | awk -F' →' '{print $1}')
        
        case "$repo_type" in
            "zenon-network")
                repo_url="${ZNNSH_DEFAULT_NODE_CONFIG[zenon_repo]}"
                success_log "You selected repository: Zenon Network"
                ;;
            "hypercore-one")
                if [[ "$ZNNSH_NODE_TYPE" == "zenon" ]]; then
                    repo_url="https://github.com/hypercore-one/go-zenon.git"
                else
                    repo_url="${ZNNSH_DEFAULT_NODE_CONFIG[hyperqube_repo]}"
                fi
                success_log "You selected repository: Hypercore One"
                ;;
            "custom")
                repo_url=$(gum input \
                    --width 70 \
                    --placeholder "Enter repository URL (e.g. https://github.com/user/repo.git)" \
                    --cursor.foreground="46")
                
                if [ -z "$repo_url" ]; then
                    repo_url="${ZNNSH_DEFAULT_NODE_CONFIG[${ZNNSH_NODE_TYPE}_repo]}"
                    info_log "No URL provided, using default: $repo_url"
                else
                    info_log "Using custom repository: $repo_url"
                fi
                ;;
            *)
                repo_url="${ZNNSH_DEFAULT_NODE_CONFIG[${ZNNSH_NODE_TYPE}_repo]}"
                info_log "Using default repository: $repo_url"
                ;;
        esac

        local all_branches
        mapfile -t all_branches < <(get_branches "$repo_url")
        local branches_array=()
        local has_master=false

        for branch in "${all_branches[@]}"; do
            if [[ "$branch" == "master" ]]; then
                has_master=true
            else
                branches_array+=("$branch")
            fi
        done

        if [[ "$has_master" == true ]]; then
            branches_array=("master" "${branches_array[@]}")
        fi
        
        if [ ${#branches_array[@]} -eq 0 ]; then
            error_log "No branches found in repository"
            return 1
        fi

        if ! select_branch "${branches_array[@]}"; then
            return 1
        fi
        branch=$selected_branch
    else
        info_log "Using repository $repo_url with branch $branch"
    fi
    
    rename_existing_dir "${node_dir}" || {
        error_log "Failed to prepare directories"
        return 1
    }

    gum spin --spinner meter --spinner.foreground 46 --title "Cloning branch '$branch' from repository..." -- \
        bash -c "git clone -b '$branch' '$repo_url' '${node_dir}' \
        >> \"${ZNNSH_LOG_FILE}\" 2>&1" || {
        error_log "Failed to clone repository"
        return 1
    }

    cd "${node_dir}" || {
        error_log "Failed to enter ${node_dir} directory"
        return 1
    }

    gum spin --spinner meter --spinner.foreground 46 --title "Building ${ZNNSH_BINARY_NAME}..." -- \
        bash -c "env GO111MODULE=on ../go/bin/go build -o 'build/${ZNNSH_BINARY_NAME}' './cmd/${ZNNSH_BINARY_NAME}' \
        >> \"${ZNNSH_LOG_FILE}\" 2>&1" || {
        error_log "Failed to build ${ZNNSH_BINARY_NAME}"
        return 1
    }

    gum spin --spinner meter --spinner.foreground 46 --title "Installing ${ZNNSH_BINARY_NAME} binary..." -- \
        bash -c "cp 'build/${ZNNSH_BINARY_NAME}' '$ZNNSH_INSTALL_DIR/' \
        >> \"${ZNNSH_LOG_FILE}\" 2>&1" || {
        error_log "Failed to install ${ZNNSH_BINARY_NAME} binary"
        return 1
    }

    success_log "Build completed successfully"
    
    return 0
}

create_service() {
    info_log "Checking if $ZNNSH_SERVICE_NAME.service is already set up..."

    if systemctl is-active --quiet "$ZNNSH_SERVICE_NAME"; then
        info_log "$ZNNSH_SERVICE_NAME.service is already active. Skipping setup."
        return
    fi

    if [ -e "/etc/systemd/system/$ZNNSH_SERVICE_NAME.service" ]; then
        info_log "$ZNNSH_SERVICE_NAME.service already exists, but it's not active. Setting it up..."
    else
        info_log "Creating $ZNNSH_SERVICE_NAME.service..."
        cat << EOF > "/etc/systemd/system/$ZNNSH_SERVICE_NAME.service"
[Unit]
Description=$ZNNSH_BINARY_NAME service
After=network.target
[Service]
LimitNOFILE=32768
User=root
Group=root
Type=simple
SuccessExitStatus=SIGKILL 9
ExecStart=/usr/local/bin/$ZNNSH_BINARY_NAME
ExecStop=/usr/bin/pkill -9 $ZNNSH_BINARY_NAME
Restart=on-failure
TimeoutStopSec=10s
TimeoutStartSec=10s
[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable "$ZNNSH_SERVICE_NAME.service"
    success_log "$ZNNSH_SERVICE_NAME.service is set up."
}


modify_hyperqube_config() {
    local hq_dir="${ZNNSH_HQZD_DIR:?ZNNSH_HQZD_DIR is required}"
    local genesis_url="${ZNNSH_HQZD_GENESIS_URL:?ZNNSH_HQZD_GENESIS_URL is required}"
    local wallet_dir="$hq_dir/wallet"
    local genesis_file="$hq_dir/genesis.json"
    local config_file="$hq_dir/config.json"

    mkdir -p "$wallet_dir"
    if [[ ! -s "$genesis_file" ]]; then
        info_log "Downloading HyperQube's genesis.json …"
        curl -fsSL -o "$genesis_file" "$genesis_url" || {
            error_log "Failed to download genesis.json from $genesis_url"; return 1; }
    fi

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "${config_file}.bak.$(date +%s)"
        info_log "Existing config.json file found and backed up. Minimal config.json created."
    fi

    cat > "$config_file" <<EOF
{
  "DataPath": "$hq_dir",
  "WalletPath": "$wallet_dir",
  "GenesisFile": "$genesis_file",
  "LogLevel": "info",
  "RPC": {
    "EnableHTTP": true,
    "EnableWS": true,
    "HTTPHost": "0.0.0.0",
    "HTTPPort": 35997,
    "WSHost": "0.0.0.0",
    "WSPort": 35998,
    "HTTPCors": ["*"],
    "WSOrigins": ["*"]
  },
  "Net": {
    "ListenHost": "0.0.0.0",
    "ListenPort": 45995,
    "MinPeers": 14,
    "MinConnectedPeers": 14,
    "MaxPeers": 60,
    "MaxPendingPeers": 10,
    "Seeders": [
      "enode://763935dbbdd2ed59e64d2263884887abf865165129f18af9fb1cd0e961b936405144970e7363e6be3d0f0bc3d1e4a0e2ac22306335b8102941728718e063777b@45.77.193.218:45995",
      "enode://1e2183f24ad6808770ac233136289ab6bdb8c3611dc0f10e4cf5a0bdaa65a1f78682b4cce6fc72c1b2a08112ce1627fd380b2477bb644741db0f45f8a05edd2b@23.95.75.249:45995",
      "enode://245044b8f6a639d5e4f9f617930ab97f0061531f6a7ce215d780abda6810f6e5af17a4d0d2376689a673ad1b3bee16a81fe49e38d988bfefcbaa0e371d3e44e9@159.69.22.88:45995"
    ]
  }
}
EOF

    success_log "HyperQube config.json generated and genesis downloaded."
}

export -f install_dependencies
export -f install_go
export -f create_service
export -f modify_hyperqube_config