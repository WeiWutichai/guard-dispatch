#!/bin/bash
# Pre-tool hook: บล็อก destructive commands
# ไฟล์นี้รันก่อน Claude Code ใช้ bash tool ทุกครั้ง
# Exit code 2 = blocked

COMMAND="$1"

# รายการ pattern ที่อันตราย
DANGEROUS_PATTERNS=(
    "rm -rf"
    "rm -fr"
    "DROP TABLE"
    "DROP SCHEMA"
    "DROP DATABASE"
    "TRUNCATE"
    "DELETE FROM.*WHERE.*1=1"
    "sudo rm"
    "format"
    "> /dev/sd"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qi "$pattern"; then
        echo "🚫 BLOCKED: Destructive command detected: '$pattern'"
        echo "   Command: $COMMAND"
        echo "   กรุณายืนยันด้วยตนเองก่อนรันคำสั่งนี้"
        exit 2
    fi
done

exit 0
