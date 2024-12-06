#!/bin/bash

# Define file directory and endings
WORK_DIR="tmp"
FILE_ENDINGS=".itb .bin"

# Find files matching the specified endings
FILES=""
for ENDING in $FILE_ENDINGS; do
    FILES="$FILES $(find "$WORK_DIR/images" -type f -name "*$ENDING")"
done

# Sort files based on whether filename contains "core" or not
CORE_FILES=""
OTHER_FILES=""
for FILE_PATH in $FILES; do
    if [[ "$FILE_PATH" == *"core"* ]]; then
        CORE_FILES="$CORE_FILES $FILE_PATH"
    else
        OTHER_FILES="$OTHER_FILES $FILE_PATH"
    fi
done
SORTED_FILES="$OTHER_FILES $CORE_FILES"

# Print information and prompt for confirmation
echo ""
echo "This script will do the following:"
echo ""
echo "- flash all the following hosts with the corresponding firmware files currently present in $WORK_DIR/images"
echo "- first flash APs, than core routers based on the naming convention"
echo "- check the availability of the hosts before and after flashing"
echo "- ignore keychecking"
echo "- make sure that at least 'image size + 1 MB' of RAM is available before starting a firmware upgrade"
echo "- delete the local firmware file, build log, build and config files from disk after flashing"
echo ""
echo "The following firmware files will be flashed:"
for FILE_PATH in $SORTED_FILES; do
    echo "- $(basename "$FILE_PATH")"
done
echo ""
read -rp "Do you want to proceed [y/N]? " choice
echo ""
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
    echo "Exiting..."
    exit 0
fi

# Loop through each file
for FILE_PATH in $SORTED_FILES; do
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

    # Check if hostname is reachable
    echo "Checking if $HOSTNAME is reachable..."
    if ping -c 1 "$HOSTNAME" >/dev/null 2>&1; then
        echo "Hostname $HOSTNAME is reachable"

        # Check memory on remote host
        MEMORY=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$HOSTNAME" "free | awk 'NR==2 {print \$7}'")
        if [ "$MEMORY" -ge $(( $(stat -c %s "$FILE_PATH") / 1024 + 1024 )) ]; then  # File size in KB + 1 MB
            echo "Memory on $HOSTNAME is sufficient ($MEMORY KB)"

            # SCP the file
            echo "Copying $FILENAME to $HOSTNAME:/tmp/"
            if scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -O "$FILE_PATH" "root@$HOSTNAME:/tmp/"; then
                # Debug output: Executing sysupgrade
                echo "Executing sysupgrade on $HOSTNAME"
                # shellcheck disable=SC2029
                ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "root@$HOSTNAME" "sysupgrade '/tmp/$FILENAME'"

                # Wait for hostname to become unreachable
                echo "Waiting for $HOSTNAME to become unreachable..."
                while ping -c 1 "$HOSTNAME" >/dev/null 2>&1; do sleep 1; done

                # Wait 20 seconds and than wait for hostname to become reachable again
                echo "Waiting for $HOSTNAME to become reachable again..."
                sleep 20
                while ! ping -c 1 "$HOSTNAME" >/dev/null 2>&1; do sleep 1; done

                # Remove local files
                echo "Removing local files for $NODENAME from $WORK_DIR"
                rm "$FILE_PATH"
                rm "$WORK_DIR/images/$NODENAME.log"
                rm -rf "$WORK_DIR/build/$NODENAME"
                rm -rf "$WORK_DIR/configs/$NODENAME"
            else
                echo "SCP command failed. Exiting..."
                exit 1
            fi

        else
            echo "Skipping file transfer due to insufficient memory on $HOSTNAME"
        fi

    else
        echo "Hostname $HOSTNAME is not reachable"
    fi

done
# Horizontal line to separate iterations
echo "----------------------------------------"
echo "Finished"
