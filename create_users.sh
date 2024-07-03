#!/bin/bash

# Script: create_users.sh
# Description: Creates users and groups based on input file, sets up home directories,
#              generates random passwords, and logs all actions.
# Usage: ./create_users.sh <input_file>

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if input file is provided
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure log file exists and has correct permissions
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"

# Ensure password file exists and has correct permissions
touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to generate a random password
generate_password() {
    openssl rand -base64 12 | tr -d '=+/'
}

# Read input file line by line
while IFS=';' read -r username groups; do
    # Skip empty lines
    [[ -z "$username" ]] && continue

    # Create user if it doesn't exist
    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping user creation."
    else
        useradd -m -s /bin/bash "$username"
        if [[ $? -eq 0 ]]; then
            log_message "User $username created successfully."
        else
            log_message "Failed to create user $username."
            continue
        fi
    fi

    # Set up home directory permissions
    chmod 700 "/home/$username"
    log_message "Set permissions for /home/$username"

    # Generate and set random password
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> "$PASSWORD_FILE"
    log_message "Set password for user $username"

    # Create and add user to groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            log_message "Group $group created."
        fi
        usermod -aG "$group" "$username"
        log_message "Added user $username to group $group"
    done

done < "$INPUT_FILE"

log_message "User creation process completed."
echo "User creation process completed. Check $LOG_FILE for details."
