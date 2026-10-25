
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PROJECT_DIR/scripts/server-health-check.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_DIR"' EXIT

# Mock system uptime.
cat > "$TEST_DIR/uptime" <<'EOF'
#!/usr/bin/env bash
echo "Mock uptime information"
EOF

# Mock memory information.
cat > "$TEST_DIR/free" <<'EOF'
#!/usr/bin/env bash
echo "Mock memory information"
EOF

# Mock filesystem utilisation.
cat > "$TEST_DIR/df" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-P" ]]; then
    echo "Filesystem 1024-blocks Used Available Capacity Mounted"
    echo "/dev/test 1000000 250000 750000 ${MOCK_DISK_USAGE}% /"
else
    echo "Mock filesystem information"
fi
EOF

# Mock SSM Agent status.
cat > "$TEST_DIR/systemctl" <<'EOF'
#!/usr/bin/env bash

if [[ "$*" == "is-active --quiet amazon-ssm-agent" ]]; then
    if [[ "${MOCK_SSM_STATUS:-running}" == "running" ]]; then
        exit 0
    fi
    exit 3
fi

exit 1
EOF

chmod +x "$TEST_DIR/"*

passed=0
failed=0

run_test() {
    local name="$1"
    local disk_usage="$2"
    local ssm_status="$3"
    local expected_exit="$4"
    local expected_message="$5"
    local expected_ssm_check="$6"

    local actual_exit=0
    local output

    output=$(
        MOCK_DISK_USAGE="$disk_usage" \
        MOCK_SSM_STATUS="$ssm_status" \
        PATH="$TEST_DIR:$PATH" \
        bash "$SCRIPT" 2>&1
    ) || actual_exit=$?

    local success=true

    # Verify the exit status.
    if [[ "$actual_exit" -ne "$expected_exit" ]]; then
        success=false
    fi

    # Verify the expected message.
    if [[ "$output" != *"$expected_message"* ]]; then
        success=false
    fi

    # Verify whether the SSM Agent check was reached.
    if [[ "$expected_ssm_check" == "yes" ]]; then
        if [[ "$output" != *"[4] SSM Agent Status"* ]]; then
            success=false
        fi
    else
        if [[ "$output" == *"[4] SSM Agent Status"* ]]; then
            success=false
        fi
    fi

    if [[ "$success" == "true" ]]; then
        echo "PASS: $name"
        ((passed += 1))
    else
        echo "FAIL: $name"
        echo "Expected exit: $expected_exit"
        echo "Actual exit: $actual_exit"
        echo "Expected message: $expected_message"
        echo "Actual output:"
        echo "$output"
        ((failed += 1))
    fi
}

run_test \
    "Healthy disk (25%)" \
    25 running 0 \
    "Disk utilisation is healthy: 25%" yes

run_test \
    "Threshold reached (80%)" \
    80 running 1 \
    "WARNING: Disk utilisation is 80%" no

run_test \
    "Critical disk (85%)" \
    85 running 1 \
    "WARNING: Disk utilisation is 85%" no

run_test \
    "SSM Agent stopped" \
    25 stopped 1 \
    "SSM Agent: NOT RUNNING" yes

echo
echo "Tests passed: $passed"
echo "Tests failed: $failed"

if (( failed > 0 )); then
    exit 1
fi

exit 0

