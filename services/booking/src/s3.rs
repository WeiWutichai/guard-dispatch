use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::primitives::ByteStream;
use std::time::Duration;

use shared::error::AppError;

const SIGNED_URL_EXPIRY_SECS: u64 = 3600; // 1 hour per CLAUDE.md
const MAX_IMAGE_SIZE: usize = 10 * 1024 * 1024; // 10MB for images
                                                // Bumped 2026-04-25 from 50MB to 200MB. 1080p phone video at ~3 Mbps fits
                                                // roughly 60s in 200MB; below that the cap was rejecting normal job photos
                                                // recorded at 1080p the moment the guard panned around the site.
                                                // nginx `/booking/assignments/` limit raised in lockstep (205m) so requests
                                                // reach the app before being short-circuited by the proxy.
const MAX_VIDEO_SIZE: usize = 200 * 1024 * 1024;

/// Allowed MIME types: images (JPEG, PNG, WEBP) + videos (MP4, QuickTime)
const ALLOWED_MIME_TYPES: &[&str] = &[
    "image/jpeg",
    "image/png",
    "image/webp",
    "video/mp4",
    "video/quicktime",
];

/// Detect actual file type from magic bytes, ignoring the client-declared MIME type.
/// Public so handlers can use magic-byte detection to override unreliable declared MIME.
pub fn detect_mime(data: &[u8]) -> Option<String> {
    detect_mime_from_bytes(data).map(|s| s.to_string())
}

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
    // MP4/MOV: bytes 4-7 = "ftyp" (ISO base media file format)
    if data.len() >= 8 && &data[4..8] == b"ftyp" {
        if data.len() >= 12 {
            let brand = &data[8..12];
            if brand == b"qt  " {
                return Some("video/quicktime");
            }
        }
        return Some("video/mp4");
    }
    None
}

/// Check if MIME type is a video type
pub fn is_video_mime(mime_type: &str) -> bool {
    mime_type.starts_with("video/")
}

/// Validate file upload constraints.
/// Checks both the declared MIME type and actual file magic bytes.
pub fn validate_upload(mime_type: &str, file_size: usize, data: &[u8]) -> Result<(), AppError> {
    if !ALLOWED_MIME_TYPES.contains(&mime_type) {
        return Err(AppError::BadRequest(format!(
            "Unsupported file type: {mime_type}. Allowed: JPEG, PNG, WEBP, MP4, MOV"
        )));
    }

    // Size check before magic bytes (prevent large allocation before reject)
    let max_size = if is_video_mime(mime_type) {
        MAX_VIDEO_SIZE
    } else {
        MAX_IMAGE_SIZE
    };
    if file_size > max_size {
        return Err(AppError::BadRequest(format!(
            "File too large: {} bytes. Maximum: {} bytes ({})",
            file_size,
            max_size,
            if is_video_mime(mime_type) {
                "50MB"
            } else {
                "10MB"
            }
        )));
    }

    // Verify actual file content matches the declared MIME type
    let detected = detect_mime_from_bytes(data).ok_or_else(|| {
        AppError::BadRequest(
            "File content does not match any allowed format (image or video)".to_string(),
        )
    })?;

    // For video: allow mp4/quicktime interchangeably since container format is the same
    let is_match = detected == mime_type || (is_video_mime(detected) && is_video_mime(mime_type));

    if !is_match {
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
        "video/mp4" => "mp4",
        "video/quicktime" => "mov",
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
