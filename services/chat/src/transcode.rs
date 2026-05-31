use std::path::PathBuf;
use std::time::Duration;
use tokio::process::Command;
use uuid::Uuid;

use shared::error::AppError;

const TRANSCODE_TIMEOUT_SECS: u64 = 120;

/// RAII guard: unlinks the temp file on drop (success, error, timeout, panic).
/// Drop is sync, so it uses blocking `std::fs` — a single unlink syscall, negligible.
struct TempFile {
    path: PathBuf,
}

impl TempFile {
    fn new(suffix: &str) -> Self {
        let mut path = std::env::temp_dir();
        path.push(format!("chatvid-{}-{suffix}", Uuid::new_v4()));
        TempFile { path }
    }
}

impl Drop for TempFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path); // best-effort
    }
}

/// Transcode an uploaded chat video to <=720p H.264 (main profile, yuv420p) + faststart.
///
/// Phone cameras record 4K H.264 High-profile clips that the target devices'
/// decoders / ExoPlayer cannot play (the confirmed root cause — 3840x2160 failed
/// on every device while a 720x480 clip played). Downscaling to <=720p main/yuv420p
/// with the moov atom at the front produces a universally playable stream.
///
/// ALWAYS returns mp4 bytes. FAILS (never falls back to the original) on any error —
/// storing the unplayable 4K would just reproduce the bug.
pub async fn transcode_video_to_720p_mp4(input: &[u8]) -> Result<Vec<u8>, AppError> {
    let in_file = TempFile::new("in");
    let out_file = TempFile::new("out.mp4");

    tokio::fs::write(&in_file.path, input)
        .await
        .map_err(|e| AppError::Internal(format!("transcode: write temp input failed: {e}")))?;

    let mut cmd = Command::new("ffmpeg");
    cmd.kill_on_drop(true)
        .arg("-nostdin")
        .arg("-y")
        .arg("-hide_banner")
        .arg("-loglevel")
        .arg("error")
        .arg("-i")
        .arg(&in_file.path)
        // First video stream + first audio stream IF present (trailing `?`).
        .arg("-map")
        .arg("0:v:0")
        .arg("-map")
        .arg("0:a:0?")
        .arg("-c:v")
        .arg("libx264")
        .arg("-profile:v")
        .arg("main")
        .arg("-pix_fmt")
        .arg("yuv420p")
        // Fit inside 1280x720 (downscale only — never upscale), then force even
        // dimensions (H.264/yuv420p requires even W/H). 720x480 stays untouched;
        // 3840x2160 -> 1280x720.
        .arg("-vf")
        .arg("scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2")
        .arg("-preset")
        .arg("veryfast")
        .arg("-crf")
        .arg("26")
        .arg("-maxrate")
        .arg("2500k")
        .arg("-bufsize")
        .arg("5000k")
        .arg("-c:a")
        .arg("aac")
        .arg("-b:a")
        .arg("128k")
        .arg("-ac")
        .arg("2")
        .arg("-movflags")
        .arg("+faststart")
        .arg("-max_muxing_queue_size")
        .arg("1024")
        .arg("-threads")
        .arg("0")
        .arg("-f")
        .arg("mp4")
        .arg(&out_file.path)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped());

    let child = cmd.spawn().map_err(|e| {
        AppError::Internal(format!("transcode: ffmpeg spawn failed (ffmpeg installed?): {e}"))
    })?;

    // The Child lives INSIDE this future; on timeout the future is dropped here,
    // which (via kill_on_drop) reaps the ffmpeg process. Do NOT hoist `child`
    // into an outer binding that outlives the timeout, or the OS process leaks.
    let output = match tokio::time::timeout(
        Duration::from_secs(TRANSCODE_TIMEOUT_SECS),
        child.wait_with_output(),
    )
    .await
    {
        Err(_elapsed) => {
            return Err(AppError::Internal("transcode: ffmpeg timed out".into()));
        }
        Ok(Err(e)) => {
            return Err(AppError::Internal(format!("transcode: ffmpeg io error: {e}")));
        }
        Ok(Ok(out)) => out,
    };

    if !output.status.success() {
        // Log stderr ONLY on failure (ffmpeg writes verbose progress to stderr
        // on success too).
        let stderr = String::from_utf8_lossy(&output.stderr);
        tracing::error!(status = ?output.status, %stderr, "ffmpeg transcode failed");
        // Bad/undecodable input -> 4xx so Dio treats it as non-retryable and
        // doesn't re-upload the same doomed clip in a loop.
        return Err(AppError::BadRequest(
            "Unable to process video. Please try a different file.".into(),
        ));
    }

    let bytes = tokio::fs::read(&out_file.path)
        .await
        .map_err(|e| AppError::Internal(format!("transcode: read temp output failed: {e}")))?;

    if bytes.is_empty() {
        return Err(AppError::Internal("transcode: ffmpeg produced empty output".into()));
    }

    // in_file / out_file drop here -> both temp files unlinked.
    Ok(bytes)
}
