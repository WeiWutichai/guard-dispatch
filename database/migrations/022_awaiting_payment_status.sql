-- Add awaiting_payment status for payment gate after guard accepts
ALTER TYPE assignment_status ADD VALUE IF NOT EXISTS 'awaiting_payment' AFTER 'accepted';
