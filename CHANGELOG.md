# Changelog

Seluruh perubahan pada proyek Flutter Mobile PLAS-TypeScript (`D:\01 Projects\plasmobile`) dicatat pada berkas ini.
Format mengacu pada Keep a Changelog dengan tanggal zona lokal `Asia/Makassar` (WITA).

## [Unreleased]

### Added
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
- Menyempurnakan `buildPlasTheme()` (`lib/core/theme/plas_theme.dart`) dan `main.dart` dengan `SystemUiOverlayStyle` Light Mode, `ProgressIndicatorThemeData`, `DividerThemeData`, `TextSelectionThemeData`, dan `SnackBarThemeData`.
- Mengganti `NavigationBar` sementara pada `_AppShellScaffold` (`lib/core/router/app_router.dart`) dengan `PlasBottomNav`.
- Menyesuaikan impor material di `lib/app.dart`, `lib/core/router/app_router.dart`, `lib/core/theme/plas_theme.dart`, dan `lib/core/theme/plas_tokens.dart` ke `package:material_ui/material_ui.dart` mengikuti ketentuan Flutter 3.50.0.
- Menaikkan `material_symbols_icons` dari `4.2801.1` ke `4.2960.0` agar kompatibel dengan `IconData` berstatus `final class` pada Dart 3.14.0.
- Menambahkan `kotlin.incremental=false` di `android/gradle.properties` untuk mencegah kegagalan penutupan cache incremental Kotlin (`.tab`) lintas drive Windows (`C:` pub cache vs `D:` build).

### Verification
- `flutter analyze`: lulus (`No issues found!`).
- `flutter test`: seluruh 54 test lulus (21 unit test pada `test/core/` dan 33 widget/unit test pada `test/widgets/`).
