#!/bin/bash
# Automated Test Runner for RISC-V Processor
# Runs all test programs and reports results

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TESTS=(
    "test_alu"
    "test_memory"
    "test_branch"
    "test_muldiv"
)

# Results tracking
PASSED=0
FAILED=0
TOTAL=0

# Create results directory
RESULTS_DIR="test_results"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_FILE="$RESULTS_DIR/test_results_$TIMESTAMP.txt"

echo "=======================================" | tee "$RESULTS_FILE"
echo "RISC-V Processor Test Suite" | tee -a "$RESULTS_FILE"
echo "=======================================" | tee -a "$RESULTS_FILE"
echo "Date: $(date)" | tee -a "$RESULTS_FILE"
echo "=======================================" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

# Function to run a single test
run_test() {
    local test_name=$1
    local output_file="$RESULTS_DIR/${test_name}_output.txt"
    
    echo -n "Running ${test_name}... " | tee -a "$RESULTS_FILE"
    
    # Clean previous build
    make clean > /dev/null 2>&1
    
    # Build and run test
    if make TEST="$test_name" run > "$output_file" 2>&1; then
        # Check if test passed
        if grep -q "ALL TESTS PASSED" "$output_file"; then
            echo -e "${GREEN}PASSED${NC}" | tee -a "$RESULTS_FILE"
            ((PASSED++))
            
            # Extract summary
            passed_count=$(grep "Passed:" "$output_file" | awk '{print $2}')
            failed_count=$(grep "Failed:" "$output_file" | awk '{print $2}')
            echo "  Tests passed: $passed_count, failed: $failed_count" | tee -a "$RESULTS_FILE"
        else
            echo -e "${RED}FAILED${NC}" | tee -a "$RESULTS_FILE"
            ((FAILED++))
            
            # Show failure details
            echo "  Check $output_file for details" | tee -a "$RESULTS_FILE"
            if grep -q "TESTS FAILED" "$output_file"; then
                failed_count=$(grep "Failed:" "$output_file" | awk '{print $2}')
                echo "  Failed tests: $failed_count" | tee -a "$RESULTS_FILE"
            fi
        fi
    else
        echo -e "${RED}BUILD FAILED${NC}" | tee -a "$RESULTS_FILE"
        ((FAILED++))
        echo "  Check $output_file for build errors" | tee -a "$RESULTS_FILE"
    fi
    
    ((TOTAL++))
    echo "" | tee -a "$RESULTS_FILE"
}

# Run all tests
for test in "${TESTS[@]}"; do
    run_test "$test"
done

# Print summary
echo "=======================================" | tee -a "$RESULTS_FILE"
echo "Test Summary" | tee -a "$RESULTS_FILE"
echo "=======================================" | tee -a "$RESULTS_FILE"
echo "Total test suites: $TOTAL" | tee -a "$RESULTS_FILE"
echo -e "${GREEN}Passed:${NC}            $PASSED" | tee -a "$RESULTS_FILE"
echo -e "${RED}Failed:${NC}            $FAILED" | tee -a "$RESULTS_FILE"
echo "=======================================" | tee -a "$RESULTS_FILE"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}ALL TEST SUITES PASSED!${NC}" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"
    exit 0
else
    echo -e "${RED}$FAILED TEST SUITE(S) FAILED!${NC}" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"
    exit 1
fi
