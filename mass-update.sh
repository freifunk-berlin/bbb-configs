#!/bin/bash

# Define file directory and endings
WORK_DIR="tmp"
FILE_ENDINGS=".itb .bin .gz"

# Extract hosts from YAML files
mapfile -t COREROUTERS < <(yq '.hosts[] | select(.role == "corerouter" or .role == "gateway") | .hostname' locations/*.yml | tr -d '"')
mapfile -t APS < <(yq '.hosts[] | select(.role == "ap") | .hostname' locations/*.yml | tr -d '"')

# Find files matching the specified endings
FILES=()
for ENDING in $FILE_ENDINGS; do
    while IFS= read -r FILE_PATH; do
        FILES+=("$FILE_PATH")
    done < <(find "$WORK_DIR/images" -type f -name "*$ENDING")
done

# Separate files for APs and corerouters
AP_FILES=()
COREROUTER_FILES=()
for FILE_PATH in "${FILES[@]}"; do
    FILENAME=$(basename "$FILE_PATH")
    NODENAME="${FILENAME%.*}"

    # Check if the node belongs to APS or COREROUTERS
    if [[ " ${APS[*]} " == *" $NODENAME "* ]]; then
        AP_FILES+=("$FILE_PATH")
    elif [[ " ${COREROUTERS[*]} " == *" $NODENAME "* ]]; then
        COREROUTER_FILES+=("$FILE_PATH")
    fi
done

# Combine APs first, then corerouters
SORTED_FILES=("${AP_FILES[@]}" "${COREROUTER_FILES[@]}")

# List to track devices with missing root password
MISSING_PASSWORD_DEVICES=()

# Print information and prompt for confirmation
echo ""
echo "This script will do the following:"
echo ""
echo "- flash all the following hosts with the corresponding firmware files currently present in $WORK_DIR/images"
echo "- first flash APs, then corerouters and gateways based on the role derived from host within the YAML files"
echo "- check the accessibility of the hosts by establishing an SSH connection before and after flashing"
echo "- ignore keychecking"
echo "- reboot hosts and stop non essential services on hosts with less than '2x image size' of RAM available"
echo "- make sure that at least 'image size + 1 MB' of RAM is available before starting a firmware upgrade"
echo "- delete the local firmware file, build log, build and config files from disk after flashing"
echo "- check for missing root passwords and show a summary of devices missing a password"
echo ""
echo "Note: This script requires key-based SSH access for all hosts you want to flash."
echo ""
echo "The following firmware files will be flashed:"
for FILE_PATH in "${SORTED_FILES[@]}"; do
    echo "- $(basename "$FILE_PATH")"
done
echo ""
read -rp "Do you want to proceed [y/N]? " choice
echo ""
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo "Exiting..."
    exit 0
fi

# Function to check reachability
check_reachability() {
    local hostname="$1"
    timeout 6 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 "root@$hostname" exit >/dev/null 2>&1
}

# Function to run a SSH command with timeout
run_ssh() {
    local hostname="$1"
    local command="$2"
    timeout 20 ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -o ServerAliveInterval=1 -o ServerAliveCountMax=5 "root@$hostname" "$command"
}

# Function to check memory availability
check_memory() {
    local hostname="$1"
    run_ssh "$hostname" "free | awk 'NR==2 {print \$7}'"
}

# Function to check for missing root password
check_missing_root_password() {
    local hostname="$1"
    local password_field

    # Get the password field of root, or handle if the root user is missing
    password_field=$(run_ssh "$hostname" "awk -F: '\$1 == \"root\" { print \$2 }' /etc/shadow" 2>/dev/null)

    if [[ -z "$password_field" || "$password_field" =~ ^(\*|!|)?$ ]]; then
        MISSING_PASSWORD_DEVICES+=("$hostname")
    fi
}

# Function to reboot and wait for host to become reachable again
reboot() {
    local hostname="$1"
    echo "Rebooting $hostname..."
    run_ssh "$hostname" "reboot"
    echo "Waiting for $hostname to become unreachable..."
    while check_reachability "$hostname"; do sleep 1; done
    echo "Waiting for $hostname to become reachable again..."
    while ! check_reachability "$hostname"; do sleep 1; done
}

# Loop through each file
for FILE_PATH in "${SORTED_FILES[@]}"; do
    # Horizontal line to separate iterations
    echo "----------------------------------------"

    # Extract filename
    FILENAME=$(basename "$FILE_PATH")
    echo "Processing file: $FILENAME"

    # Build nodename by omitting the ending
    NODENAME="${FILENAME%.*}"
    echo "Nodename: $NODENAME"

    # Build hostname
    HOSTNAME="$NODENAME.ff"
    echo "Hostname: $HOSTNAME"

    # Check if hostname is accessible
    echo "Checking if $HOSTNAME is accessible..."
    if check_reachability "$HOSTNAME"; then
        echo "Hostname $HOSTNAME is accessible"

        # Check if device is considered low memory
        MEMORY=$(check_memory "$HOSTNAME")
        if [ "$MEMORY" -lt $(( $(stat -c %s "$FILE_PATH") * 2 / 1024 )) ]; then  # Less than 2x file size
            echo "Low memory detected ($MEMORY KB), initiating reboot sequence..."
            reboot "$HOSTNAME"
            echo "Stopping non-essential services on $HOSTNAME..."
            run_ssh "$HOSTNAME" "\
                /etc/init.d/collectd stop; \
                /etc/init.d/luci_statistics stop; \
                /etc/init.d/sysntpd stop; \
                /etc/init.d/urngd stop; \
                /etc/init.d/rpcd stop; \
                /etc/init.d/naywatch stop"
            sleep 20
            MEMORY=$(check_memory "$HOSTNAME")
        fi

        # Check memory on remote host before flashing
        MEMORY=$(check_memory "$HOSTNAME")
        if [ "$MEMORY" -ge $(( $(stat -c %s "$FILE_PATH") / 1024 + 1024 )) ]; then  # File size in KB + 1 MB
            echo "Memory on $HOSTNAME is sufficient ($MEMORY KB)"

            # SCP the file
            echo "Copying $FILENAME to $HOSTNAME:/tmp/"

            if timeout 120 scp -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5 -O "$FILE_PATH" "root@$HOSTNAME:/tmp/"; then

                echo "Executing sysupgrade on $HOSTNAME"
                # shellcheck disable=SC2029
                # Perform the sysupgrade; Ensure the connection terminates within 5 seconds using keep-alive in run_ssh
                UPGRADE_OUTPUT=$(run_ssh "$HOSTNAME" "sysupgrade '/tmp/$FILENAME'" 2>&1)
                echo "$UPGRADE_OUTPUT"
                if echo "$UPGRADE_OUTPUT" | grep -qi "Out of memory"; then
                    echo "Out of memory detected during upgrade, rebooting $HOSTNAME and skipping..."
                    reboot "$HOSTNAME"
                    continue
                fi

                # Wait for hostname to become unreachable
                echo "Waiting for $HOSTNAME to become unreachable..."
                while check_reachability "$HOSTNAME"; do sleep 1; done

                # Wait 20 seconds and then wait for hostname to become reachable again
                echo "Waiting for $HOSTNAME to become reachable again..."
                sleep 20
                while ! check_reachability "$HOSTNAME"; do sleep 1; done

                # Remove local files
                echo "Removing local files for $NODENAME from $WORK_DIR"
                rm -f "$FILE_PATH"
                rm -f "$WORK_DIR/images/$NODENAME.log"
                rm -rf "$WORK_DIR/build/$NODENAME"
                rm -rf "$WORK_DIR/configs/$NODENAME"
            else
                echo "SCP to $HOSTNAME failed. Rebooting and skipping..."
                reboot "$HOSTNAME"
                continue
            fi
        else
            echo "Skipping $HOSTNAME due to insufficient memory"
            continue
        fi

        # Check for missing root password
        check_missing_root_password "$HOSTNAME"
    else
        echo "Hostname $HOSTNAME is not reachable, skipping..."
        continue
    fi
done

# Print summary of devices with missing root password only if there are any
if [ ${#MISSING_PASSWORD_DEVICES[@]} -gt 0 ]; then
    echo "----------------------------------------"
    echo -e "\e[31mThe following devices miss a root password:\e[0m"
    for DEVICE in "${MISSING_PASSWORD_DEVICES[@]}"; do
        echo -e "\e[31m- $DEVICE\e[0m"
    done
    echo -e "\e[31mPlease set root passwords on all listed devices.\e[0m"
fi

echo "----------------------------------------"
echo "Finished"
