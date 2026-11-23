# Changelog

Seluruh perubahan pada proyek Flutter Mobile PLAS-TypeScript (`D:\01 Projects\plasmobile`) dicatat pada berkas ini.
Format mengacu pada Keep a Changelog dengan tanggal zona lokal `Asia/Makassar` (WITA).

## [Unreleased]

### Added
- **Tahap 5 (Bagian 2): Uji E2E Kontrak HTTP & QA Akhir Mobile (2026-11-23)**
  - Menambahkan 4 skenario uji integrasi E2E kontrak HTTP pada `test/features/live_contract_e2e_test.dart` yang menjalankan `PlasApp` langsung di atas `ApiPlasRepository` + `createPlasDio()` (`AuthInterceptor`, `IdempotencyInterceptor`, `ErrorInterceptor`) + `PendingSyncNotifier`: onboarding HTTP (`Authorization: Bearer`, `404 profile_not_found`, `409 nim_conflict`, `POST /me`, `PATCH /me/class`), offline retry idempoten (`Idempotency-Key` identik + payload `P6` kanonis), `DBR-14`/`DBR-15`/`P12`/`P13`, serta AI Socratic WITA (`35` detik timeout, `504 ai_timeout`, `200 already_processed`, `403 quota_exceeded`).
  - Menambahkan laporan Audit Final `antislop` Delivery Gate dan hasil ukur `contrast-check.py` WCAG 2.1 AA pada `docs/qa/delivery-gate-report.md`.
  - Menambahkan matriks pengujian Black Box (`BB-01` s.d. `BB-20`), protokol *task-based usability testing* (`UT-01` s.d. `UT-06`) + instrumen kuesioner **UEQ-S 8 item**, serta runbook integrasi live `USE_MOCK=false` pada `docs/qa/blackbox-usability-qa.md`.
- **Tahap 5 (Bagian 1): Persiapan Konfigurasi Android & Environment Live (2026-11-22)**
  - Memperbarui [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) dengan `android:label="PLAS-TypeScript"` dan `android:networkSecurityConfig="@xml/network_security_config"`.
  - Menambahkan `network_security_config.xml` terpisah untuk rilis (`cleartextTrafficPermitted="false"` di `android/app/src/main/res/xml/`) dan debug (`cleartextTrafficPermitted="true"` di `android/app/src/debug/res/xml/` untuk akses server Next.js lokal seperti `http://10.0.2.2:3000/api`).
  - Menetapkan tema `Light Mode` konsisten (`@android:style/Theme.Light.NoTitleBar`, `#F8FAFC` pada `colors.xml`) di `values/styles.xml` dan `values-night/styles.xml`, serta splash `launch_background.xml` + `drawable-v21/launch_background.xml` dengan vector `ic_plas_splash_logo.xml`.
  - Menerjemahkan logo aplikasi (`assets/svg/app_logo_ts.svg`) ke adaptive launcher icon vektor native API 26+ (`ic_launcher_background.xml`, `ic_launcher_foreground.xml`, `mipmap-anydpi-v26/ic_launcher.xml`) tanpa tambahan package pihak ketiga.
  - Menambahkan template `env.example.json` untuk `--dart-define-from-file`, meng-ignore `env.live.json` & `env.*.local.json` di `.gitignore`, menambahkan helper `AppEnv.missingLiveConfigKeys()` di `lib/core/config/app_env.dart` dengan pemeriksaan fail-fast di `lib/main.dart` ketika `USE_MOCK=false`, unit test `test/core/app_env_test.dart`, serta pembaruan dokumentasi pada `README.md`.

### Fixed
- **Audit Keseluruhan & Perbaikan Bug Pra-Tahap 5 (2026-11-22)**
  - `BUG-001`: Membekukan `(key, elapsedSeconds, answer)` per `questionId` (`_PendingExerciseSubmission`) di `lib/features/exercise/presentation/exercise_session_screen.dart` agar retry jawaban latihan yang identik tidak memicu `409 idempotency_conflict` akibat perubahan `time_spent_seconds`, mereset kunci bila mahasiswa mengubah jawaban sebelum berhasil atau saat error klien non-retryable, menambahkan parameter `clock` opsional untuk pengujian deterministik, menambahkan `didUpdateWidget` saat `exerciseId` berganti, serta fallback pengambilan `questions` dari `getExercise(subId)` bila respons `createExerciseAttempt` tidak menyertakannya.
  - `BUG-002`: Mengikat kunci idempotensi per `sequence` dengan payload jawaban (`_pendingAnswers`) di `lib/features/test_eval/presentation/test_session_screen.dart` agar perubahan jawaban pasca error `500`/`422` selalu mencetak `Idempotency-Key` baru, mereset kunci pada error klien non-retryable, serta mengisi `_pendingNextSequence = sequence + 1` pada cabang `409 already_answered` agar retry `startTestQuestion` tidak mengirim ulang jawaban soal sebelumnya.
  - `BUG-003`: Menambahkan guard `_bootstrapRevision` dan `userId` pada `SessionController.refreshProfile()` (`lib/features/auth/application/session_controller.dart`) guna mencegah respons `getMe()` yang terlambat memulihkan `profile` setelah `signOut()`.
  - `BUG-004`: Memperbaiki `accessTokenProvider` (`lib/core/network/dio_client.dart`) agar memanggil `ref.watch(authServiceProvider)` saat inisialisasi provider, bukan di dalam callback `AccessTokenProvider`.
  - Menambahkan 3 regression test baru di `test/features/exercise_session_review_test.dart`, `test/features/test_eval_flow_test.dart`, dan `test/features/auth_onboarding_flow_test.dart`.

### Added
- **Tahap 4: Implementasi Layar `M01` sampai `M15` (2026-11-21)**
  - Penambahan penyedia data bersama & manajemen sesi (`lib/features/shared/providers/plas_providers.dart` dan `lib/features/auth/application/session_controller.dart`) mencakup 5 tahap guard `AuthGateStatus`, sinkronisasi flag lokal `plas_class_onboarding_done_<mahasiswaId>`, serta `retryPendingSyncQueue` dan `invalidateLearningData`.
  - Penambahan alur autentikasi & onboarding `M01` hingga `M04` (`lib/features/auth/presentation/`): `SplashScreen`, `AuthScreen` (Email+Sandi & Google Sign-In), `OnboardingIdentityScreen` (`Nama` + `NIM VARCHAR(30)` dengan penanganan inline `409 nim_conflict` dan `profile_conflict`), dan `OnboardingClassScreen` (pencocokan `Kode Kelas`, pratinjau `#F0FDF4`/`#15803D`, dan `Lewati (Pengguna Umum)`).
  - Penambahan alur belajar & asisten Socratic `M05`, `M06`, `M07`, & `M09` (`lib/features/learn/presentation/` & `lib/features/ai/presentation/`): `LearnHomeScreen` (`ENERGY 2`, Hero Progress Banner, `PlasOfflineSyncBanner`, gerbang `DBR-15` Post-Test terkunci sampai 7/7 latihan `SUBMITTED`, 7 materi TypeScript), `MaterialDetailScreen` (SubMateri, Exercise `MC`/`TF`/`FIB`, `Attempt 1/3`..`3/3`, banner `attempt_limit_reached`, `Riwayat Attempt`), `SubMaterialReadScreen` (`PlasMarkdownView` + `PlasCodeBlock` + `TanyaAiFab`), dan `AiAssistantSheet` (`OwlBracketMascot`, 3 level Socratic, `requestId` UUID stabil saat retry `502`/`504`/offline, penanganan `already_processed`, dan varian `0/10` reset `00:00 WITA`).
  - Penambahan komponen latihan bersama (`lib/shared/widgets/plas_accuracy_ring.dart` dan `lib/features/shared/widgets/question_answer_input.dart`) serta layar latihan `M08A/B` dan `M13` (`lib/features/exercise/presentation/`): `ExerciseSessionScreen` (`ENERGY 1` tanpa Bottom Nav, tanpa timer, tanpa feedback instan, `Petunjuk Awal` opsional gratis, `TanyaAiFab`, antrean offline idempoten, `showSubmitExerciseConfirmDialog`) dan `ExerciseReviewScreen` (`PlasAccuracyRing` `#15803D`, `Jawaban Anda`, `Pembahasan Konsep` khusus status `SUBMITTED`, nol kunci jawaban `P13`).
  - Penambahan alur evaluasi Pre-Test & Post-Test `M10`, `M11`, & `M12` (`lib/features/test_eval/presentation/`): `TestSessionScreen` (ujian linear tanpa tombol Kembali, tanpa timer, tanpa `TanyaAiFab` `P12`, `PopScope` konfirmasi keluar sementara, banner/aksi resume `IN_PROGRESS` `P7`, antrean offline idempoten, refresh profil pasca `PRE` submit untuk `DBR-14`) dan `TestResultScreen` (`PlasAccuracyRing` `#1D4ED8`, skor, total durasi, status `is_correct` & durasi per soal, nol `explanation` dan nol kunci jawaban `P13`).
  - Penambahan tab `Riwayat` & `Profil` `M14` dan `M15` (`lib/features/history/presentation/history_screen.dart` & `lib/features/profile/presentation/profile_screen.dart`): ringkasan evaluasi tes, filter status aktivitas (`Semua`, `Selesai`, `Berlangsung`), timestamp `Asia/Makassar` (`WITA`), manajemen kelas aktif maupun terkunci `DBR-14` (`#FFFBEB`, `#E2E8F0`/`#475569`, `Symbols.lock`), dan konfirmasi keluar akun `showLogoutConfirmDialog`.
  - Penambahan 5 berkas widget & flow test baru pada `test/features/`: `auth_onboarding_flow_test.dart`, `learn_and_ai_flow_test.dart`, `exercise_session_review_test.dart`, `test_eval_flow_test.dart`, dan `history_profile_flow_test.dart` (termasuk stress test lebar `390px` dengan `TextScaler.linear(2.0)`).
- **Tahap 3: Layer Data Contract-Driven & Autentikasi (2026-11-19)**
  - Penambahan DTO aman mahasiswa di `lib/data/dto/` tanpa package codegen tambahan: `student_answer.dart`, `student_profile_dto.dart`, `material_dto.dart`, `exercise_dto.dart`, `test_dto.dart`, `ai_dto.dart`, dan `progress_dto.dart` (nol field kunci jawaban `P13`, enum uppercase `IN_PROGRESS`/`SUBMITTED` tanpa `EXPIRED`, serta `AiAskResponseDto` dengan field nullable untuk `already_processed`).
  - Penambahan `sealed class StudentAnswer` (`McAnswer`, `TfAnswer`, `FibAnswer`) dengan validasi ketat payload kanonis `P6` (1 key saja: `option_id` atau `value`, maksimal 255 karakter untuk `FIB`, menolak key ekstra dengan error `422 invalid_answer`).
  - Penambahan abstraksi autentikasi `AuthService` beserta `SupabaseAuthService` (khusus `GoTrueClient` + `GoogleSignIn` `signInWithIdToken` tanpa akses langsung tabel Supabase `P1`/`P4`) dan `MockAuthService` (`authServiceProvider`), terhubung ke `accessTokenProvider` pada `lib/core/network/dio_client.dart`.
  - Penambahan kontrak `PlasRepository` (24 operasi REST API Mobile `§4.1` hingga `§4.6` ditambah `replayPendingSyncItem`) dan `ApiPlasRepository` di `lib/data/repositories/` dengan `Idempotency-Key` milik pemanggil, timeout AI `35` detik (`kAiRequestTimeout`), dan konversi `DioException` ke `PlasApiException`.
  - Penambahan `MockSeedData` (2 kelas, NIM konflik `'2115099999'`, 7 materi pemrograman dasar TypeScript dengan blok kode ```` ```ts ```` dan latihan seragam `MC`/`TF`/`FIB`, serta Pre-Test dan Post-Test 5 soal campuran) dan `MockPlasRepository` (`DBR-14`, `DBR-15`, batas `3/3` attempt, fingerprint idempotensi `P2`, urutan linear dan `question_started_at` set-if-NULL `P7`, evaluasi FIB Levenshtein >= 70%, kuota AI `10/10 WITA` `P12`, dan `replayPendingSyncItem`) beserta `plasRepositoryProvider`.
  - Penambahan 4 berkas unit test di `test/data/`: `student_answer_dto_test.dart`, `auth_service_test.dart`, `api_plas_repository_test.dart`, dan `mock_plas_repository_test.dart`.
- **Tahap 2: Design System v1.1 & Komponen Inti (2026-11-19)**
  - Bundling font lokal statis ke `assets/fonts/` (`Plus Jakarta Sans` weight `400`/`500`/`600`/`700` dan `JetBrains Mono` weight `400`/`600`) serta pendaftaran pada `pubspec.yaml` untuk rendering Zero-CLS dan dukungan offline.
  - Penambahan 4 aset SVG vektor murni di `assets/svg/` (`owl_bracket.svg`, `owl_bracket_outline.svg`, `google_logo.svg`, `app_logo_ts.svg`) tanpa tag `<text>`.
  - Penambahan 8 komponen inti di `lib/shared/widgets/`:
    - `OwlBracketMascot`, `PlasAppLogo`, dan `PlasGoogleLogo` (`owl_bracket_mascot.dart`).
    - `PlasCodeBlock` beserta tokenizer murni `tokenizeTypeScriptLine` (`plas_code_block.dart`) dengan header `#1E293B`, fallback `TYPESCRIPT`, nomor baris, scroll horizontal terisolasi, dan `SelectionArea` opsional.
    - `PlasMarkdownView` beserta parser blok murni `parseMarkdownBlocks` dan `buildInlineSpans` (`plas_markdown_view.dart`) untuk merender materi SubMateri dan fenced block `.ts`.
    - `PlasStatusBadge` (`plas_status_badge.dart`) dengan 6 varian semantik yang selalu memasangkan ikon vektor dan teks.
    - `TanyaAiFab` (`tanya_ai_fab.dart`) dengan guard keras `isAssessmentMode` (`P12`) yang menyembunyikan tombol AI saat Pre/Post-Test.
    - `PlasConfirmDialog` beserta helper `showSubmitExerciseConfirmDialog`, `showSubmitTestConfirmDialog`, dan `showLogoutConfirmDialog` (`confirm_dialog.dart`).
    - `PlasBottomNav` (`plas_bottom_nav.dart`) dengan 3 tab (`Belajar`, `Riwayat`, `Profil`) dan target sentuh >= `48dp`.
    - `PlasStateViews` (`plas_state_views.dart`) untuk 4 data states wajib: `PlasLoadingSkeleton`, `PlasEmptyView`, `PlasErrorView`, dan `PlasOfflineSyncBanner`.
  - Penambahan 5 berkas widget test di `test/widgets/`: `owl_bracket_mascot_test.dart`, `plas_code_block_test.dart`, `plas_markdown_view_test.dart`, `tanya_ai_fab_test.dart`, dan `plas_components_test.dart` (mencakup uji lebar `390px` dengan `TextScaler.linear(2.0)`).
- **Tahap 1: Bootstrap Proyek & Arsitektur Folder (2026-11-19)**
  - Inisialisasi proyek Flutter Android (`id.ac.undiksha.plas.plasmobile`) pada `Flutter 3.50.0` (`Dart 3.14.0`) dengan `minSdk = 26` (Android 8.0+) pada `android/app/build.gradle.kts` dan izin `INTERNET` pada `AndroidManifest.xml`.
  - Penambahan dependensi inti di `pubspec.yaml`: `flutter_riverpod: 2.6.1`, `go_router: 14.6.2`, `dio: 5.7.0`, `supabase_flutter: 2.8.0`, `google_sign_in: 6.2.2`, `uuid: 4.5.1`, `shared_preferences: 2.3.3`, `flutter_svg: 2.0.16`, dan `material_symbols_icons: 4.2960.0`.
  - Modul konfigurasi dan error (`lib/core/config/app_env.dart`, `lib/core/constants/api_error_codes.dart`, `lib/core/errors/plas_exception.dart`) dengan pemetaan 29 kode error API dan SQLSTATE ke pesan bahasa Indonesia tanpa karakter em dash.
  - Layer jaringan HTTP (`lib/core/network/`) menggunakan `Dio` dengan `AuthInterceptor` (`Bearer JWT`), `IdempotencyInterceptor` (meneruskan kunci `Idempotency-Key` milik pemanggil tanpa regenerate saat retry), dan `ErrorInterceptor` (`PlasApiException` + deteksi kondisi offline).
  - Antrean sinkronisasi tertunda (`lib/core/sync/pending_sync_queue.dart`) berbasis `SharedPreferences` dengan deduplikasi `idempotencyKey` dan pembersihan otomatis konflik terminal `409`.
  - Utilitas domain (`lib/core/utils/levenshtein.dart` untuk normalisasi & kemiripan FIB >= 70% maks 255 karakter; `lib/core/utils/wita_clock.dart` untuk penanggalan kuota `Asia/Makassar` UTC+8).
  - Fondasi tema Light Mode *Academic Code & Paper* (`lib/core/theme/plas_tokens.dart`, `lib/core/theme/plas_theme.dart`) serta routing `GoRouter` (`lib/core/router/app_routes.dart`, `lib/core/router/app_router.dart`) mencakup guard 4 tahap `M01` hingga `M04` dan shell 3 tab (`Belajar`, `Riwayat`, `Profil`).
  - Bootstrap aplikasi (`lib/app.dart`, `lib/main.dart`) dengan inisialisasi opsional `Supabase.initialize` saat `USE_MOCK=false` dan konfigurasi tersedia.
  - Berkas pelacakan proyek `BACKLOG.md` dan `CHANGELOG.md`.
  - 6 berkas unit test inti (`test/core/`): `api_error_codes_test.dart`, `app_router_test.dart`, `interceptors_test.dart`, `levenshtein_test.dart`, `pending_sync_queue_test.dart`, dan `wita_clock_test.dart`.

### Changed
- Menambahkan parameter kueri opsional `{String? submaterialId}` pada `AppRoutes.exerciseSession` (`lib/core/router/app_routes.dart`) dengan kompatibilitas penuh saat parameter dikosongkan.
- Menghubungkan seluruh rute `M01` hingga `M15` di `appRouterProvider` (`lib/core/router/app_router.dart`) ke layar implementasi nyata serta menghapus `_StagePlaceholderScreen`.
- Menghubungkan `accessTokenProvider` (`lib/core/network/dio_client.dart`) secara default ke `authServiceProvider.getAccessToken()`.
- Menyempurnakan `buildPlasTheme()` (`lib/core/theme/plas_theme.dart`) dan `main.dart` dengan `SystemUiOverlayStyle` Light Mode, `ProgressIndicatorThemeData`, `DividerThemeData`, `TextSelectionThemeData`, dan `SnackBarThemeData`.
- Mengganti `NavigationBar` sementara pada `_AppShellScaffold` (`lib/core/router/app_router.dart`) dengan `PlasBottomNav`.
- Menyesuaikan impor material di `lib/app.dart`, `lib/core/router/app_router.dart`, `lib/core/theme/plas_theme.dart`, dan `lib/core/theme/plas_tokens.dart` ke `package:material_ui/material_ui.dart` mengikuti ketentuan Flutter 3.50.0.
- Menaikkan `material_symbols_icons` dari `4.2801.1` ke `4.2960.0` agar kompatibel dengan `IconData` berstatus `final class` pada Dart 3.14.0.
- Menambahkan `kotlin.incremental=false` di `android/gradle.properties` untuk mencegah kegagalan penutupan cache incremental Kotlin (`.tab`) lintas drive Windows (`C:` pub cache vs `D:` build).

### Verification
- `flutter analyze`: lulus (`No issues found!`).
- `flutter test`: seluruh 144 test lulus (24 unit test pada `test/core/`, 30 unit test pada `test/data/`, 33 widget/unit test pada `test/widgets/`, dan 57 widget/E2E flow test pada `test/features/`).
- `contrast-check.py`: seluruh pasangan warna `PlasColors` lolos WCAG 2.1 AA (teks normal minimal `6.15:1` >= `4.5:1`; border/focus/ring non-teks minimal `4.07:1` >= `3.0:1`).
- `flutter build apk --debug`: lulus (`build\app\outputs\flutter-apk\app-debug.apk`).
- `flutter build apk --release`: lulus (`build\app\outputs\flutter-apk\app-release.apk`, 52.2MB, `minSdk = 26`).
