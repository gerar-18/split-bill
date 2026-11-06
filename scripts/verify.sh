#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo " Running SplitBill Verification Pipeline"
echo "=============================================="

PROJECT_PATH="apps/SplitBill/SplitBill.xcodeproj"
SCHEME="SplitBill"

# 1. Architecture Check: Ensure Domain layer has NO dependency on SwiftUI, SwiftData, or binary floats (ADR-002)
echo "--> [1/3] Verifying architecture boundaries and financial invariants (ADR-002)..."
if [ -d "apps/SplitBill/SplitBill/Domain" ]; then
    if grep -rn "import SwiftUI" apps/SplitBill/SplitBill/Domain/ 2>/dev/null; then
        echo "❌ Architecture violation: Domain layer must not import SwiftUI (see docs/decisions/ADR-002-domain-separation.md)."
        exit 1
    fi
    if grep -rn "import SwiftData" apps/SplitBill/SplitBill/Domain/ 2>/dev/null; then
        echo "❌ Architecture violation: Domain layer must not import SwiftData (see docs/decisions/ADR-002-domain-separation.md)."
        exit 1
    fi
    if grep -E -rn "\b(Double|Float)\b" apps/SplitBill/SplitBill/Domain/ 2>/dev/null; then
        echo "❌ Financial invariant violation: Domain layer must not represent money with binary floating point (Float/Double)."
        exit 1
    fi
fi
echo "✓ Architecture boundaries and financial invariants respected."

# Determine Destination & Simulator Device
SIM_LINE=""
if [ -z "${DESTINATION:-}" ]; then
    if SIM_LINE=$(xcrun simctl list devices available | grep -E "iPhone 17 \(" | head -n 1) && [ -n "${SIM_LINE}" ]; then
        SIM_NAME="iPhone 17"
    elif SIM_LINE=$(xcrun simctl list devices available | grep -E "iPhone 16 \(" | head -n 1) && [ -n "${SIM_LINE}" ]; then
        SIM_NAME="iPhone 16"
    elif SIM_LINE=$(xcrun simctl list devices available | grep -E "iPhone " | head -n 1) && [ -n "${SIM_LINE}" ]; then
        SIM_NAME=$(echo "${SIM_LINE}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(.*//')
    else
        SIM_NAME="iPhone 16"
        SIM_LINE=""
    fi
    DESTINATION="platform=iOS Simulator,name=${SIM_NAME}"
fi

# Pre-boot simulator if an available device UUID is identified and not yet booted
SIM_ID=$(echo "${SIM_LINE:-}" | grep -o -E '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -n 1 || true)
if [ -n "${SIM_ID}" ]; then
    if ! xcrun simctl list devices | grep "${SIM_ID}" | grep -q "Booted"; then
        echo "--> Pre-booting simulator ${SIM_NAME} (${SIM_ID})..."
        xcrun simctl boot "${SIM_ID}" 2>/dev/null || true
        xcrun simctl bootstatus "${SIM_ID}" -b
    fi
fi

# 2. Build for Testing (Single-pass build avoiding duplicate compilation)
echo "--> [2/3] Building SplitBill for destination [${DESTINATION}]..."
xcodebuild -project "${PROJECT_PATH}" \
           -scheme "${SCHEME}" \
           -destination "${DESTINATION}" \
           CODE_SIGNING_ALLOWED=NO \
           -quiet \
           build-for-testing
echo "✓ Build succeeded."

# 3. Test Check (Fast execution of Swift Testing without recompilation)
echo "--> [3/3] Running tests with Swift Testing on destination [${DESTINATION}]..."
xcodebuild test-without-building \
           -project "${PROJECT_PATH}" \
           -scheme "${SCHEME}" \
           -destination "${DESTINATION}" \
           CODE_SIGNING_ALLOWED=NO \
           -enableCodeCoverage NO \
           -quiet
echo "✓ All tests passed!"

echo "=============================================="
echo "🎉 Verification complete! Everything is green."
echo "=============================================="
