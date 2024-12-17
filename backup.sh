#!/bin/bash

# Function to print usage instructions
usage() {
    echo "Usage: $0 --backup|--restore"
    exit 1
}

# Function to perform backup
do_backup() {
    # Ensure zip is installed
    if ! command -v zip &> /dev/null; then
        echo "zip is not installed. Attempting to install zip..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y zip
        elif command -v yum &> /dev/null; then
            yum install -y zip
        elif command -v dnf &> /dev/null; then
            dnf install -y zip
        else
            echo "Could not install zip. No supported package manager found (apt-get/yum/dnf)."
            exit 1
        fi
    fi

    # Define date and file variables
    current_datetime=$(date +"%Y%m%d%H%M%S")
    zip_file_name="bootstrap-$current_datetime.zip"
    hash_file_name="bootstrap-$current_datetime.hash"

    # Stop the service
    systemctl stop go-zenon

    # Sleep 10 seconds to ensure service has stopped
    sleep 10

    # Navigate to the directory
    cd /root/.znn

    # Create backup directory if it doesn't exist
    mkdir -p /root/.znn/backup
    backup_dir="/root/.znn/backup/$current_datetime"
    mkdir -p "$backup_dir"

    # Copy necessary folders to backup directory
    cp -r nom/ "$backup_dir/nom.bak"
    cp -r network/ "$backup_dir/network.bak"
    cp -r consensus/ "$backup_dir/consensus.bak"

    # Check if cache directory exists and copy if it does
    if [ -d "cache/" ]; then
        cp -r cache/ "$backup_dir/cache.bak"
    fi

    # Start the service
    systemctl start go-zenon

    # Create the zip and hash files
    cd "$backup_dir"
    zip -r "$zip_file_name" ./*.bak
    echo "$(sha256sum "$zip_file_name" | awk '{ print $1 }')" > "$hash_file_name"

    # Remove the .bak directories
    rm -rf nom.bak network.bak consensus.bak
    if [ -d "cache.bak" ]; then
        rm -rf cache.bak
    fi

    echo "Backup completed at $backup_dir"
    echo "Cleanup completed!"
}

# Function to perform restore
do_restore() {
    # Check if backup directory exists
    if [ ! -d "/root/.znn/backup" ]; then
        echo "No backup directory found at /root/.znn/backup"
        exit 1
    fi

    # List available backups and let user choose
    echo "Available backups:"
    backup_dates=($(ls -1 /root/.znn/backup))
    if [ ${#backup_dates[@]} -eq 0 ]; then
        echo "No backups found"
        exit 1
    fi

    for i in "${!backup_dates[@]}"; do
        echo "$((i+1)): ${backup_dates[$i]}"
    done

    read -p "Select backup to restore (1-${#backup_dates[@]}): " selection

    # Validate selection
    if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#backup_dates[@]} ]; then
        echo "Invalid selection"
        exit 1
    fi

    selected_date=${backup_dates[$((selection-1))]}
    backup_path="/root/.znn/backup/$selected_date"
    current_datetime=$(date +"%Y%m%d%H%M%S")
    archive_dir="/root/.znn/archive/$current_datetime"

    # Stop the service
    systemctl stop go-zenon

    # Sleep 10 seconds to ensure service has stopped
    sleep 10

    # Create archive directory
    mkdir -p "$archive_dir"

    # Move current directories to archive with timestamp
    for dir in nom network consensus cache; do
        if [ -d "/root/.znn/$dir" ]; then
            mv "/root/.znn/$dir" "$archive_dir/${dir}.bak-$current_datetime"
        fi
    done

    # Unzip the backup
    cd "$backup_path"
    unzip "bootstrap-$selected_date.zip"

    # Move restored files to main directory
    for dir in nom.bak network.bak consensus.bak cache.bak; do
        if [ -d "$dir" ]; then
            mv "$dir" "/root/.znn/${dir%.bak}"
        fi
    done

    # Start the service
    systemctl start go-zenon

    echo "Restore completed successfully!"
    echo "Previous files archived in: $archive_dir"
}

# Check arguments
if [ "$#" -ne 1 ]; then
    usage
fi

# Make sure to run with root permissions
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Process commands
case "$1" in
    --backup)
        do_backup
        ;;
    --restore)
        do_restore
        ;;
    *)
        usage
        ;;
esac