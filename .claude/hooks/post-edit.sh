#!/bin/bash
# Post-tool hook: รันหลัง Claude Code แก้ไขไฟล์ .rs
# - cargo fmt อัตโนมัติ
# - ตรวจจับ .unwrap()
# - cargo clippy

FILE="$1"

# ทำงานเฉพาะไฟล์ .rs เท่านั้น
if [[ "$FILE" != *.rs ]]; then
    exit 0
fi

echo "🔧 Post-edit hook: $FILE"

# หา service root (folder ที่มี Cargo.toml)
SERVICE_DIR=$(dirname "$FILE")
while [[ "$SERVICE_DIR" != "/" ]]; do
    if [[ -f "$SERVICE_DIR/Cargo.toml" ]]; then
        break
    fi
    SERVICE_DIR=$(dirname "$SERVICE_DIR")
done

if [[ "$SERVICE_DIR" == "/" ]]; then
    echo "⚠️  ไม่พบ Cargo.toml"
    exit 0
fi

# 1. cargo fmt
echo "📐 Running cargo fmt..."
cd "$SERVICE_DIR"
cargo fmt 2>&1
if [[ $? -eq 0 ]]; then
    echo "✅ cargo fmt: passed"
else
    echo "❌ cargo fmt: failed"
fi

# 2. ตรวจจับ .unwrap() ในไฟล์ที่แก้ไข
echo "🔍 Checking for .unwrap()..."
UNWRAP_COUNT=$(grep -c "\.unwrap()" "$FILE" 2>/dev/null || echo 0)
if [[ "$UNWRAP_COUNT" -gt 0 ]]; then
    echo "⚠️  WARNING: พบ .unwrap() จำนวน $UNWRAP_COUNT จุดในไฟล์ $FILE"
    grep -n "\.unwrap()" "$FILE" | head -5
    echo "   กรุณาแทนที่ด้วย ? หรือ proper error handling"
fi

# 3. cargo clippy
echo "🔎 Running cargo clippy..."
cargo clippy 2>&1 | grep -E "^error|^warning" | head -20
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
    echo "✅ cargo clippy: passed"
else
    echo "⚠️  cargo clippy: มี warnings/errors — กรุณาตรวจสอบ"
fi

echo "✅ Post-edit hook เสร็จสิ้น"
exit 0
