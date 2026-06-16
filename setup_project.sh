#!/bin/bash

PROJECT_DIR=""
USER_INPUT=""

cleanup_trap() {
    echo -e "\n\n[!] Caught SIGINT (Ctrl+C) Interrupt Signal!"

    if [[ -n "$PROJECT_DIR" && -d "$PROJECT_DIR" ]]; then
        ARCHIVE_NAME="attendance_tracker_${USER_INPUT}_archive.tar.gz"
        echo "[*] Creating safety recovery archive: ${ARCHIVE_NAME}..."

	tar -czf "$ARCHIVE_NAME" "./$PROJECT_DIR" 2>/dev/null

        echo "[*] Purging uncompleted partial workspace directory structures..."
        rm -rf "$PROJECT_DIR"
    fi

    echo "[✓] Workspace cleaned successfully. Terminating execution."
    exit 1
}

trap cleanup_trap SIGINT

echo "=== Student Attendance Tracker Setup Factory ==="
read -r -p "Enter a unique project identifier string suffix: " USER_INPUT

if [[ -z "${USER_INPUT// }" ]]; then
    echo "[X] Error: Project naming string identifier cannot be blank."
    exit 1
fi

PROJECT_DIR="attendance_tracker_${USER_INPUT}"

if [ -d "$PROJECT_DIR" ]; then
    echo "[X] Error: Destination architecture directory '${PROJECT_DIR}' already exists."
    exit 1
fi

echo "[*] Deploying system directory paths..."
if ! mkdir  -p "$PROJECT_DIR"/{Helpers,reports} 2> /tmp/error.log; then 
    echo "[X] Error!"
    cat /tmp/error.log
    exit 1

fi

echo "[*] Seeding default template source code files..."

cat << 'EOF' > "$PROJECT_DIR/attendance_checker.py"
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)
    
    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']
        
        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")
        
        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])
            
            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100
            
            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."
            
            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
EOF

cat << 'EOF' > "$PROJECT_DIR/Helpers/assets.csv"
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
EOF

cat << 'EOF' > "$PROJECT_DIR/Helpers/config.json"
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
EOF

cat << 'EOF' > "$PROJECT_DIR/reports/reports.log"
--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT: Charlie Davis, your attendance is 26.7%. You will fail this class.
EOF

chmod +x "$PROJECT_DIR/attendance_checker.py"

echo -e "\n--- Dynamic Configuration Upgrades ---"
read -r -p "Would you like to customize the attendance thresholds? (y/N): " CHOOSE_UPDATE

if [[ "$CHOOSE_UPDATE" =~ ^[Yy]*$ ]]; then
    read -r -p "Enter custom Warning threshold (Numeric 0-100 | Default 75): " WARNING_IN
    WARNING_IN=${WARNING_IN:-75}

    read -r -p "Enter custom Failure threshold (Numeric 0-100 | Default 50): " FAILURE_IN
    FAILURE_IN=${FAILURE_IN:-50}

    WARNING_IN="${WARNING_IN// /}"
    FAILURE_IN="${FAILURE_IN// /}"

       if ! [[ "$WARNING_IN" =~ ^(100|[0-9]{1,2})$ ]] || ! [[ "$FAILURE_IN" =~ ^(100|[0-9]{1,2})$ ]]; then
        echo "[X] Input Validation Error: Thresholds must be numeric values between 0 and 100. Falling back to defaults."
        WARNING_IN=75
        FAILURE_IN=50
    fi

    if (( FAILURE_IN >= WARNING_IN )); then
        echo "[X] Input Validation Error: Failure threshold must be less than Warning threshold. Falling back to defaults."
        WARNING_IN=75
        FAILURE_IN=50
    fi

    echo "[*] Overwriting configurations inline using stream editing engine..."

    sed -i "s/\"warning\": [0-9]*/\"warning\": $WARNING_IN/" "$PROJECT_DIR/Helpers/config.json"
    sed -i "s/\"failure\": [0-9]*/\"failure\": $FAILURE_IN/" "$PROJECT_DIR/Helpers/config.json"

    echo "[✓] Configuration parameters updated in config.json successfully."
fi

echo -e "\n--- Environment Health Check Validation ---"
STRUCTURE_VALID=true

if python3 --version >/dev/null 2>&1; then
    PY_VER_STR=$(python3 --version)
    echo "[✓] System Runtime Validation Success: $PY_VER_STR detected."
else
    echo "[!] System Runtime Warning: python3 was not detected globally in local paths."
    STRUCTURE_VALID=false
fi

echo "[*] Reviewing structural deployment mappings..."
REQUIRED_FILES=(
    "$PROJECT_DIR/attendance_checker.py"
    "$PROJECT_DIR/Helpers/assets.csv"
    "$PROJECT_DIR/Helpers/config.json"
    "$PROJECT_DIR/reports/reports.log"
)

for target_file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$target_file" ]; then
        echo "  -> Verified: $target_file [OK]"
    else
        echo "  -> Missing File Failure: $target_file [CRITICAL]"
        STRUCTURE_VALID=false
    fi
done

if [ "$STRUCTURE_VALID" = true ]; then
    echo -e "\n[✓] Exemplary Deployment Completed Successfully for workspace: $PROJECT_DIR"
else
    echo -e "\n[X] Error: Architecture verification layout health checks failed."
    exit 1
fi
