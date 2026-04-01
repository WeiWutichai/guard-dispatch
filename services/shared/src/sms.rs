use crate::error::AppError;

/// Configuration for INET SMS Gateway (Cheese Digital Network CSGAPI).
///
/// API: POST https://bulksms.cheesemobile.com/v2/
/// Parameters: username, passwd, from, to, text, datacoding, resultmode
#[derive(Debug, Clone)]
pub struct SmsConfig {
    pub username: String,
    pub password: String,
    pub sender: String,
    pub url: String,
}

impl SmsConfig {
    /// Load SMS config from environment variables.
    /// Fails fast if any required variable is missing.
    pub fn from_env() -> Result<Self, AppError> {
        let username = std::env::var("INET_SMS_USERNAME")
            .map_err(|_| AppError::Internal("Missing env var: INET_SMS_USERNAME".to_string()))?;
        let password = std::env::var("INET_SMS_PASSWORD")
            .map_err(|_| AppError::Internal("Missing env var: INET_SMS_PASSWORD".to_string()))?;
        let sender = std::env::var("INET_SMS_SENDER").unwrap_or_else(|_| "GuardApp".to_string());
        let url = std::env::var("INET_SMS_URL")
            .unwrap_or_else(|_| "https://bulksms.cheesemobile.com/v2/".to_string());

        if username.is_empty() {
            return Err(AppError::Internal(
                "INET_SMS_USERNAME must not be empty".to_string(),
            ));
        }
        if password.is_empty() {
            return Err(AppError::Internal(
                "INET_SMS_PASSWORD must not be empty".to_string(),
            ));
        }

        Ok(Self {
            username,
            password,
            sender,
            url,
        })
    }
}

/// INET CSGAPI XML response status codes.
#[derive(Debug)]
pub struct SmsResponse {
    pub status: String,
    pub detail: String,
    pub tran_id: Option<String>,
}

/// Percent-encode raw bytes for a URL query parameter value.
fn url_encode_bytes(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 3);
    for &b in bytes {
        if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.' | b'~') {
            out.push(b as char);
        } else if b == b' ' {
            out.push_str("%20");
        } else {
            use std::fmt::Write;
            let _ = write!(out, "%{b:02X}");
        }
    }
    out
}

/// Encode text for the INET SMS gateway's UCS-2 output.
///
/// The gateway generates UCS-2 SMS (2 bytes per char) but has a quirk:
///   - **High bytes** (≥0x80): treated as TIS-620 → correctly expanded to 2-byte UCS-2
///   - **Low bytes** (<0x80): passed through as-is (1 byte) → causes UCS-2 misalignment
///
/// Fix: Thai chars → TIS-620 single byte (gateway expands to 2-byte UCS-2).
///      ASCII chars → prepend 0x00 so gateway passes both bytes through,
///      forming a correct UCS-2 pair (e.g., "O" → 00 4F → U+004F).
fn text_to_sms_url(text: &str) -> String {
    let mut bytes = Vec::with_capacity(text.len() * 2);
    for ch in text.chars() {
        let cp = ch as u32;
        if cp < 0x80 {
            // ASCII: prepend 0x00 to form correct UCS-2 pair in SMS PDU
            bytes.push(0x00);
            bytes.push(cp as u8);
        } else if (0x0E01..=0x0E3A).contains(&cp) || cp == 0x0E3F || (0x0E40..=0x0E5B).contains(&cp)
        {
            // Thai: TIS-620 single byte (gateway correctly expands to 2-byte UCS-2)
            bytes.push((cp - 0x0D60) as u8);
        } else {
            bytes.push(0x00);
            bytes.push(b'?');
        }
    }
    url_encode_bytes(&bytes)
}

/// Send an SMS via the INET CSGAPI gateway.
///
/// Thai text is encoded as **TIS-620** bytes (single-byte Thai encoding) with
/// `datacoding=U`. The gateway always reads the `text` bytes as TIS-620, so we
/// must encode Thai chars as TIS-620. Using `datacoding=U` ensures the gateway
/// generates a proper **UCS-2 SMS PDU** (2 bytes per char for ALL characters
/// including ASCII), which all phones decode correctly.
///
/// The URL is built manually because reqwest's `.query()` sends UTF-8 bytes,
/// which the gateway misinterprets as TIS-620 (producing garbled output).
///
/// The `client` should be a shared `reqwest::Client` (stored in AppState) to reuse
/// TCP connections and avoid per-request overhead.
///
/// Returns the transaction ID on success, or an `AppError` on failure.
pub async fn send_sms(
    config: &SmsConfig,
    client: &reqwest::Client,
    to: &str,
    text: &str,
) -> Result<String, AppError> {
    // Build URL manually — text encoded as TIS-620, other params are ASCII-safe
    let url = format!(
        "{}?username={}&passwd={}&from={}&to={}&text={}&datacoding=U&resultmode=xml",
        config.url,
        url_encode_bytes(config.username.as_bytes()),
        url_encode_bytes(config.password.as_bytes()),
        url_encode_bytes(config.sender.as_bytes()),
        url_encode_bytes(to.as_bytes()),
        text_to_sms_url(text),
    );

    let response = client
        .get(&url)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("SMS gateway request failed: {e}")))?;

    let status_code = response.status();
    let body = response
        .text()
        .await
        .map_err(|e| AppError::Internal(format!("Failed to read SMS gateway response: {e}")))?;

    if !status_code.is_success() {
        tracing::error!("SMS gateway HTTP error: status={status_code}, body={body}");
        return Err(AppError::Internal(
            "SMS gateway returned an error".to_string(),
        ));
    }

    // Parse XML response: <xml><response><status>00</status><detail>Accepted</detail><tranid>...</tranid></response>...</xml>
    let parsed = parse_inet_xml_response(&body)?;

    if parsed.status == "00" {
        let tran_id = parsed.tran_id.unwrap_or_default();
        tracing::info!("SMS sent successfully: tran_id={tran_id}");
        Ok(tran_id)
    } else {
        let error_desc = inet_error_description(&parsed.status);
        tracing::error!(
            "SMS gateway error: code={}, detail={}, desc={}",
            parsed.status,
            parsed.detail,
            error_desc
        );
        Err(AppError::Internal(format!(
            "SMS send failed: {} ({})",
            parsed.detail, error_desc
        )))
    }
}

/// Parse INET CSGAPI XML response (simple tag extraction — no XML crate needed).
fn parse_inet_xml_response(xml: &str) -> Result<SmsResponse, AppError> {
    let status = extract_xml_tag(xml, "status").unwrap_or_default();
    let detail = extract_xml_tag(xml, "detail").unwrap_or_default();
    let tran_id = extract_xml_tag(xml, "tranid");

    Ok(SmsResponse {
        status,
        detail,
        tran_id,
    })
}

/// Extract text content from a simple XML tag: `<tag>content</tag>`
fn extract_xml_tag(xml: &str, tag: &str) -> Option<String> {
    let open = format!("<{tag}>");
    let close = format!("</{tag}>");
    let start = xml.find(&open)? + open.len();
    let end = xml[start..].find(&close)? + start;
    Some(xml[start..end].to_string())
}

/// Map INET error codes to descriptions.
fn inet_error_description(code: &str) -> &'static str {
    match code {
        "00" => "Accepted",
        "01" => "No Such User",
        "02" => "Password is wrong",
        "03" => "No parameters list found",
        "04" => "Method is wrong",
        "05" => "Internal Server Error",
        "06" => "Phone Number is wrong",
        "07" => "SMS parameter missing",
        "08" => "Insufficient SMS Credits",
        "09" => "User is expire",
        "10" => "Transaction ID invalid",
        "11" => "Text length overflow",
        "12" => "DateTime is wrong",
        "13" => "User is disable",
        "14" => "Invalid SenderName",
        "15" => "Text not match Datacoding",
        "16" => "Invalid Datacoding",
        "17" => "Text is empty",
        "18" => "Parameter is empty",
        "19" => "URL invalid format",
        "20" => "Wappush name invalid format",
        "99" => "Permission denied",
        _ => "Unknown error",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_xml_success_response() {
        let xml = r#"<?xml version="1.0" encoding="UTF8"?><xml><response><status>00</status><detail>Accepted</detail><tranid>CM.108.1350356789.51730500</tranid></response><data/></xml>"#;
        let result = parse_inet_xml_response(xml).unwrap();
        assert_eq!(result.status, "00");
        assert_eq!(result.detail, "Accepted");
        assert_eq!(
            result.tran_id,
            Some("CM.108.1350356789.51730500".to_string())
        );
    }

    #[test]
    fn parse_xml_error_response() {
        let xml = r#"<?xml version="1.0"?><xml><response><status>06</status><detail>Phone Number is wrong</detail></response></xml>"#;
        let result = parse_inet_xml_response(xml).unwrap();
        assert_eq!(result.status, "06");
        assert_eq!(result.detail, "Phone Number is wrong");
        assert!(result.tran_id.is_none());
    }

    #[test]
    fn extract_xml_tag_finds_content() {
        let xml = "<root><name>hello</name></root>";
        assert_eq!(extract_xml_tag(xml, "name"), Some("hello".to_string()));
    }

    #[test]
    fn extract_xml_tag_returns_none_for_missing() {
        let xml = "<root><name>hello</name></root>";
        assert_eq!(extract_xml_tag(xml, "missing"), None);
    }

    #[test]
    fn text_to_sms_url_thai_chars() {
        // Thai-only: ร=0xC3, ห=0xCB, ั=0xD1, ส=0xCA (TIS-620, no 0x00 prefix)
        assert_eq!(text_to_sms_url("รหัส"), "%C3%CB%D1%CA");
    }

    #[test]
    fn text_to_sms_url_ascii() {
        // ASCII: each char gets 0x00 prefix → %00 + char
        assert_eq!(text_to_sms_url("O"), "%00O");
        assert_eq!(text_to_sms_url("OTP"), "%00O%00T%00P");
        assert_eq!(text_to_sms_url("123"), "%001%002%003");
    }

    #[test]
    fn text_to_sms_url_mixed() {
        // "OTP: 123" → %00O %00T %00P %00%3A %00%20 %001 %002 %003
        let encoded = text_to_sms_url("OTP: 123");
        assert!(encoded.starts_with("%00O%00T%00P"));
        assert!(encoded.contains("%001%002%003"));
    }

    #[test]
    fn text_to_sms_url_full_otp_message() {
        let msg = "รหัส OTP: 123456 หมดอายุใน 5 นาที";
        let encoded = text_to_sms_url(msg);
        // Starts with TIS-620 encoded "รหัส" (no 0x00 prefix for Thai)
        assert!(encoded.starts_with("%C3%CB%D1%CA"));
        // ASCII parts get 0x00 prefix
        assert!(encoded.contains("%00O%00T%00P"));
        assert!(encoded.contains("%001%002%003%004%005%006"));
    }

    #[test]
    fn inet_error_codes_mapped() {
        assert_eq!(inet_error_description("00"), "Accepted");
        assert_eq!(inet_error_description("06"), "Phone Number is wrong");
        assert_eq!(inet_error_description("08"), "Insufficient SMS Credits");
        assert_eq!(inet_error_description("99"), "Permission denied");
        assert_eq!(inet_error_description("ZZ"), "Unknown error");
    }
}
