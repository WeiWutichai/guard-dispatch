# PinLoginScreen — Brute-force gap (rate limiting)

**Status:** Open — out of scope for `fix/pin-rate-limiting` PR
**Severity:** 🟠 High
**First flagged:** Phase 3 review of PIN rate limiting (commit `98f4ed3`)
**Related PR:** `fix/pin-rate-limiting` (commits `a1a70ef` + `98f4ed3` + `333a70f` + `2ed4f0b`)
**Owner:** _TBD_

---

## Summary

`PinLoginScreen` ไม่อยู่ภายใต้ rate limiting/wipe protection ที่เพิ่งเพิ่มเข้ามาใน `PinLockScreen` — attacker ที่เข้าถึง physical device + เข้าถึงหน้า `PinLoginScreen` ได้ สามารถ brute-force 6-digit PIN โดยถูกจำกัดด้วย **Nginx rate limit (5 req/s)** อย่างเดียว = **~55 ชั่วโมงสำหรับ PIN space เต็ม 10⁶**

---

## Context — ทำไม PinLoginScreen ถึงไม่ผ่าน PinStorageService.validatePin

`PinLoginScreen` มีจุดประสงค์แยกจาก `PinLockScreen`:

| Screen | ใช้ตอนไหน | Validation path |
|---|---|---|
| **`PinLockScreen`** | เปิดแอปหลังครั้งแรก (มี `pin_hash` เก็บอยู่) | Local SHA-256 compare ผ่าน `PinStorageService.validatePin` |
| **`PinLoginScreen`** | returning approved user **หลัง tokens ถูก clear** (e.g. logout หรือ refresh fail permanent) | **Backend login** ผ่าน `loginWithPhone(phone, hashPin(pin))` → `POST /auth/login/mobile` |

เข้า `PinLoginScreen` ผ่านเส้นทางเดียว: `PinSetupScreen._finishSetup()` fallback ที่ commit [`3bf396a`](../../frontend/mobile/lib/screens/pin_setup_screen.dart#L173-L186):

```dart
// เมื่อ registerWithOtp() คืน 409 "log in instead":
try {
  await loginWithPhone(widget.phone!, pinHash);
  // success → RoleSelectionScreen
} catch (_) {
  // PIN ไม่ตรง → fall through ไป PinLoginScreen
  Navigator.pushAndRemoveUntil(
    ...MaterialPageRoute(builder: (_) => PinLoginScreen(phone: widget.phone!))...
  );
}
```

หลังเข้า `PinLoginScreen` แล้ว ทุก attempt คือการเรียก backend ตรง — `PinStorageService.validatePin` ไม่ได้ถูกเรียกเลย เพราะ **local `pin_hash` ไม่มี** ในเครื่องที่ tokens เพิ่งถูก clear (fresh install / restore / post-logout scenario)

---

## Attack vector

**Pre-conditions:**
- Attacker มี physical access ต่อ unlocked device **หรือ** device ที่ไม่มี screen lock OS-level
- User บัญชีเป้าหมาย approved แล้ว (มี row ใน `auth.users`, status `approved`)
- Attacker รู้เบอร์โทรของเป้าหมาย
- Attacker trigger ให้แอปเข้า `PinLoginScreen` state (เช่น clear app data ไม่ได้ เพราะ FlutterSecureStorage จะหาย — ต้อง engineer flow)

**วิธี trigger PinLoginScreen state:**
1. Clear app tokens อย่างเดียว (FlutterSecureStorage `access_token` + `refresh_token` keys) — ยังเก็บ `pin_hash` ไว้
2. เปิดแอป → `checkAuthStatus` เจอ no token → ไป check-status + loginWithPhone — ถ้า wrong PIN ไม่ route ไป `PinLoginScreen` ตรง ต้องผ่าน `PinSetupScreen` fallback
3. หรือ: fresh install (ไม่มี `pin_hash` local) → OTP request → verify → `PinSetupScreen` → register 409 "log in instead" → `PinLoginScreen`

**Attack:** ใน `PinLoginScreen` loop ใส่ PIN 000000 → 000001 → ... → 999999 โดย automation (accessibility service / ADB input / HID injection)

**Rate limit budget:**
- Backend Nginx `auth_limit`: **5 req/s per IP**
- Argon2 verify (backend CPU cost): ~50 ms/attempt (ไม่ใช่ rate limit จริงๆ แต่ปลายทาง)
- Effective attempts/sec: 5 (limited by Nginx)
- Full PIN space: 10⁶ attempts ÷ 5/s = **200,000 sec ≈ 55.5 ชั่วโมง**
- Average time to hit: **~28 ชั่วโมง**

**Attacker ขยายขอบเขต:** ถ้ามี bot network + rotate IPs (per-IP Nginx limit) → สามารถลดเวลาลงถึงระดับนาที

**Additional exposure:** PinLoginScreen ไม่มี client-side counter — restart app ไม่ reset counter ของ backend (เพราะ backend ไม่ track per-account), ไม่มี lockout UI

---

## Impact

| Dimension | Assessment |
|---|---|
| Confidentiality | ⚠️ HIGH — หาก PIN cracked, attacker ได้ `loginWithPhone` success → access_token valid → เข้าถึง jobs, customer addresses, bank accounts ของ victim ได้ |
| Integrity | ⚠️ MEDIUM — attacker สามารถ accept/decline assignments, modify profile |
| Availability | 🟢 LOW — ไม่มี direct DoS |
| Blast radius | ⚠️ per-account (single victim per attack run) |
| Exploitability | MEDIUM — ต้อง physical access + automation setup |

**Why not Critical:** Physical access + multi-hour attack window + detectable ใน backend logs

---

## Mitigation options

### Option A: Backend per-phone login attempt counter (recommended)

- Add Redis-based rate limiter: `login_attempts:{phone}` — INCR on failed `/auth/login/mobile`, reset on success
- Threshold: 5 failures → 60s lockout, 10 failures → 30-min lockout + email/SMS alert to user
- Response: on lockout, return HTTP 429 with `Retry-After` header
- **Pros:** Works regardless of client (web, mobile, curl). Can correlate attempts across IPs
- **Cons:** Backend change required (service + Redis key management + migration)

**Effort:** ~4 ชม. implementation + tests

### Option B: Client-side local rate limiter ใน PinLoginScreen

- Reuse `PinStorageService` infrastructure — แต่ validate ผ่าน backend แทน local hash
- เพิ่ม method `recordLoginAttempt({required bool success})` → เดียวกับ `validatePin` (inflight lock, counter, lockout)
- Storage keys separate: `login_failed_attempts`, `login_lock_until_ms`
- **Pros:** No backend change. Deploys to mobile only. Reuses battle-tested Phase 2 logic
- **Cons:** Attacker bypassable ผ่าน curl ตรง (ไม่ผ่าน app). Only protects average user + reduces UI-driven automation

**Effort:** ~2 ชม. implementation + tests

### Option C: Both (defense-in-depth)

- Backend: Option A (true security guarantee)
- Client: Option B (fast UX feedback, reduce backend load)

**Effort:** ~6 ชม. total

**Recommendation:** Start with **Option A** as the primary fix. Add Option B later if telemetry shows legitimate need for UX improvement (e.g. user complaints about brute force attempts that exhaust backend budget mid-incident)

---

## Acceptance criteria (for future PR)

- [ ] `POST /auth/login/mobile` ต้อง enforce per-phone rate limit (Option A)
- [ ] Redis key `login_attempts:{phone}` with atomic `INCR` + explicit `EXPIRE` after first failure
- [ ] HTTP 429 response on lockout พร้อม `Retry-After` header
- [ ] Integration test: 5 failed logins → 429 → wait → 1 more = success path restored
- [ ] No user enumeration via error message — same generic 401 สำหรับ wrong PIN, non-existent phone, inactive account
- [ ] Test: valid login รีเซ็ต counter
- [ ] Audit log entry for lockout events
- [ ] (Optional) Send notification (FCM + SMS) to user on suspicious activity
- [ ] Update `CLAUDE.md`: Flutter Mobile Known Security Tradeoffs — remove the "PinLoginScreen has NO local rate limiting" bullet
- [ ] Mobile `PinLoginScreen._onSubmit`: handle 429 response → show countdown UI similar to `PinLockScreen` banner

---

## Related code

- `frontend/mobile/lib/screens/pin_login_screen.dart` — current implementation, calls `loginWithPhone` directly
- `frontend/mobile/lib/providers/auth_provider.dart::loginWithPhone` — POST /auth/login/mobile
- `services/auth/src/handlers.rs::login_mobile` — backend handler (no rate limit currently)
- `services/auth/src/service.rs::login_with_phone` — verify_password via Argon2 (slow but ไม่ใช่ rate limit)
- `nginx/nginx.conf` — `limit_req zone=auth_limit` (5 req/s per IP only)
- `CLAUDE.md` Known Security Tradeoffs section (Flutter Mobile) — references this issue

---

## Notes

- This issue was discovered during deep review of PIN rate limiting on `fix/pin-rate-limiting` branch
- Deliberately **out of scope** for that PR to keep the local PIN security fix focused + mergeable
- No known active exploitation — filed preventively
