#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo " Running SplitBill Verification (M0 Foundation)"
echo "=============================================="

PROJECT_PATH="apps/SplitBill/SplitBill.xcodeproj"
SCHEME="SplitBill"
DESTINATION="platform=iOS Simulator,name=iPhone 17"

# 1. Architecture Check: Ensure Domain layer has NO dependency on SwiftUI or SwiftData (ADR-002)
echo "--> [1/3] Verifying architecture boundaries (ADR-002)..."
if [ -d "apps/SplitBill/SplitBill/Domain" ]; then
    if grep -rn "import SwiftUI" apps/SplitBill/SplitBill/Domain/ 2>/dev/null; then
        echo "❌ Architecture violation: Domain layer must not import SwiftUI (see docs/decisions/ADR-002-domain-separation.md)."
        exit 1
    fi
    if grep -rn "import SwiftData" apps/SplitBill/SplitBill/Domain/ 2>/dev/null; then
        echo "❌ Architecture violation: Domain layer must not import SwiftData (see docs/decisions/ADR-002-domain-separation.md)."
        exit 1
    fi
fi
echo "✓ Architecture boundaries respected."

# 2. Build Check
echo "--> [2/3] Building SplitBill..."
xcodebuild -project "${PROJECT_PATH}" \
           -scheme "${SCHEME}" \
           -destination "generic/platform=iOS Simulator" \
           CODE_SIGNING_ALLOWED=NO \
           build > /dev/null
echo "✓ Build succeeded."

# 3. Test Check (Swift Testing)
echo "--> [3/3] Running tests with Swift Testing..."
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
