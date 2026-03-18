-- Add 'video' to message_type enum for chat video attachments
ALTER TYPE message_type ADD VALUE IF NOT EXISTS 'video';
