# PIN Rate Limiting + Wipe Protection

Implements **C1 Critical finding** from the biometric auth deep review: 6-digit PIN on `PinLockScreen` had no rate limiting → brute-force feasible via UI automation (~83 hours average) against stolen devices with unlocked screen.

**Branch:** `fix/pin-rate-limiting`
**Stack:** 4 commits (Phase 2 service → Phase 3 UI → Phase 4 banner fix → docs)

---

## Summary

- **Lockout after 5 wrong attempts** (60s), **wipe after 10** — counter persists in FlutterSecureStorage across app restarts
- New `PinResult` sealed type (`PinValid | PinInvalid | PinLockedOut | PinWiped`) replaces `bool` return from `validatePin`
- `PinLockScreen` gains countdown timer, disabled keypad during lockout, wipe warning when ≥7 attempts
- On wipe: modal dialog → `auth.logout()` (server-side session revoke) → `PhoneInputScreen` (clear stack) → user must re-OTP
- Biometric disabled during PIN lockout (prevent bypass)

**Before:** Attacker with physical access could try all 10⁶ PINs limited only by 600ms UI delay
**After:** Hard cap at 10 attempts per PIN lifetime, then mandatory re-OTP (OTP is backend rate-limited 3/min)

---

## Commits

| SHA | Message |
|---|---|
| `a1a70ef` | `feat(mobile): PIN rate limiting + wipe (Phase 2 — service + tests)` |
| `98f4ed3` | `feat(mobile): PIN rate limiting UI integration (Phase 3)` |
| `333a70f` | `fix: surface wipe warning in lockout banner (Phase 4 finding)` |
| `2ed4f0b` | `docs: add PIN rate limiting` |
| `fb85e73` | `docs: track PinLoginScreen brute-force gap as separate issue` |

---

## Design decisions (locked via review)

1. **Lockout schedule: Option B** — 60s lockout on every attempt ≥5 (not just at 5), wipe at 10. Total time 5→10 = 5 min (blocks automation, graceful for forgetful users)
2. **Wipe behavior: keep stored phone** — UX win (no re-typing), phone is non-sensitive, OTP rate-limited backend anyway
3. **Wipe cleanup: UI handler** — service wipes `pin_hash` + `biometric_enabled` + counters only. UI calls `auth.logout()` separately (avoids service ↔ AuthProvider coupling)
4. **Time source: wall clock + injection** — `DateTime Function()` constructor param for test determinism. Production uses `DateTime.now`. Clock-rollback vulnerability documented as known limitation
5. **Biometric during lockout: disabled** — entire keypad (including biometric button) dimmed + IgnorePointer wrapped. Auto-trigger in `initState` skipped when already locked

---

## Files changed

| File | Type | Purpose |
|---|---|---|
| `frontend/mobile/lib/services/pin_storage_service.dart` | Modified | Sealed `PinResult` type, async `validatePin`, counter/lockout logic, clock injection, backup-restore defense in `init()` |
| `frontend/mobile/test/services/pin_storage_service_test.dart` | New | 15 unit tests (happy path, invalid, lockout, wipe, persistence, concurrency, init defense) |
| `frontend/mobile/lib/screens/pin_lock_screen.dart` | Modified | Async `_validatePin` with `PinResult` switch, countdown timer, lockout banner with wipe warning, `_handleWipe` → `PhoneInputScreen` |
| `frontend/mobile/lib/widgets/pin_keypad.dart` | Modified | New optional `enabled` param (default `true`) |
| `frontend/mobile/lib/l10n/app_strings.dart` | Modified | 6 new i18n keys on `PinLockStrings` (TH/EN) |
| `frontend/mobile/pubspec.yaml` | Modified | Added `flutter_secure_storage_platform_interface` dev dep for testing |
| `CLAUDE.md` | Modified | PIN rate limiting section + Known Security Tradeoffs + 11 new Do NOT items |
| `docs/issues/pin-login-rate-limit.md` | New | Tracks separate PinLoginScreen brute-force gap (out of scope) |

**Total:** 6 modified + 2 new, ~750 insertions

---

## Security impact

### Threats now mitigated
- ✅ **Physical device brute-force via UI** — 10-attempt hard cap, mandatory re-OTP after wipe
- ✅ **Accessibility/HID automation** — counter persists across app kill/restart; attacker can't reset via force-close
- ✅ **Biometric bypass during lockout** — entire keypad disabled, biometric hidden
- ✅ **Backup-restore counter rollback** — `init()` defense clears residual counter if PIN hash is missing

### Known limitations (documented in CLAUDE.md)
- ⚠️ **Device clock rollback** bypasses 60s lockout windows (but 10-attempt wipe counter is monotonic)
- ⚠️ **Rooted/jailbroken device** — can read raw `pin_hash` from FlutterSecureStorage → SHA-256 rainbow-table crack <1s (out of scope — needs slow KDF)
- ⚠️ **PinLoginScreen NOT covered** — see `docs/issues/pin-login-rate-limit.md` for separate tracking

### Not addressed in this PR (tracked)
- PinLoginScreen backend rate limiting (separate issue, est. 4-6h work)
- Per-device salt + slow KDF for PIN hash (future hardening)
- Biometric enrollment change detection (`LAContext.evaluatedPolicyDomainState` on iOS) — was H1 in biometric review

---

## Test coverage

**Unit tests (`test/services/pin_storage_service_test.dart`):** 15 test cases, all pass in ~4s
- Happy path (correct PIN → `PinValid`)
- Invalid path (4 wrong → `PinInvalid` with decreasing remaining count)
- Lockout (5th → `PinLockedOut`, attempts during lockout don't increment)
- Expiry (clock advance + correct PIN resets)
- Re-lock (6th after expiry re-locks)
- Wipe (10th → `PinWiped` + pin_hash cleared + biometric off)
- Post-wipe (no counter increment, missing PIN returns `PinInvalid` indefinitely)
- Counter reset on success
- `getCurrentLockoutState()` correctness
- Concurrency (parallel `validatePin` calls → exact count increment, no race)
- Persistence across instance recreation (app restart simulation)
- `savePin` resets counters (for wipe → re-OTP → new PIN flow)
- `init()` clears stale counter when PIN hash missing (backup-restore defense)

**Manual test checklist:** 30 cases across 8 groups (A-H) — see PR comments or Phase 4 review

---

## Review checklist

- [ ] Code review: `frontend/mobile/lib/services/pin_storage_service.dart` (core logic + sealed type)
- [ ] Code review: `frontend/mobile/lib/screens/pin_lock_screen.dart` (UI integration)
- [ ] Verify `flutter analyze` clean on 5 Phase-changed files
- [ ] Verify `flutter test test/services/pin_storage_service_test.dart` → 15/15 pass
- [ ] Verify `grep -n "_attemptsRemainingHint\|_wipeThreshold" frontend/mobile/lib/` → 0 matches (dead code removed)
- [ ] Verify `PinKeypad` backward compat: search all `PinKeypad(` callsites, ensure old ones still work (no `enabled` arg = default true)
- [ ] Verify wipe flow end-to-end on physical device: 10 wrong PINs → dialog → PhoneInputScreen → re-OTP works
- [ ] Verify counter persists across app kill (manual: 3 wrong → kill → reopen → 2 more wrong → 5th triggers lockout)
- [ ] Verify lockout banner shows wipe warning starting at attempt 7 ("เหลือ 3 ครั้งก่อนล้างข้อมูล")
- [ ] Verify biometric auto-trigger skipped during lockout (cold start into locked state)
- [ ] Verify i18n TH ↔ EN switch updates lockout banner / wipe dialog in realtime
- [ ] Verify new `CLAUDE.md` additions render correctly (no broken markdown)
- [ ] Verify `docs/issues/pin-login-rate-limit.md` links resolve in GitHub UI

---

## Rollout plan

1. Merge to `develop` after review approval
2. QA on staging: run manual test checklist Groups A-H
3. Security-reviewer sign-off (this is auth-critical code)
4. Deploy as normal app release (no backend coordination needed — purely client-side)
5. Monitor crash reports / user reports of "can't unlock" during first week (expect increase from legitimate users hitting lockout when they forget PIN — this is the intended behavior)

---

## Follow-ups (separate PRs)

1. **HIGH** — PinLoginScreen backend rate limiting (`docs/issues/pin-login-rate-limit.md`)
2. **MEDIUM** — Biometric enrollment change detection (finding H1 from biometric review — `LAContext.evaluatedPolicyDomainState` + Android KeyStore `setInvalidatedByBiometricEnrollment`)
3. **MEDIUM** — Slow KDF for local PIN hash (finding M4 from biometric review — PBKDF2 or Argon2 with per-device salt)
4. **LOW** — `iOS InfoPlist.strings` localization for Face ID prompt (finding M2 from biometric review)
5. **LOW** — Exception code distinction in biometric error handling — currently `catch (_)` swallows `NotEnrolled`, `LockedOut`, `PermanentlyLockedOut` (finding H2 from biometric review)

---

## References

- **Phase 1 Design spec:** shared in review thread — includes threat model, lockout schedule rationale, PinResult sealed class design, all 13 test cases, 5 open questions that were locked via review
- **Phase 2 review:** service + tests (15/15 pass, analyze clean, no coupling)
- **Phase 3 review:** UI integration (5 files clean, PinKeypad backward compat preserved)
- **Phase 4 review:** 30 manual test cases + Phase 4 finding that was subsequently fixed in `333a70f`
- **Parent review:** Biometric auth deep review (C1 Critical + H1 + H2 + 4 Medium findings) — see branch history

---

**🤖 Co-authored-by:** Claude (code-review-deep skill)
**Reviewer suggestions:** security-reviewer, flutter-rust-code-reviewer agents
