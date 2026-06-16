import os
import json
import csv

def run_tracker():
    print("Executing Student Attendance Processing Core...")
    config_path = os.path.join("Helpers", "config.json")
    assets_path = os.path.join("Helpers", "assets.csv")
    log_path = os.path.join("reports", "reports.log")
    
    if not os.path.exists(config_path):
        print(f"Error: Missing configuration map at {config_path}")
        return

    with open(config_path, 'r') as f:
        config = json.load(f)
    print(f"Active Threshold System Rules Loaded -> Warning: {config['warning_threshold']}%, Failure: {config['failure_threshold']}%")

if __name__ == "__main__":
    run_tracker()
