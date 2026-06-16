#!/bin/bash

TEMPLATE_DIR="template"
PROJECT_NAME="attendance_tracker"
WORKSPACE=""

archive_workspace() {
    clear
    echo -e "\n"
    echo "[!] Caught SIGINT (Ctrl+C) Interrupt Signal!"
    echo "[*] Archiving start for the workspace: $WORKSPACE"

    mkdir -p "archives"
    LOG_FILE="archives/progress_${WORKSPACE}_$(date +%Y%m%d_%H%M%S).log"
    ARCHIVE_NAME="archives/archive_${WORKSPACE}.tar.gz"

    echo "Starting archive process for workspace: $WORKSPACE" >> "$LOG_FILE"

    if [ ! -d "$WORKSPACE" ]; then
        echo "Workspace directory does not exist - empty workspace" >> "$LOG_FILE"
        echo "Archive process completed: no files to archive" >> "$LOG_FILE"
        echo -e "\n" >> "$LOG_FILE"
        exit 0
    fi

    required_files=(
        "$WORKSPACE/attendance_checker.py"
        "$WORKSPACE/Helpers/assets.csv"
        "$WORKSPACE/Helpers/config.json"
        "$WORKSPACE/reports/reports.log"
    )

    missing_files=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "Missing required file: $file" >> "$LOG_FILE"
            ((missing_files++))
        fi
    done

    echo "[*] Missing $missing_files required files during interruption."
    echo "Missing $missing_files required files" >> "$LOG_FILE"

    if [ -f "$WORKSPACE/Helpers/config.json" ]; then
        warning=$(grep -o '"warning_threshold": [0-9]*' "$WORKSPACE/Helpers/config.json" | awk '{print $2}')
        failure=$(grep -o '"failure_threshold": [0-9]*' "$WORKSPACE/Helpers/config.json" | awk '{print $2}')
        echo "Config thresholds at interruption point: warning=$warning%, failure=$failure%" >> "$LOG_FILE"
    fi

    echo "[*] Creating archive: $ARCHIVE_NAME"
    if tar -czf "$ARCHIVE_NAME" "$WORKSPACE" 2>/dev/null; then
        echo "[✓] Successfully created safety recovery archive."
        echo -e "\n[*] Deleting incomplete workspace directory to maintain workspace hygiene..."
        rm -rf "$WORKSPACE"
        echo -e "\n[✓] Archive process completed successfully."
    else
        echo "[X] ERROR: Failed to create archive."
    fi

    exit 0
}

trap archive_workspace SIGINT


does_archive_exist() {
    echo ""
    ARCHIVE="archives/archive_${WORKSPACE}.tar.gz"
    
    if [[ -f "$ARCHIVE" ]]; then
        read -p "[?] An archive for this WORKSPACE exists. Do you want to resume it [Y/N]? " RESUME

        if [[ "$RESUME" =~ ^[Yy]$ ]]; then
            echo ""
            echo "[*] Extracting the WORKSPACE archive: $ARCHIVE ...."
            if tar -xzf "$ARCHIVE"; then
                echo "[✓] Successfully extracted workspace archive: $ARCHIVE"
                                rm "$ARCHIVE" "archives/progress_${WORKSPACE}"* 2>/dev/null
                environment_checkup
            else
                echo "[X] Failed to extract the archive: $ARCHIVE"
                exit 1
            fi
        else
            echo "[*] Creating a brand new WORKSPACE instead. Clearing old archive tracks..."
            rm "$ARCHIVE" "archives/progress_${WORKSPACE}"* 2>/dev/null
            return
        fi
    else
        return
    fi
}

init_system() {
    clear
    
    read -p "Enter the variation/suffix of this project: " PROJ_VARIATION

    if [[ -z "${PROJ_VARIATION// }" ]]; then
        echo "[X] Error: Suffix variation string identifier cannot be completely empty."
        exit 1
    fi

    WORKSPACE="${PROJECT_NAME}_${PROJ_VARIATION}"
    
    if [ -d "$WORKSPACE" ]; then
        read -p "[!] This workspace $WORKSPACE already exists. Do you want to overwrite it [Y/N]? " OVERWRITE
        
        if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo "[*] Overwriting the existing workspace: $WORKSPACE"
            rm -rf "$WORKSPACE"
        else
            echo "Aborting the setup process."
            exit 0
        fi
    fi

    does_archive_exist

    echo "[*] Starting to create a new workspace => $WORKSPACE ......"
    mkdir -p "$WORKSPACE/Helpers" "$WORKSPACE/reports"
    echo "[OK] Created the workspace directories successfully."

    files_to_copy=(
        "attendance_checker.py|$WORKSPACE"
        "reports.log|$WORKSPACE/reports"
        "assets.csv|$WORKSPACE/Helpers"
        "config.json|$WORKSPACE/Helpers"
    )

    for file_entry in "${files_to_copy[@]}"; do
        IFS='|' read -r filename dest_dir <<< "$file_entry"
        if [ -f "$filename" ]; then
            cp "$filename" "$dest_dir/"
            echo "[OK] Migrated the $filename file to $dest_dir/"
        else
            echo "[X] Error during migration: Source $filename not found!"
            exit 1
        fi
    done

    chmod +x "$WORKSPACE/attendance_checker.py"
    echo -e "\n[✓] Successfully created and migrated the whole workspace structure."
    
    update_attendance_thresholds
}

update_attendance_thresholds() {
    read -p "Do you want to update the attendance thresholds [Y/N]? " IS_UPDATE

    if [[ "$IS_UPDATE" =~ ^[Yy]$ ]]; then
        read -p "Enter new warning threshold percentage [Default 75]: " WARNING_THRESHOLD
        WARNING_THRESHOLD=${WARNING_THRESHOLD:-75}
        
        read -p "Enter new failure threshold percentage [Default 50]: " FAILURE_THRESHOLD
        FAILURE_THRESHOLD=${FAILURE_THRESHOLD:-50}

       if ! [[ "$WARNING_THRESHOLD" =~ ^[0-9]+$ ]] || ! [[ "$FAILURE_THRESHOLD" =~ ^[0-9]+$ ]]; then
            echo -e "\n[ERROR] Thresholds must be valid whole numbers."
            update_attendance_thresholds
            return
        elif [ "$WARNING_THRESHOLD" -lt 0 ] || [ "$WARNING_THRESHOLD" -gt 100 ] || [ "$FAILURE_THRESHOLD" -lt 0 ] || [ "$FAILURE_THRESHOLD" -gt 100 ]; then
            echo -e "\n[ERROR] Thresholds must be between 0 and 100."
            update_attendance_thresholds
            return
        elif [ "$WARNING_THRESHOLD" -le "$FAILURE_THRESHOLD" ]; then
            echo -e "\n[ERROR] Warning threshold must be strictly higher than failure threshold."
            update_attendance_thresholds
            return
        fi

        sed -i "s/\"warning_threshold\": .*/\"warning_threshold\": $WARNING_THRESHOLD,/" "$WORKSPACE/Helpers/config.json"
        sed -i "s/\"failure_threshold\": .*/\"failure_threshold\": $FAILURE_THRESHOLD/" "$WORKSPACE/Helpers/config.json"
        
        echo -e "[✓] Updated thresholds: Warning ==> ${WARNING_THRESHOLD}% | Failure ==> ${FAILURE_THRESHOLD}%\n"
        environment_checkup
    else
        echo -e "Using default configuration specifications: Warning ==> 75% | Failure ==> 50%\n"
        environment_checkup
    fi
}

environment_checkup() {
    echo "--- Starting Environment Checkup Verification ---"
    echo ""

    if command -v python3 &> /dev/null; then
        echo "[OK] Python 3 runtime is accessible. Version: $(python3 --version)"
    else
        echo "[WARNING] Python 3 runtime engine was not found on system path environments."
    fi

    echo -e "\nVerifying workspace directory layout structural paths..."

    required_paths=(
        "$WORKSPACE|The workspace ($WORKSPACE) has not been properly instantiated|directory"
        "$WORKSPACE/attendance_checker.py|The core script execution module (attendance_checker.py) is missing|file"
        "$WORKSPACE/Helpers/assets.csv|The database tracking record metadata (assets.csv) file is missing|file"
        "$WORKSPACE/Helpers/config.json|The primary properties config mapping schema (config.json) file is missing|file"
        "$WORKSPACE/reports/reports.log|The historical system operational trace module (reports.log) file is missing|file"
    )

    error_occurred=0
    for path_entry in "${required_paths[@]}"; do
        IFS='|' read -r path error_msg type <<< "$path_entry"
        
        if [ "$type" = "directory" ]; then
            if [ ! -d "$path" ]; then
                echo "[ERROR] $error_msg"
                error_occurred=1
            else
                echo "  -> [OK] Directory Verified: $path"
            fi
        else
            if [ ! -f "$path" ]; then
                echo "[ERROR] $error_msg"
                error_occurred=1
            else
                echo "  -> [OK] File Verified: $path"
            fi
        fi
    done

    if [ $error_occurred -eq 1 ]; then
        echo -e "\n[ERROR] Workspace runtime layout checks failed. Rectify the manual gaps listed above."
        exit 1
    else
        echo -e "\n[✓] Success: All architecture path structures validated cleanly."
        exit 0
    fi
}

init_system
