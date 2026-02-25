use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::primitives::ByteStream;
use std::time::Duration;

use shared::error::AppError;

const SIGNED_URL_EXPIRY_SECS: u64 = 3600; // 1 hour per CLAUDE.md
const MAX_FILE_SIZE: usize = 10 * 1024 * 1024; // 10MB per CLAUDE.md

/// Allowed MIME types (per CLAUDE.md: JPEG, PNG, WEBP only)
const ALLOWED_MIME_TYPES: &[&str] = &["image/jpeg", "image/png", "image/webp"];

/// Validate file upload constraints
pub fn validate_upload(mime_type: &str, file_size: usize) -> Result<(), AppError> {
    if !ALLOWED_MIME_TYPES.contains(&mime_type) {
        return Err(AppError::BadRequest(format!(
            "Unsupported file type: {mime_type}. Allowed: JPEG, PNG, WEBP"
        )));
    }

    if file_size > MAX_FILE_SIZE {
        return Err(AppError::BadRequest(format!(
            "File too large: {} bytes. Maximum: {} bytes (10MB)",
            file_size, MAX_FILE_SIZE
        )));
    }

    Ok(())
}

/// Get file extension from MIME type
pub fn mime_to_extension(mime_type: &str) -> &str {
    match mime_type {
        "image/jpeg" => "jpg",
        "image/png" => "png",
        "image/webp" => "webp",
        _ => "bin",
    }
}

/// Upload file to S3/MinIO
pub async fn upload_file(
    client: &aws_sdk_s3::Client,
    bucket: &str,
    file_key: &str,
    data: Vec<u8>,
    content_type: &str,
) -> Result<(), AppError> {
    client
        .put_object()
        .bucket(bucket)
        .key(file_key)
        .body(ByteStream::from(data))
        .content_type(content_type)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to upload to S3: {e}")))?;

    Ok(())
}

/// Generate a presigned URL for accessing a file
pub async fn get_signed_url(
    client: &aws_sdk_s3::Client,
    bucket: &str,
    file_key: &str,
) -> Result<String, AppError> {
    let presigning = PresigningConfig::expires_in(Duration::from_secs(SIGNED_URL_EXPIRY_SECS))
        .map_err(|e| AppError::Internal(format!("Failed to create presigning config: {e}")))?;

    let url = client
        .get_object()
        .bucket(bucket)
        .key(file_key)
        .presigned(presigning)
        .await
        .map_err(|e| AppError::Internal(format!("Failed to generate signed URL: {e}")))?;

    Ok(url.uri().to_string())
}

/// Delete file from S3/MinIO
pub async fn delete_file(
    client: &aws_sdk_s3::Client,
    bucket: &str,
    file_key: &str,
) -> Result<(), AppError> {
    client
        .delete_object()
        .bucket(bucket)
        .key(file_key)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to delete from S3: {e}")))?;

    Ok(())
}
