#!/usr/bin/env bash
# El integrity check — fails if index.html is truncated or malformed.
# Used by .git/hooks/pre-commit and the GitHub Actions workflow.
set -e

FILE="${1:-index.html}"

if [ ! -f "$FILE" ]; then
  echo "X integrity: $FILE not found"
  exit 1
fi

LINES=$(wc -l < "$FILE")
TAIL_END=$(tail -c 200 "$FILE")

# Minimum reasonable size — bumped any time the app legitimately grows.
MIN_LINES=5500

if [ "$LINES" -lt "$MIN_LINES" ]; then
  echo "X integrity: $FILE is only $LINES lines (expected at least $MIN_LINES)."
  echo "   The file may have been truncated. Restore with: git checkout -- $FILE"
  exit 1
fi

if ! printf '%s' "$TAIL_END" | grep -q "</html>"; then
  echo "X integrity: $FILE does not end with </html>."
  echo "   The file may have been truncated. Restore with: git checkout -- $FILE"
  exit 1
fi

if ! printf '%s' "$TAIL_END" | grep -q "</script>"; then
  echo "X integrity: $FILE is missing the closing </script> near the end."
  echo "   The file may have been truncated. Restore with: git checkout -- $FILE"
  exit 1
fi

# Cheap brace balance check (not perfect for braces inside strings, but catches
# the common truncation case where a few hundred trailing braces vanish).
OPEN=$(grep -o '{' "$FILE" | wc -l)
CLOSE=$(grep -o '}' "$FILE" | wc -l)
DIFF=$((OPEN - CLOSE))
if [ "$DIFF" -gt 2 ] || [ "$DIFF" -lt -2 ]; then
  echo "X integrity: brace imbalance in $FILE — $OPEN open, $CLOSE close (diff $DIFF)."
  echo "   This usually means the file was cut off mid-block."
  exit 1
fi

echo "OK integrity: $FILE = $LINES lines, ends correctly, braces balanced."
