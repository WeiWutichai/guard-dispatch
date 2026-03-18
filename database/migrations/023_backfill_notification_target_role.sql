-- Backfill target_role in notification payload for role-based filtering
-- Old notifications without target_role show on both guard and customer sides

-- Customer-targeted notifications
UPDATE notification.notification_logs
SET payload = COALESCE(payload, '{}'::jsonb) || '{"target_role": "customer"}'::jsonb
WHERE payload->>'target_role' IS NULL
  AND title IN (
    'การจองสำเร็จ',
    'เจ้าหน้าที่ตอบรับแล้ว',
    'เจ้าหน้าที่ปฏิเสธงาน',
    'เจ้าหน้าที่กำลังเดินทาง',
    'เจ้าหน้าที่ถึงแล้ว',
    'รอตรวจสอบงาน'
  );

-- Guard-targeted notifications
UPDATE notification.notification_logs
SET payload = COALESCE(payload, '{}'::jsonb) || '{"target_role": "guard"}'::jsonb
WHERE payload->>'target_role' IS NULL
  AND title IN (
    'งานใหม่ที่ได้รับ',
    'ชำระเงินสำเร็จ',
    'งานเสร็จสมบูรณ์',
    'คะแนนรีวิวใหม่'
  );
