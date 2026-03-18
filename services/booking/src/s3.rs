use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::primitives::ByteStream;
use std::time::Duration;

use shared::error::AppError;

const SIGNED_URL_EXPIRY_SECS: u64 = 3600; // 1 hour per CLAUDE.md
const MAX_IMAGE_SIZE: usize = 10 * 1024 * 1024; // 10MB for images

/// Allowed MIME types: images only (JPEG, PNG, WEBP)
const ALLOWED_MIME_TYPES: &[&str] = &["image/jpeg", "image/png", "image/webp"];

/// Detect actual file type from magic bytes, ignoring the client-declared MIME type.
fn detect_mime_from_bytes(data: &[u8]) -> Option<&'static str> {
    if data.len() >= 3 && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF {
        return Some("image/jpeg");
    }
    if data.len() >= 8 && &data[..8] == b"\x89PNG\r\n\x1a\n" {
        return Some("image/png");
    }
    if data.len() >= 12 && &data[..4] == b"RIFF" && &data[8..12] == b"WEBP" {
        return Some("image/webp");
    }
    None
}

/// Validate file upload constraints.
/// Checks both the declared MIME type and actual file magic bytes.
pub fn validate_upload(mime_type: &str, file_size: usize, data: &[u8]) -> Result<(), AppError> {
    if !ALLOWED_MIME_TYPES.contains(&mime_type) {
        return Err(AppError::BadRequest(format!(
            "Unsupported file type: {mime_type}. Allowed: JPEG, PNG, WEBP"
        )));
    }

    // Size check before magic bytes (prevent large allocation before reject)
    if file_size > MAX_IMAGE_SIZE {
        return Err(AppError::BadRequest(format!(
            "File too large: {} bytes. Maximum: {} bytes (10MB)",
            file_size, MAX_IMAGE_SIZE
        )));
    }

    // Verify actual file content matches the declared MIME type
    let detected = detect_mime_from_bytes(data).ok_or_else(|| {
        AppError::BadRequest(
            "File content does not match any allowed format (JPEG, PNG, WEBP)".to_string(),
        )
    })?;

    if detected != mime_type {
        return Err(AppError::BadRequest(format!(
            "MIME type mismatch: declared {mime_type} but file content is {detected}"
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
