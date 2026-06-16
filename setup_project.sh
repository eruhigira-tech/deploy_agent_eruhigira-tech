#!/bin/bash

TEMPLATE_DIR="template"
PROJECT_NAME="attendance_tracker"

trap archive_workspace SIGINT

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "The source code for the student attandance tracker project is missing"
    exit
fi

init_system() {
    clear
    
    read -p "Enter the variation of this project: " PROJ_VARIATION

    WORKSPACE="${PROJECT_NAME}_${PROJ_VARIATION}"
    
    if [ -d "$WORKSPACE" ]; then
        read -p "This workspace  $WORKSPACE already exists. Do you want to overwrite it [Y/N]? " OVERWRITE
        
		if [[ "$OVERWRITE" =~ ^[Yy]$ ]]; then
            echo "Overwriting the existing workspace: $WORKSPACE"
            rm -rf "$WORKSPACE"
        else
            echo "Aborting the setup process."
            exit
        fi
    fi

	does_archive_exist

	echo " Starting to create a new workspace => $WORKSPACE ......"

	mkdir "$WORKSPACE"

	echo ""
	echo "[OK] Workspace successfully created: $WORKSPACE"
	echo ""
	
	mkdir -p "$WORKSPACE/Helpers" "$WORKSPACE/reports"

	echo "[OK] created the workspace directories successfully"

    files_to_copy=(
        "attendance_checker.py|$WORKSPACE"
        "reports.log|$WORKSPACE/reports"
        "assets.csv|$WORKSPACE/Helpers"
        "config.json|$WORKSPACE/Helpers"
    )

    for file_entry in "${files_to_copy[@]}"; do
        IFS='|' read -r filename dest_dir <<< "$file_entry"

        cp "$TEMPLATE_DIR/$filename" "$dest_dir"
        echo "[OK] Migrated the $filename file to $dest_dir/"
    done

	echo ""

	echo "Successfully created migrated the whole workspace..."
	echo ""

	update_attendance_thresholds
}

update_attendance_thresholds() {
    read -p "Do you want to update the attendance thresholds [Y/N]? " IS_UPDATE

    if [[ "$IS_UPDATE" =~ ^[Yy]$ ]]; then
        read -p "Enter new warning threshold percentage[Default 75%]: " WARNING_THRESHOLD
        read -p "Enter new failure threshold percentage[Default 50%]: " FAILURE_THRESHOLD

        if ! [[ "$WARNING_THRESHOLD" =~ ^[0-9]+$ ]] || ! [[ "$FAILURE_THRESHOLD" =~ ^[0-9]+$ ]]; then
            clear
			echo "[ERROR] Thresholds must be valid numbers."
			update_attendance_thresholds
        elif [ "$WARNING_THRESHOLD" -lt 0 ] || [ "$WARNING_THRESHOLD" -gt 100 ] || [ "$FAILURE_THRESHOLD" -lt 0 ] || [ "$FAILURE_THRESHOLD" -gt 100 ]; then
            clear
			echo "[ERROR] Thresholds must be between 0 and 100."
			update_attendance_thresholds
        elif [ "$WARNING_THRESHOLD" -le "$FAILURE_THRESHOLD" ]; then
			clear
            echo "[ERROR] Warning threshold must be higher than failure threshold."
			update_attendance_thresholds
        fi

        sed -i "s/\"warning\": [0-9]*/\"warning\": $WARNING_THRESHOLD/" "$WORKSPACE/Helpers/config.json"
        sed -i "s/\"failure\": [0-9]*/\"failure\": $FAILURE_THRESHOLD/" "$WORKSPACE/Helpers/config.json"
        echo "Updated thresholds: Warning ==> ${WARNING_THRESHOLD}%  |  Failure ==> ${FAILURE_THRESHOLD}%"
		echo ""

		environment_checkup
    else
		echo "Used default thresholds: Warning ==> 75%  |  Failure ==> 50%"
		echo ""

		environment_checkup
    fi
    
}

environment_checkup() {
	echo "Starting Environement checkup..."
	echo ""

    if command -v python3 &> /dev/null; then
        echo "[OK] Python 3 is installed. Version: $(python3 --version)"
    else
        echo "[WARNING] Python 3 is not installed. Please install Python 3 to run this generated workspace."
    fi

	echo ""
	echo "Verifying workspace directory structure ..."
	echo ""

	required_paths=(
		"$WORKSPACE|The workspace($WORKSPACE) has not been created|directory"
		"$WORKSPACE/attendance_checker.py|The main python file (attendance_checker.py) is missing|file"
		"$WORKSPACE/Helpers/assets.csv|The assets.csv file is missing|file"
		"$WORKSPACE/Helpers/config.json|The config.json file is missing|file"
		"$WORKSPACE/reports/reports.log|The reports.log file is missing|file"
	)

	error_occurred=0
	for path_entry in "${required_paths[@]}"; do
		IFS='|' read -r path error_msg type <<< "$path_entry"
		
		if [ "$type" = "directory" ]; then
			if [ ! -d "$path" ]; then
				echo "[ERROR] $error_msg"
				error_occurred=1
			else
				echo "[OK] $path exists"
			fi
		else
			if [ ! -f "$path" ]; then
				echo "[ERROR] $error_msg"
				error_occurred=1
			else
				echo "[OK] $path exists"
			fi
		fi
	done

	if [ $error_occurred -eq 1 ]; then
		echo ""
		echo "[ERROR] Workspace environment checkup failed. Please fix the missing files."
		exit 1
	else
		echo ""
		echo "[OK] Workspace environment checkup completed"
		exit 0
	fi
}

archive_workspace() {
	clear
	echo ""

    echo "archiving start for the workspace: $WORKSPACE"

    mkdir -p "archives"
    LOG_FILE="archives/progress_${WORKSPACE}_$(date +%Y%m%d_%H%M%S).log"
    ARCHIVE_NAME="archives/archive_${WORKSPACE}.tar.gz"

    echo "Starting archive process for workspace: $WORKSPACE" >> "$LOG_FILE"

    if [ ! -d "$WORKSPACE" ]; then
        echo "Workspace directory does not exist - empty workspace" >> "$LOG_FILE"
        echo "Archive process completed: no files to archive" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
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

	echo ""
	echo "Missing $missing_files required files"
	echo ""

	if [ -f "$WORKSPACE/Helpers/config.json" ]; then
		warning=$(grep -o '"warning": [0-9]*' "$WORKSPACE/Helpers/config.json" | awk '{print $2}')
		failure=$(grep -o '"failure": [0-9]*' "$WORKSPACE/Helpers/config.json" | awk '{print $2}')
		
		if [ "$warning" -eq 75 ] && [ "$failure" -eq 50 ]; then
			echo "Config thresholds remain at default values: warning=$warning%, failure=$failure%" >> "$LOG_FILE"
		fi
	fi

    echo "Creating archive: $ARCHIVE_NAME"
    if tar -czf "$ARCHIVE_NAME" "$WORKSPACE"; then
        echo "Successfully created archive"
        
		echo ""
        echo "Deleting incomplete workspace directory"
        rm -rf "$WORKSPACE"
		
		echo ""
        echo "Archive process completed successfully"
    else
        echo "ERROR: Failed to create archive"
    fi

	exit 0
}

does_archive_exist() {
	echo ""

	ARCHIVE="archives/archive_${WORKSPACE}.tar.gz"
	if [[ -f "$ARCHIVE" ]]; then
		read -p "An archive for this WORKSPACE exists. Do you want to resume it [Y/N]? " RESUME

		if [[ "$RESUME" =~ ^[Yy]$ ]]; then
			echo ""
			echo "Extracting the WORKSPACE archive: $ARCHIVE ...."
			if tar -xzf "$ARCHIVE"; then
				echo "Successfully extracted workspace archive: $ARCHIVE"
				environment_checkup
				rm "$ARCHIVE" "archives/progress_${WORKSPACE}"*
				rm -rf "$WORKSPACE"
			else
				echo "Failed to extract the archive: $ARCHIVE"
				exit 0
			fi
		else
			echo "Creating a brand new WORKSPACE"
			rm "$ARCHIVE" "archives/progress_${WORKSPACE}"*
			return
		fi
	else
		return
	fi
}

init_system
