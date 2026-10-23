
#!/usr/bin/env bash

# Project 1: Linux Server Health Check

set -u

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

echo
echo "[4] SSM Agent Status"

if systemctl is-active --quiet amazon-ssm-agent; then
    echo "SSM Agent: RUNNING"
else
    echo "SSM Agent: NOT RUNNING"
    exit 1
fi

echo
echo "Health check completed."

