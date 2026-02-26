use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::primitives::ByteStream;
use std::time::Duration;

use shared::error::AppError;

const SIGNED_URL_EXPIRY_SECS: u64 = 3600; // 1 hour per CLAUDE.md
const MAX_FILE_SIZE: usize = 10 * 1024 * 1024; // 10MB per CLAUDE.md

/// Allowed MIME types (per CLAUDE.md: JPEG, PNG, WEBP only)
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

    if file_size > MAX_FILE_SIZE {
        return Err(AppError::BadRequest(format!(
            "File too large: {} bytes. Maximum: {} bytes (10MB)",
            file_size, MAX_FILE_SIZE
        )));
    }

    // Verify actual file content matches the declared MIME type
    let detected = detect_mime_from_bytes(data).ok_or_else(|| {
        AppError::BadRequest("File content does not match any allowed image format".to_string())
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

#[cfg(test)]
mod tests {
    use super::*;

    // Minimal valid file headers for testing
    const JPEG_HEADER: &[u8] = &[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
    const PNG_HEADER: &[u8] = &[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    const WEBP_HEADER: &[u8] = b"RIFF\x00\x00\x00\x00WEBP";
    const GIF_HEADER: &[u8] = b"GIF89a";

    // =========================================================================
    // detect_mime_from_bytes
    // =========================================================================

    #[test]
    fn detect_jpeg_magic_bytes() {
        assert_eq!(detect_mime_from_bytes(JPEG_HEADER), Some("image/jpeg"));
    }

    #[test]
    fn detect_png_magic_bytes() {
        assert_eq!(detect_mime_from_bytes(PNG_HEADER), Some("image/png"));
    }

    #[test]
    fn detect_webp_magic_bytes() {
        assert_eq!(detect_mime_from_bytes(WEBP_HEADER), Some("image/webp"));
    }

    #[test]
    fn detect_returns_none_for_unknown() {
        assert_eq!(detect_mime_from_bytes(GIF_HEADER), None);
        assert_eq!(detect_mime_from_bytes(b""), None);
        assert_eq!(detect_mime_from_bytes(b"\x00\x00"), None);
    }

    // =========================================================================
    // validate_upload — MIME type validation
    // =========================================================================

    #[test]
    fn validate_upload_accepts_jpeg() {
        assert!(validate_upload("image/jpeg", JPEG_HEADER.len(), JPEG_HEADER).is_ok());
    }

    #[test]
    fn validate_upload_accepts_png() {
        assert!(validate_upload("image/png", PNG_HEADER.len(), PNG_HEADER).is_ok());
    }

    #[test]
    fn validate_upload_accepts_webp() {
        assert!(validate_upload("image/webp", WEBP_HEADER.len(), WEBP_HEADER).is_ok());
    }

    #[test]
    fn validate_upload_rejects_gif() {
        let result = validate_upload("image/gif", GIF_HEADER.len(), GIF_HEADER);
        assert!(result.is_err());
    }

    #[test]
    fn validate_upload_rejects_pdf() {
        let result = validate_upload("application/pdf", 1024, b"%PDF-1.4");
        assert!(result.is_err());
    }

    #[test]
    fn validate_upload_rejects_svg() {
        let result = validate_upload("image/svg+xml", 5, b"<svg>");
        assert!(result.is_err());
    }

    #[test]
    fn validate_upload_rejects_text() {
        let result = validate_upload("text/plain", 5, b"hello");
        assert!(result.is_err());
    }

    #[test]
    fn validate_upload_rejects_empty_mime() {
        let result = validate_upload("", 3, b"\x00\x00\x00");
        assert!(result.is_err());
    }

    #[test]
    fn validate_upload_rejects_mime_mismatch() {
        // Declares JPEG but sends PNG bytes
        let result = validate_upload("image/jpeg", PNG_HEADER.len(), PNG_HEADER);
        assert!(result.is_err());
    }

    #[test]
    fn validate_upload_rejects_spoofed_mime_with_wrong_bytes() {
        // Declares PNG but file is actually random garbage
        let result = validate_upload("image/png", 10, b"notanimage");
        assert!(result.is_err());
    }

    // =========================================================================
    // validate_upload — file size validation
    // =========================================================================

    #[test]
    fn validate_upload_rejects_over_10mb() {
        let over_10mb = 10 * 1024 * 1024 + 1;
        // Size check happens before magic byte check
        let result = validate_upload("image/jpeg", over_10mb, JPEG_HEADER);
        assert!(result.is_err());
    }

    // =========================================================================
    // mime_to_extension
    // =========================================================================

    #[test]
    fn mime_to_extension_jpeg() {
        assert_eq!(mime_to_extension("image/jpeg"), "jpg");
    }

    #[test]
    fn mime_to_extension_png() {
        assert_eq!(mime_to_extension("image/png"), "png");
    }

    #[test]
    fn mime_to_extension_webp() {
        assert_eq!(mime_to_extension("image/webp"), "webp");
    }

    #[test]
    fn mime_to_extension_unknown_returns_bin() {
        assert_eq!(mime_to_extension("application/pdf"), "bin");
        assert_eq!(mime_to_extension(""), "bin");
    }

    // =========================================================================
    // Constants validation (per CLAUDE.md)
    // =========================================================================

    #[test]
    fn signed_url_expires_in_one_hour() {
        assert_eq!(SIGNED_URL_EXPIRY_SECS, 3600);
    }

    #[test]
    fn max_file_size_is_10mb() {
        assert_eq!(MAX_FILE_SIZE, 10 * 1024 * 1024);
    }

    #[test]
    fn only_three_mime_types_allowed() {
        assert_eq!(ALLOWED_MIME_TYPES.len(), 3);
        assert!(ALLOWED_MIME_TYPES.contains(&"image/jpeg"));
        assert!(ALLOWED_MIME_TYPES.contains(&"image/png"));
        assert!(ALLOWED_MIME_TYPES.contains(&"image/webp"));
    }
}
