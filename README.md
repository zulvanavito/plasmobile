# PLAS-TypeScript Mobile (`plasmobile`)

Aplikasi mobile Android berbasis Flutter untuk **PLAS-TypeScript** (*Programming Learning Assistant System*), yaitu media pembelajaran sintaksis dasar TypeScript bagi mahasiswa pemula dengan evaluasi terstruktur dan pendampingan AI *Socratic*.

Proyek ini merupakan implementasi client mobile dari blueprint acuan pada `C:\Users\shawn\Documents\Secondbrain\01 Projects\PLAS\` dan terhubung ke backend Next.js REST API serta Supabase Auth.

## Daftar Isi

- [Ringkasan Sistem & Ruang Lingkup](#ringkasan-sistem--ruang-lingkup)
- [Spesifikasi Teknis & Dependensi](#spesifikasi-teknis--dependensi)
- [Arsitektur Modul Inti](#arsitektur-modul-inti)
- [Struktur Direktori](#struktur-direktori)
- [Konfigurasi Environment](#konfigurasi-environment)
- [Menjalankan Aplikasi & Pengujian](#menjalankan-aplikasi--pengujian)
- [Status Implementasi & Dokumen Terkait](#status-implementasi--dokumen-terkait)

---

## Ringkasan Sistem & Ruang Lingkup

Client `plasmobile` melayani alur belajar mahasiswa pada perangkat Android (`minSdk 26` / Android 8.0 ke atas) melalui tiga kelompok alur utama:

| Kelompok Alur | Kode Layar | Cakupan Fungsional |
|---|---|---|
| Autentikasi & Onboarding | `M01` sampai `M04` | Masuk dengan email/kata sandi atau Google Sign-In melalui Supabase Auth, melengkapi identitas mahasiswa (`Nama` dan `NIM`), serta bergabung ke kelas atau memilih mode pengguna umum. |
| Pembelajaran & Latihan | `M05` sampai `M09`, `M13` | Mengakses 7 materi dasar TypeScript, membaca submateri beserta blok kode, mengerjakan latihan (`MC`, `TF`, `FIB`) maksimal 3 percobaan per *SubMaterial*, meninjau hasil tanpa kunci jawaban di client, serta menggunakan asisten AI *Socratic* 3 level dengan kuota harian zona waktu `Asia/Makassar` (WITA). |
| Evaluasi & Riwayat | `M10` sampai `M12`, `M14`, `M15` | Mengerjakan Pre-test dan Post-test secara linear tanpa timer, melihat ringkasan riwayat latihan maupun tes, serta memantau status profil dan keanggotaan kelas. |

---

## Spesifikasi Teknis & Dependensi

| Komponen | Spesifikasi / Paket | Keterangan |
|---|---|---|
| Application ID | `id.ac.undiksha.plas.plasmobile` | Target Android `minSdk = 26`, izin `INTERNET` |
| SDK & UI Toolkit | Dart `^3.14.0`, `material_ui: ^1.1.0` | Light Mode Material 3 (*Academic Code & Paper*) |
| Java & Kotlin Target | JVM 17 | Dikonfigurasi pada `android/app/build.gradle.kts` |
| State Management | `flutter_riverpod: ^2.6.1` | `Provider` dan `Notifier` manual tanpa codegen |
| Navigasi | `go_router: ^14.6.2` | Redirect 5 status auth + shell 3 tab + rute layar penuh |
| Jaringan HTTP | `dio: ^5.7.0` | Timeout connect/send 15 detik, receive 20 detik, AI `kAiRequestTimeout` 35 detik |
| Autentikasi | `supabase_flutter: ^2.8.0`, `google_sign_in: ^6.2.2` | Khusus Auth/JWT; seluruh data lewat Next.js REST API |
| Penyimpanan & Utilitas | `shared_preferences: ^2.3.3`, `uuid: ^4.5.1` | Antrean sync lokal (`plas_pending_sync_v1`) |
| Grafis & Ikon | `flutter_svg: ^2.0.16`, `material_symbols_icons: 4.2960.0` | Aset vektor SVG dan ikon Material Symbols |
| Linter | `flutter_lints: ^6.0.0` | Diaktifkan melalui `analysis_options.yaml` |

---

## Arsitektur Modul Inti

Seluruh fondasi lintas fitur berada di bawah `lib/core/` dan dipisahkan menurut tanggung jawabnya:

```text
lib/main.dart (SharedPreferences + Supabase.initialize jika USE_MOCK=false)
  └── PlasApp (lib/app.dart)
        ├── Theme      : buildPlasTheme() + PlasColors/PlasTypography/PlasSpacing
        ├── Router     : appRouterProvider -> computeAuthRedirect(AuthGateStatus)
        ├── Network    : createPlasDio() -> AuthInterceptor
        │                                -> IdempotencyInterceptor
        │                                -> ErrorInterceptor -> PlasApiException
        ├── Offline    : PendingSyncStorage & PendingSyncNotifier (SharedPreferences)
        └── Utilities  : levenshtein.dart (FIB >= 70%), wita_clock.dart (UTC+8)
```

- `lib/core/network/`, `lib/core/errors/`, dan `lib/core/constants/` mengelola komunikasi HTTP dan pemetaan kesalahan. `AuthInterceptor` menyisipkan header `Authorization: Bearer <token>` kecuali ketika `extra['skipAuth'] == true`. `IdempotencyInterceptor` meneruskan header `Idempotency-Key` milik pemanggil tanpa membuat ulang UUID saat percobaan ulang. `ErrorInterceptor` memetakan kegagalan jaringan atau kode error API dari `ApiErrorCodes` (29 kode error) menjadi `PlasApiException` berbahasa Indonesia.
- `lib/core/sync/pending_sync_queue.dart` menangani antrean sinkronisasi tertunda pada `SharedPreferences` (`plas_pending_sync_v1`) dengan deduplikasi `idempotencyKey`. Saat `retryAll` dijalankan, item yang menerima konflik terminal (`already_answered`, `already_submitted`, `attempt_submitted`, `idempotency_conflict`) otomatis dihapus dari antrean, sedangkan error dengan flag `isRetryable` tetap disimpan untuk dicoba ulang.
- `lib/core/router/` mengatur navigasi dan proteksi akses lewat `computeAuthRedirect` berdasarkan `AuthGateStatus` (`loading`, `unauthenticated`, `needsIdentity`, `needsClass`, `authenticated`). Pengguna terautentikasi masuk ke shell 3 tab (`Belajar` di `/learn`, `Riwayat` di `/history`, `Profil` di `/profile`), dengan rute layar penuh untuk detail materi, baca submateri, sesi latihan, review latihan, sesi tes, dan hasil tes.
- `lib/core/utils/` menyimpan aturan domain client. `levenshtein.dart` menormalisasi jawaban *Fill-in-the-Blank* (maksimal 255 karakter) dan mengevaluasi kemiripan dengan ambang minimal `0.70`, sedangkan `wita_clock.dart` menghitung tanggal kalender serta sisa waktu menuju tengah malam `Asia/Makassar` (`UTC+8`) agar perhitungan kuota tidak bergantung pada zona waktu perangkat.
- `lib/core/theme/` menyediakan token warna Light Mode, spasi, radius, bayangan, serta pasangan font `Plus Jakarta Sans` dan `JetBrains Mono` di `plas_tokens.dart` yang dirangkai ke `ThemeData` oleh `buildPlasTheme()` di `plas_theme.dart`.

---

## Struktur Direktori

```text
plasmobile/
├── android/
│   ├── gradle.properties                         # Menyetel kotlin.incremental=false untuk build Windows
│   └── app/
│       ├── build.gradle.kts                      # Namespace, minSdk 26, Java/Kotlin 17
│       └── src/
│           ├── debug/res/xml/
│           │   └── network_security_config.xml   # Mengizinkan HTTP lokal saat debug (10.0.2.2)
│           └── main/
│               ├── AndroidManifest.xml           # Label PLAS-TypeScript, INTERNET, networkSecurityConfig
│               └── res/
│                   ├── drawable/
│                   │   ├── ic_launcher_background.xml
│                   │   ├── ic_launcher_foreground.xml
│                   │   ├── ic_plas_splash_logo.xml
│                   │   └── launch_background.xml # Splash Light Mode + logo PLAS-TypeScript
│                   ├── drawable-v21/launch_background.xml
│                   ├── mipmap-anydpi-v26/ic_launcher.xml
│                   ├── values/colors.xml
│                   ├── values/styles.xml         # LaunchTheme & NormalTheme Light Mode
│                   ├── values-night/styles.xml   # Paksa Light Mode meski OS memakai Dark Mode
│                   └── xml/network_security_config.xml # Ketat HTTPS (cleartext=false) untuk rilis
├── assets/
│   ├── fonts/                                    # Plus Jakarta Sans & JetBrains Mono statis
│   └── svg/                                      # Aset vektor owl_bracket, google_logo, app_logo_ts
├── lib/
│   ├── app.dart                                  # Root widget PlasApp (MaterialApp.router)
│   ├── main.dart                                 # Entry point, validasi AppEnv, & Supabase.initialize
│   ├── core/                                     # Config, error codes, Dio, router, sync, tema, utils
│   ├── data/                                     # DTO kontrak API, AuthService, Mock & Api repository
│   ├── shared/widgets/                           # Komponen UI desain sistem PLAS
│   └── features/                                 # Layar M01-M15 (auth, learn, ai, exercise, test_eval, history, profile)
├── test/
│   ├── core/                                     # 7 berkas unit test modul inti (24 test)
│   ├── data/                                     # 4 berkas unit test data layer & kontrak API (30 test)
│   ├── widgets/                                  # 5 berkas widget test komponen inti (33 test)
│   └── features/                                 # 5 berkas integration/flow test layar M01-M15 (53 test)
├── analysis_options.yaml
├── BACKLOG.md                                    # Rencana kerja 5 tahap & catatan perbaikan bug
├── CHANGELOG.md                                  # Riwayat perubahan proyek
├── env.example.json                              # Template konfigurasi --dart-define-from-file
└── pubspec.yaml
```

---

## Konfigurasi Environment

Konfigurasi runtime dikelola lewat `--dart-define` atau `--dart-define-from-file` pada [`lib/core/config/app_env.dart`](./lib/core/config/app_env.dart). Tersedia berkas template [`env.example.json`](./env.example.json) sebagai acuan.

| Variabel | Default | Fungsi |
|---|---|---|
| `USE_MOCK` | `true` | Mengaktifkan mode mock lokal; jika `false`, startup memvalidasi key wajib lewat `AppEnv.missingLiveConfigKeys()` sebelum memanggil `Supabase.initialize` |
| `API_BASE_URL` | `http://10.0.2.2:3000/api` | Base URL Next.js REST API (`10.0.2.2` mengarah ke host lokal dari emulator Android) |
| `SUPABASE_URL` | `""` | URL proyek Supabase untuk layanan autentikasi (wajib saat `USE_MOCK=false`) |
| `SUPABASE_ANON_KEY` | `""` | Anon key publik Supabase Auth (wajib saat `USE_MOCK=false`) |
| `GOOGLE_WEB_CLIENT_ID` | `""` | Client ID OAuth Web untuk autentikasi Google Sign-In |

### Catatan Keamanan Jaringan & Google Sign-In Android

- **Debug vs Release Network Security Config:** Build `debug` menggunakan [`android/app/src/debug/res/xml/network_security_config.xml`](./android/app/src/debug/res/xml/network_security_config.xml) (`cleartextTrafficPermitted="true"`) agar emulator dan perangkat uji bisa mengakses server Next.js lokal via HTTP (`http://10.0.2.2:3000/api` atau IP LAN). Build `release` dan `profile` memakai [`android/app/src/main/res/xml/network_security_config.xml`](./android/app/src/main/res/xml/network_security_config.xml) (`cleartextTrafficPermitted="false"`) yang mewajibkan HTTPS.
- **Konfigurasi Environment Live Lokal:** Salin `env.example.json` menjadi `env.live.json` (sudah di-ignore pada [`.gitignore`](./.gitignore)) lalu isi kredensial proyek Anda:

```bash
cp env.example.json env.live.json
```

- **SHA-1 Keystore untuk Google Sign-In:** Daftarkan SHA-1 keystore debug/rilis Android ke proyek Google Cloud OAuth & Supabase Auth dengan mengecek fingerprint melalui Gradle:

```bash
cd android && ./gradlew signingReport
```

---

## Menjalankan Aplikasi & Pengujian

### Prasyarat
- Flutter SDK dengan Dart `^3.14.0`
- Android SDK dengan target minimal API Level 26 (Android 8.0)
- Pada lingkungan Windows, [`android/gradle.properties`](./android/gradle.properties) menonaktifkan kompilasi incremental Kotlin (`kotlin.incremental=false`) untuk mencegah kegagalan penguncian cache lintas drive (`C:` pub cache dan `D:` build)

### 1. Pasang Dependensi

```bash
flutter pub get
```

### 2. Jalankan Aplikasi

Mode default (`USE_MOCK=true`):

```bash
flutter run
```

Mode terhubung ke backend Next.js dan Supabase Auth menggunakan `env.live.json`:

```bash
flutter run --dart-define-from-file=env.live.json
```

Atau secara eksplisit dengan flag `--dart-define`:

```bash
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=http://10.0.2.2:3000/api --dart-define=SUPABASE_URL=<supabase_url> --dart-define=SUPABASE_ANON_KEY=<supabase_anon_key> --dart-define=GOOGLE_WEB_CLIENT_ID=<google_web_client_id>
```

### 3. Analisis Statis, Unit Test, & Build APK

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release --dart-define-from-file=env.live.json
```

Konfigurasi `release` pada [`android/app/build.gradle.kts`](./android/app/build.gradle.kts) saat ini masih memakai `signingConfigs.getByName("debug")` sampai konfigurasi keystore rilis ditambahkan.

---

## Status Implementasi & Dokumen Terkait

Perkembangan proyek mengacu pada lima tahap di [`BACKLOG.md`](./BACKLOG.md):

| Tahap | Cakupan | Status |
|---|---|---|
| Tahap 1 | Bootstrap proyek, arsitektur `lib/core/`, tema, router, dan unit test modul inti (24 test) | Selesai |
| Tahap 2 | Bundling font lokal, aset SVG, dan widget inti Design System (`DESIGN.md v1.1`) (33 test) | Selesai |
| Tahap 3 | DTO kontrak API `P6`, `AuthService`, `MockPlasRepository`, dan `ApiPlasRepository` (30 test) | Selesai |
| Tahap 4 | Implementasi layar `M01` sampai `M15` + audit bugfix `BUG-001` hingga `BUG-004` (53 test) | Selesai |
| Tahap 5 | Konfigurasi Android & env live selesai; lanjut uji `USE_MOCK=false`, `DBR-14`/`DBR-15`, dan QA akhir | Sedang berjalan |

Untuk daftar tugas per tahap dan keputusan teknis terkunci, lihat [`BACKLOG.md`](./BACKLOG.md). Catatan rinci setiap perubahan dan hasil verifikasi berkala terdokumentasi di [`CHANGELOG.md`](./CHANGELOG.md).
