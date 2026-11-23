# Backlog Implementasi Mobile PLAS-TypeScript (`plasmobile`)

**Target Proyek:** `D:\01 Projects\plasmobile` (Flutter Android `minSdk 26` / Android 8.0+)  
**Blueprint Acuan (Read-Only):** `C:\Users\shawn\Documents\Secondbrain\01 Projects\PLAS\`  
**Mode Antislop:** `during` (session override)

## Keputusan Teknis Terkunci
- State Management & DI: `flutter_riverpod` (`^2.6.1`, manual `Notifier`/`Provider`, tanpa codegen)
- Routing: `go_router` (`^14.6.2`, guard 4 tahap `M01` hingga `M04` + `StatefulShellRoute.indexedStack` 3 tab)
- HTTP Client: `dio` (`^5.7.0`, `AuthInterceptor`, `IdempotencyInterceptor`, `ErrorInterceptor`)
- DTO & Serialization: Plain immutable Dart 3 classes + `sealed class StudentAnswer` (`P6` kanonis tanpa extra key)
- Autentikasi (`P1`, `P4`): `supabase_flutter` (`^2.8.0`) + `google_sign_in` (`^6.2.2`) khusus Auth/JWT; seluruh operasi data melalui Next.js REST API (`POST /me` + `PATCH /me/class`)
- Pendukung: `uuid` (`^4.5.1`), `shared_preferences` (`^2.3.3`), `flutter_svg` (`^2.0.16`), `material_symbols_icons` (`4.2960.0`, kompatibel Flutter 3.50 / Dart 3.14)

---

## Tahap 1: Bootstrap Proyek & Arsitektur Folder
- [x] Inisialisasi proyek Flutter Android (`id.ac.undiksha.plas.plasmobile`, `minSdk = 26`, izin `INTERNET`)
- [x] Konfigurasi dependensi inti di `pubspec.yaml` tanpa package codegen
- [x] Implementasi `AppEnv` (`--dart-define` untuk `USE_MOCK`, `API_BASE_URL`, Supabase, Google Web Client ID)
- [x] Implementasi `ApiErrorCodes` (pemetaan kode error API dan 21 SQLSTATE) dan `PlasApiException`
- [x] Implementasi `Dio` client beserta `AuthInterceptor`, `IdempotencyInterceptor` (UUID stabil tanpa regenerate), dan `ErrorInterceptor`
- [x] Implementasi `PendingSyncStorage` dan `PendingSyncNotifier` berbasis `SharedPreferences`
- [x] Implementasi utilitas `levenshtein.dart` (normalisasi FIB + ambang >= 70%, maks 255 karakter) dan `wita_clock.dart` (`Asia/Makassar` UTC+8)
- [x] Implementasi fondasi token `DESIGN.md` (`plas_tokens.dart`) dan `buildPlasTheme()` Light Mode (`plas_theme.dart`)
- [x] Implementasi `AppRoutes` dan `GoRouter` (`computeAuthRedirect` 5 status + shell 3 tab + rute layar penuh `M06`, `M07`, `M08`, `M10`, `M12`, `M13`)
- [x] Buat `BACKLOG.md` dan `CHANGELOG.md` di `D:\01 Projects\plasmobile`
- [x] Verifikasi `flutter analyze` dan seluruh unit test `test/core/` lulus tanpa error

## Tahap 2: Design System & Komponen Inti (`DESIGN.md v1.1`)
- [x] Bundling font lokal `Plus Jakarta Sans` dan `JetBrains Mono` di `assets/fonts/` + registrasi di `pubspec.yaml`
- [x] Aset SVG vektor nyata di `assets/svg/` (`owl_bracket.svg`, `google_logo.svg`, `app_logo_ts.svg`)
- [x] Widget `PlasCodeBlock` (header `#1E293B`, fallback `TYPESCRIPT`, nomor baris `#94A3B8`, isi `#0F172A`, syntax tint TypeScript, scroll horizontal terisolasi)
- [x] Widget `PlasStatusBadge` (ikon vektor + teks untuk Success, Error, Warning, Neutral)
- [x] Widget `OwlBracketMascot` dan `TanyaAiFab` (`48dp`, `#0F172A`, border `#1E293B`)
- [x] Widget `ConfirmDialog` (submit tes, submit latihan, logout; radius `20px`, `shadow.overlay`)
- [x] Widget `PlasBottomNav` 3 tab (`Belajar`, `Riwayat`, `Profil`, tinggi `64dp`)
- [x] Widget `PlasStateViews` (4 data states wajib: Loading zero-CLS, Empty berilustrasi Owl Bracket, Error terpetakan, Offline/Pending Sync banner)
- [x] Widget `PlasMarkdownView` (parser fenced-Markdown SubMateri yang merender blok `.ts` via `PlasCodeBlock`)
- [x] Widget test komponen inti dan audit Delivery Gate Tahap 2

## Tahap 3: Layer Data Contract-Driven (`DTO` + `MockPlasRepository` & `ApiPlasRepository`)
- [x] Definisi DTO kontrak `API Specification §4.1` sampai `§4.6` (tanpa kunci jawaban di DTO mahasiswa `P13`)
- [x] `sealed class StudentAnswer` (`McAnswer`, `TfAnswer`, `FibAnswer`) dengan JSON kanonis ketat `P6` (tanpa extra key)
- [x] Abstraksi `AuthService`, `SupabaseAuthService` (Email+Sandi & Google Sign-In), dan `MockAuthService`
- [x] Kontrak `PlasRepository` (24 operasi endpoint Mobile)
- [x] Implementasi `MockPlasRepository` + `mock_seed_data.dart` (7 materi TypeScript, soal MC/TF/FIB, `DBR-14`, `DBR-15`, batas `3/3 attempt`, kuota `10/10 WITA`, evaluasi FIB Levenshtein >= 70%)
- [x] Implementasi `ApiPlasRepository` (terhubung ke `Dio` + `PendingSyncNotifier` + `kAiRequestTimeout`)
- [x] Unit test kontrak JSON `P6`, aturan `DBR-14`/`DBR-15`, batas `3/3`, kuota WITA, dan `P13` (zero answer key leakage)

## Tahap 4: Implementasi Layar `M01` sampai `M15`
- [x] `M01 - Splash` & pemeriksaan sesi auth + redirect onboarding/beranda
- [x] `M02 - Masuk / Daftar` (Email+Sandi + Google Sign-In)
- [x] `M03 - Lengkapi Identitas Mahasiswa` (`Nama` + `NIM VARCHAR(30)` + tangani `409 nim_conflict` & `profile_conflict`)
- [x] `M04 - Gabung Kelas` (input `Kode Kelas` + pratinjau kelas/dosen + `Lewati (Pengguna Umum)`)
- [x] `M05 - Beranda Belajar & Gerbang Tes` (Hero Progress Banner, kartu Pre-Test & Post-Test `DBR-15`, daftar 7 materi, `ENERGY 2`)
- [x] `M06 - Daftar SubMateri, Exercise, & Riwayat Attempt` (`Attempt 1/3`..`3/3`, state `attempt_limit_reached`)
- [x] `M07 - Layar Baca SubMateri` (`PlasMarkdownView` + `PlasCodeBlock` + `TanyaAiFab`)
- [x] `M08A/B - Sesi Soal Latihan` (MC, TF, FIB maks 255 karakter, `Petunjuk Awal` opsional, tanpa feedback instan, `TanyaAiFab`, antrean offline idempoten)
- [x] `M09 - Bottom Sheet AI Learning Assistant` (3-level Socratic, kuota WITA `10/10`, varian `0/10` reset `00:00 WITA`)
- [x] `M10`, `M11`, `M12` - Pre/Post-Test Linear (tanpa timer, tanpa tombol Kembali, `TanyaAiFab` disembunyikan), Resume `IN_PROGRESS`, `ConfirmDialog`, & Hasil Tes tanpa pembahasan/kunci
- [x] `M13 - Ringkasan & Detail Review Latihan` (grafik cincin akurasi SVG, status `Benar`/`Salah`, `Pembahasan Konsep`, tanpa kunci jawaban `P13`)
- [x] `M14` & `M15` - Tab `Riwayat` dan Tab `Profil` (status kelas, kunci kelas `DBR-14` pasca Pre-Test `SUBMITTED`, Logout `ConfirmDialog`)

## Tahap 5: Integrasi Backend Next.js & QA Akhir
- [x] Persiapan konfigurasi Android & environment live (label aplikasi `PLAS-TypeScript`, `network_security_config` debug HTTP vs release HTTPS, adaptive launcher icon & splash vector Light Mode `#F8FAFC`, template `env.example.json` + validasi fail-fast `AppEnv.missingLiveConfigKeys()`, serta verifikasi build APK debug & release `minSdk 26`)
- [x] Verifikasi E2E kontrak HTTP (`ApiPlasRepository` + `Dio` interceptors + `PlasApp` melalui `test/features/live_contract_e2e_test.dart`): onboarding HTTP `404`/`409`/`POST /me`/`PATCH /me/class`, offline retry idempoten `P2` + payload `P6`, `DBR-14`/`DBR-15`/`P12`/`P13`, dan AI Socratic WITA `504`/`already_processed`/`403 quota_exceeded`
- [x] Audit final `antislop` Delivery Gate & kesiapan uji Black Box / Usability (kontras WCAG 2.1 AA via `contrast-check.py` pada `docs/qa/delivery-gate-report.md`, serta matriks Black Box `BB-01`..`BB-20`, protokol Task-Based Usability `UT-01`..`UT-06` + kuesioner UEQ-S 8 item, dan runbook live di `docs/qa/blackbox-usability-qa.md`)
- [ ] Uji end-to-end dengan `--dart-define=USE_MOCK=false` terhadap REST API Next.js dan Supabase Auth live serta build APK live setelah server backend aktif

---

## Catatan Bug & Temuan Review
- [x] **BUG-001 (`P2` Idempotency Conflict saat Retry Jawaban Latihan):** Pada `lib/features/exercise/presentation/exercise_session_screen.dart`, `timeSpentSeconds` (`elapsed`) sebelumnya dihitung ulang saat tombol kirim ditekan sementara UUID `Idempotency-Key` dipertahankan, serta kunci lama tetap terpakai bila pengguna mengganti jawaban sebelum retry.
  - **Perbaikan:** Membekukan draft `(key, elapsedSeconds, answer)` per `questionId` dalam `_PendingExerciseSubmission` untuk retry jawaban yang sama, mereset draft pada `QuestionAnswerInput.onChanged` bila jawaban diubah maupun pada error klien non-retryable, serta menambahkan `didUpdateWidget` saat `exerciseId` berubah dan fallback `questions` dari `getExercise(subId)`.
- [x] **BUG-002 (`P2` Idempotency Conflict saat Mengubah Jawaban Tes setelah Error Inline):** Pada `lib/features/test_eval/presentation/test_session_screen.dart`, `_answerKeys[sequence]` sebelumnya tidak di-reset bila pengguna mengubah pilihan jawaban setelah gagal kirim non-retryable (mis. `500`/`422`), dan cabang `409 already_answered` tidak mengisi `_pendingNextSequence` sebelum memanggil `startTestQuestion(sequence + 1)`.
  - **Perbaikan:** Mengikat kunci idempotensi per `sequence` dengan payload jawaban pada `_pendingAnswers`, meresetnya saat `QuestionAnswerInput.onChanged` atau error klien non-retryable, serta menetapkan `_pendingNextSequence = sequence + 1` pada handler `already_answered`.
- [x] **BUG-003 (Race Condition `SessionController.refreshProfile` vs `signOut`):** Pada `lib/features/auth/application/session_controller.dart`, `refreshProfile()` sebelumnya dapat menimpa `state.profile` dengan respons `getMe()` yang terlambat setelah pengguna keluar akun.
  - **Perbaikan:** Menambahkan guard `_bootstrapRevision` dan `userId` aktif sebelum dan sesudah `await _repository.getMe()`.
- [x] **BUG-004 (`ref.watch` di dalam Closure `accessTokenProvider`):** Pada `lib/core/network/dio_client.dart`, `accessTokenProvider` memanggil `ref.watch(authServiceProvider)` di dalam fungsi callback async.
  - **Perbaikan:** Memindahkan pembacaan `ref.watch(authServiceProvider)` ke body provider dan mengembalikan tear-off `authService.getAccessToken`.
