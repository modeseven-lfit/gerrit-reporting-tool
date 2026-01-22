#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

#!/bin/bash
# Verification script for DataTables integration

echo "=========================================="
echo "DataTables Integration Verification"
echo "=========================================="
echo ""

# Run tests
echo "1. Running integration tests..."
python -m pytest tests/test_datatables_integration.py -v --tb=short
TEST_RESULT=$?

echo ""
echo "2. Running linting checks..."
pre-commit run --files \
  src/templates/html/base.html.j2 \
  src/templates/html/components/datatables_support.html.j2 \
  src/templates/html/components/data_table.html.j2 \
  src/rendering/context.py \
  tests/test_datatables_integration.py \
  --show-diff-on-failure
LINT_RESULT=$?

echo ""
echo "3. Checking file existence..."
FILES=(
  "src/templates/html/components/datatables_support.html.j2"
  "src/themes/default/theme.css"
  "src/themes/dark/theme.css"
  "src/themes/minimal/theme.css"
  "tests/test_datatables_integration.py"
  "docs/DATATABLES_USAGE.md"
  "docs/DATATABLES_IMPLEMENTATION.md"
)

FILE_CHECK=0
for file in "${FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✅ $file"
  else
    echo "  ❌ $file MISSING"
    FILE_CHECK=1
  fi
done

echo ""
echo "=========================================="
echo "Verification Results"
echo "=========================================="
if [ $TEST_RESULT -eq 0 ] && [ $LINT_RESULT -eq 0 ] && [ $FILE_CHECK -eq 0 ]; then
  echo "✅ ALL CHECKS PASSED"
  echo "DataTables integration is ready for production!"
  exit 0
else
  echo "❌ SOME CHECKS FAILED"
  [ $TEST_RESULT -ne 0 ] && echo "  - Tests failed"
  [ $LINT_RESULT -ne 0 ] && echo "  - Linting failed"
  [ $FILE_CHECK -ne 0 ] && echo "  - Files missing"
  exit 1
fi
