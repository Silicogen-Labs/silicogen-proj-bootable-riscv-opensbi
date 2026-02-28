#!/bin/bash
# Boot OpenSBI and display UART output cleanly
#
# The simulator outputs debug messages mixed with UART characters.
# This script filters and displays just the UART console output.

set -e

cd "$(dirname "$0")/.."

echo "=== Bootble RISC-V Soft Processor Core - OpenSBI Boot ==="
echo ""

# Clean up old logs
rm -f /tmp/uart_output.txt /tmp/sim_*.log

# Run simulator in background with timeout
# All debug output goes to stderr/files, UART goes to /tmp/uart_output.txt
echo "Starting simulation (60 second timeout)..."
echo "(Debug output suppressed - UART captured to /tmp/uart_output.txt)"
echo ""

timeout 60 ./build/verilator/Vtb_soc > /tmp/sim_stdout.log 2>&1 || true

# Show UART output
echo "=== UART Console Output ==="
echo ""
if [ -f /tmp/uart_output.txt ] && [ -s /tmp/uart_output.txt ]; then
    cat /tmp/uart_output.txt
    echo ""
    echo "=== Boot Complete ==="
    CHARS=$(wc -c < /tmp/uart_output.txt)
    echo "Total characters output: $CHARS"
    
    # Quick verification
    if grep -q "OpenSBI" /tmp/uart_output.txt; then
        echo "Status: OpenSBI boot SUCCESSFUL"
    else
        echo "Status: WARNING - OpenSBI banner not found"
    fi
else
    echo "ERROR: No UART output captured"
    echo ""
    echo "Check /tmp/sim_stdout.log for debug output:"
    tail -20 /tmp/sim_stdout.log 2>/dev/null || echo "(log file not found)"
    exit 1
fi
