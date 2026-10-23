
#!/usr/bin/env bash

# Project 1: Linux Server Health Check

set -euo pipefail

DISK_THRESHOLD=80

echo "================================="
echo " Linux Server Health Check"
echo "================================="

echo
echo "[1] System Uptime and Load"
uptime

echo
echo "[2] Memory Usage"
free -h

echo
echo "[3] Root Filesystem Usage"
df -h /

disk_usage=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

if [[ ! "$disk_usage" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Could not determine disk utilisation."
    exit 2
fi

if (( disk_usage >= DISK_THRESHOLD )); then
    echo "WARNING: Disk utilisation is ${disk_usage}%"
    exit 1
else
    echo "Disk utilisation is healthy: ${disk_usage}%"
fi

echo
echo "[4] SSM Agent Status"

if systemctl is-active --quiet amazon-ssm-agent; then
    echo "SSM Agent: RUNNING"
else
    echo "SSM Agent: NOT RUNNING"
    exit 1
fi

echo
echo "Health check completed successfully."
