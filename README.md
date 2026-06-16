# Attendance Tracker - Project Factory

## How to run
1. Make the script executable:
   chmod +x setup_project.sh

2. Run it with your desired project suffix:
   ./setup_project.sh myproject
   (or run with no argument and you'll be prompted for a name)

3. This creates `attendance_tracker_myproject/` with:
   - attendance_checker.py
   - Helpers/assets.csv
   - Helpers/config.json
   - reports/reports.log

4. When prompted, choose whether to update the Warning/Failure
   thresholds. Values are validated to be numeric and written into
   config.json via `sed`.

5. The script then runs a health check (python3 --version) and
   verifies the directory structure.
# deploy_agent_eruhigira-tech
