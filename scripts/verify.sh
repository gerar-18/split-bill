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

# 2. Build Check
echo "--> [2/3] Building SplitBill for generic iOS Simulator..."
xcodebuild -project "${PROJECT_PATH}" \
           -scheme "${SCHEME}" \
           -destination "generic/platform=iOS Simulator" \
           CODE_SIGNING_ALLOWED=NO \
           build > /dev/null
echo "✓ Build succeeded."

# 3. Test Check (Swift Testing)
if [ -z "${DESTINATION:-}" ]; then
    if xcrun simctl list devices available | grep -q "iPhone 17 ("; then
        DESTINATION="platform=iOS Simulator,name=iPhone 17"
    elif SIM_NAME=$(xcrun simctl list devices available | grep -E "iPhone " | head -n 1 | sed -E 's/^[[:space:]]+//; s/[[:space:]]+\(.*//'); [ -n "${SIM_NAME}" ]; then
        DESTINATION="platform=iOS Simulator,name=${SIM_NAME}"
    else
        DESTINATION="platform=iOS Simulator,name=iPhone 16"
    fi
fi

echo "--> [3/3] Running tests with Swift Testing on destination [${DESTINATION}]..."
xcodebuild test \
           -project "${PROJECT_PATH}" \
           -scheme "${SCHEME}" \
           -destination "${DESTINATION}" \
           CODE_SIGNING_ALLOWED=NO \
           -quiet
echo "✓ All tests passed!"

echo "=============================================="
echo "🎉 Verification complete! Everything is green."
echo "=============================================="
