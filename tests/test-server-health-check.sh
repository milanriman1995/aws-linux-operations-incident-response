
#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PROJECT_DIR/scripts/server-health-check.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEST_DIR"' EXIT

# Mock the Linux memory command.
cat > "$TEST_DIR/free" <<'EOF'
#!/usr/bin/env bash
echo "Mock memory information"
EOF

# Mock filesystem usage.
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
    exit 0
fi
exit 1
EOF

# Mock uptime for consistent test output.
cat > "$TEST_DIR/uptime" <<'EOF'
#!/usr/bin/env bash
echo "Mock uptime information"
EOF

chmod +x "$TEST_DIR/free" "$TEST_DIR/df" \
    "$TEST_DIR/systemctl" "$TEST_DIR/uptime"

passed=0
failed=0

run_test() {
    local name="$1"
    local disk_usage="$2"
    local expected_exit="$3"
    local actual_exit
    local output

    actual_exit=0

    output=$(MOCK_DISK_USAGE="$disk_usage" \
        PATH="$TEST_DIR:$PATH" \
        bash "$SCRIPT" 2>&1) || actual_exit=$?

    if [[ "$actual_exit" -eq "$expected_exit" ]]; then
        echo "PASS: $name"
        ((passed += 1))
    else
        echo "FAIL: $name"
        echo "Expected exit: $expected_exit"
        echo "Actual exit: $actual_exit"
        echo "$output"
        ((failed += 1))
    fi
}

run_test "Healthy disk (25%)" 25 0
run_test "Threshold reached (80%)" 80 1
run_test "Critical disk (85%)" 85 1

echo
echo "Tests passed: $passed"
echo "Tests failed: $failed"

if (( failed > 0 )); then
    exit 1
fi

exit 0

