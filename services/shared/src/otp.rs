use crate::error::AppError;

/// OTP configuration loaded from environment.
#[derive(Debug, Clone)]
pub struct OtpConfig {
    pub expiry_minutes: i64,
    pub max_attempts: i32,
    pub length: usize,
    pub rate_limit_seconds: u64,
    /// TTL for phone_verified_token (separate from OTP expiry to give users
    /// more time to fill the registration form). Default: 10 minutes.
    pub phone_verify_ttl_minutes: i64,
    /// Maximum OTP requests per phone per 24-hour window. Default: 10.
    pub daily_otp_limit: u32,
}

impl OtpConfig {
    pub fn from_env() -> Result<Self, AppError> {
        Ok(Self {
            expiry_minutes: std::env::var("OTP_EXPIRY_MINUTES")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(5),
            max_attempts: std::env::var("OTP_MAX_ATTEMPTS")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(3),
            length: std::env::var("OTP_LENGTH")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(6),
            rate_limit_seconds: std::env::var("OTP_RATE_LIMIT_SECONDS")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(60),
            phone_verify_ttl_minutes: std::env::var("PHONE_VERIFY_TTL_MINUTES")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(10),
            daily_otp_limit: std::env::var("DAILY_OTP_LIMIT")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(10),
        })
    }
}

/// Generate a random numeric OTP code of the given length.
/// Uses `rand::thread_rng()` for cryptographically sufficient randomness.
pub fn generate_otp(length: usize) -> String {
    use rand::Rng;
    let mut rng = rand::thread_rng();
    (0..length)
        .map(|_| rng.gen_range(0..10).to_string())
        .collect()
}

/// Format the OTP message in Thai for SMS delivery.
///
/// Kept short (≤ 40 chars) so the hex-encoded UCS-2 text fits in a single
/// SMS segment (160 hex chars) = 1 credit. Brand name shows as sender ID.
pub fn format_otp_message(code: &str, expiry_minutes: i64) -> String {
    format!("รหัส OTP: {code} หมดอายุใน {expiry_minutes} นาที")
}

/// Validate Thai phone number format: 10 digits starting with 0.
/// Strips non-digit characters before validation.
pub fn validate_thai_phone(phone: &str) -> Result<String, AppError> {
    let digits: String = phone.chars().filter(|c| c.is_ascii_digit()).collect();
    if digits.len() != 10 || !digits.starts_with('0') {
        return Err(AppError::BadRequest(
            "Invalid phone format — must be 10 digits starting with 0".to_string(),
        ));
    }
    Ok(digits)
}

/// Convert Thai local phone (0812345678) to international format (66812345678)
/// for the INET SMS API which accepts both formats.
pub fn to_international_format(phone: &str) -> String {
    let digits: String = phone.chars().filter(|c| c.is_ascii_digit()).collect();
    if let Some(stripped) = digits.strip_prefix('0') {
        format!("66{stripped}")
    } else {
        digits
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_otp_correct_length() {
        let code = generate_otp(6);
        assert_eq!(code.len(), 6);
    }

    #[test]
    fn generate_otp_only_digits() {
        let code = generate_otp(6);
        assert!(code.chars().all(|c| c.is_ascii_digit()));
    }

    #[test]
    fn generate_otp_different_each_time() {
        // Very unlikely to generate same 6-digit code twice in a row
        let codes: Vec<String> = (0..10).map(|_| generate_otp(6)).collect();
        let unique: std::collections::HashSet<&String> = codes.iter().collect();
        assert!(unique.len() > 1, "OTP codes should be random");
    }

    #[test]
    fn format_otp_message_contains_code() {
        let msg = format_otp_message("123456", 5);
        assert!(msg.contains("123456"));
        assert!(msg.contains("5 นาที"));
    }

    #[test]
    fn format_otp_message_fits_single_sms_segment() {
        let msg = format_otp_message("123456", 5);
        let char_count = msg.chars().count();
        // Must be ≤ 40 chars so hex-encoded UCS-2 (×4) ≤ 160 = 1 SMS segment
        assert!(
            char_count <= 40,
            "OTP message too long: {char_count} chars (max 40 for 1 credit)"
        );
    }

    #[test]
    fn validate_thai_phone_valid() {
        assert_eq!(validate_thai_phone("0812345678").unwrap(), "0812345678");
    }

    #[test]
    fn validate_thai_phone_with_dashes() {
        assert_eq!(validate_thai_phone("081-234-5678").unwrap(), "0812345678");
    }

    #[test]
    fn validate_thai_phone_with_spaces() {
        assert_eq!(validate_thai_phone("081 234 5678").unwrap(), "0812345678");
    }

    #[test]
    fn validate_thai_phone_too_short() {
        assert!(validate_thai_phone("081234567").is_err());
    }

    #[test]
    fn validate_thai_phone_not_starting_with_zero() {
        assert!(validate_thai_phone("1812345678").is_err());
    }

    #[test]
    fn to_international_format_converts() {
        assert_eq!(to_international_format("0812345678"), "66812345678");
    }

    #[test]
    fn to_international_format_already_international() {
        assert_eq!(to_international_format("66812345678"), "66812345678");
    }
}
