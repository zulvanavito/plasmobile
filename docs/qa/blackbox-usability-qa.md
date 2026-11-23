# Dokumen Pengujian QA Akhir: Black Box, Task-Based Usability (UEQ-S), & Runbook Live

**Proyek:** `plasmobile` (`PLAS-TypeScript` Mobile Android, `minSdk 26`)  
**Rujukan:** `PRD MOBILE.md` (§6, §10, §12), `API Specification PLAS-TypeScript.md` (§1-§4, §6), `DESIGN.md v1.1`  
**Branch:** `staging`

---

## Bagian A: Matriks Pengujian Black Box (`BB-01` s.d. `BB-20`)

Matriks berikut memetakan kebutuhan fungsional `MOB-FR-001` sampai `MOB-FR-046` dan aturan domain (`DBR-14`, `DBR-15`, `P2`, `P6`, `P7`, `P12`, `P13`) menjadi skenario uji terverifikasi. Kolom **Uji Otomatis** merujuk pada test yang sudah berjalan dan lulus pada suite `flutter test`, sedangkan **Status Perangkat/Live** diisi saat pengujian langsung dengan backend Next.js & Supabase live (`USE_MOCK=false`).

| Kode | Area / Layar | Ref. Kebutuhan | Skenario & Input Uji | Hasil yang Diharapkan | Rujukan Uji Otomatis (Lulus) | Status Live |
|---|---|---|---|---|---|---|
| `BB-01` | `M01`-`M02` Autentikasi Email | `MOB-FR-001`, `MOB-FR-003` | Masuk dengan email format salah / kata sandi < 6 karakter, lalu masuk dengan kredensial valid. | Pesan error inline tampil tanpa crash; login valid memanggil `GET /me` dengan header `Authorization: Bearer <jwt>`. | `auth_onboarding_flow_test.dart`, `live_contract_e2e_test.dart` (#1) | `[ ]` |
| `BB-02` | `M02` Google Sign-In | `MOB-FR-001`, `P1` | Tekan `Masuk dengan Google` saat dibatalkan vs saat berhasil. | Pembatalan menampilkan pesan inline aman; login sukses menukar ID token lewat GoTrue dan memeriksa `GET /me`. | `auth_onboarding_flow_test.dart`, `auth_service_test.dart` | `[ ]` |
| `BB-03` | `M03` Onboarding Identitas | `KF11`, `DBR-13` | Akun baru (`404 profile_not_found`) isi Nama & NIM; uji NIM duplikat (`409 nim_conflict`) dan `409 profile_conflict`. | Error `nim_conflict` tampil di bawah field NIM; profil valid tersimpan via `POST /me` (`kelas_id: null`) lalu lanjut ke `M04`. | `auth_onboarding_flow_test.dart`, `live_contract_e2e_test.dart` (#1) | `[ ]` |
| `BB-04` | `M04` Gabung Kelas / Umum | `MOB-FR-004` | Masukkan kode kelas `TI-2A-2026`, cek pratinjau dosen; uji tombol `Lewati (Pengguna Umum)`. | Pratinjau hijau (`#F0FDF4`) tampil saat cocok dan `PATCH /me/class` mengarahkan ke `/learn`; mode lewati menyimpan preferensi lokal dan masuk ke `/learn` sebagai `Pengguna Umum`. | `auth_onboarding_flow_test.dart`, `live_contract_e2e_test.dart` (#1) | `[ ]` |
| `BB-05` | `M05` Beranda & Progres | `MOB-FR-005`, `MOB-FR-009` | Buka tab `Belajar`, periksa Hero Progress Banner, kuota AI WITA, dan daftar 7 materi urut `sequence`. | Menampilkan nama/avatar inisial, progres `completed/7`, kuota AI WITA, kartu Pre-Test/Post-Test, dan 7 materi TypeScript. | `learn_and_ai_flow_test.dart` | `[ ]` |
| `BB-06` | `M06`-`M07` Materi & Blok Kode | `MOB-FR-006` s.d. `008` | Buka Materi -> SubMateri; gulir blok kode `.ts` horizontal di layar sempit. | Blok kode gelap `#0F172A` dengan header file & nomor baris bergulir horizontal tanpa menyebabkan overflow halaman. | `learn_and_ai_flow_test.dart`, `plas_markdown_view_test.dart` | `[ ]` |
| `BB-07` | `M08A/B` Sesi Latihan (`MC`/`TF`/`FIB`) | `MOB-FR-010` s.d. `013`, `P6` | Kerjakan soal `MC`, `TF`, dan `FIB` (maks 255 char); coba `FIB` > 255 / hanya spasi. | Payload jawaban kanonis 1 key (`{"option_id":...}` atau `{"value":...}`); tombol Kirim nonaktif bila kosong; tidak ada feedback `Benar`/`Salah` instan saat `IN_PROGRESS`. | `exercise_session_review_test.dart`, `student_answer_dto_test.dart` | `[ ]` |
| `BB-08` | `M08` Petunjuk Awal Gratis | `MOB-FR-010` | Toggle tombol `Petunjuk Awal` sebelum mengirim jawaban latihan. | Kartu `#FFFBEB` tampil/sembunyi lokal tanpa memanggil `POST /ai/ask` dan tanpa mengurangi kuota AI harian. | `exercise_session_review_test.dart` | `[ ]` |
| `BB-09` | `M08` Bug-001 Retry & Ubah Jawaban | `P2` Idempotency | Gagal kirim jawaban latihan (`503`/`500`) lalu klik ulang tanpa ubah jawaban; ulangi skenario lain dengan mengubah opsi sebelum retry. | Retry jawaban identik memakai `Idempotency-Key` dan `time_spent_seconds` beku; mengubah jawaban sebelum berhasil selalu mencetak `Idempotency-Key` baru tanpa `409 idempotency_conflict`. | `exercise_session_review_test.dart` (`BUG-001`) | `[ ]` |
| `BB-10` | `M08` Offline Queue & Replay | `PRD §10 Koneksi`, `P2` | Putus koneksi saat kirim jawaban & submit latihan, sambungkan kembali, tekan `Kirim Ulang Sekarang`. | Item masuk `PendingSyncNotifier` (`plas_pending_sync_v1`), banner offline tampil, replay mengirim ulang key & payload `P6` identik tanpa duplikasi attempt, lalu masuk `M13`. | `live_contract_e2e_test.dart` (#2), `pending_sync_queue_test.dart` | `[ ]` |
| `BB-11` | `M06` Batas 3/3 Attempt | `MOB-FR-015`, `DBR-05` | Selesaikan 3 attempt pada satu exercise dan coba buat attempt ke-4. | Status menampilkan `Attempt 3/3` dan banner merah `attempt_limit_reached`; CTA mulai baru nonaktif. | `learn_and_ai_flow_test.dart`, `exercise_session_review_test.dart`, `mock_plas_repository_test.dart` | `[ ]` |
| `BB-12` | `M13` Review Latihan (`P13`) | `MOB-FR-014`, `P13` | Buka `M13` untuk attempt `SUBMITTED` dan coba akses rute review untuk attempt `IN_PROGRESS`. | Attempt `SUBMITTED` menampilkan `PlasAccuracyRing`, `Jawaban Anda`, status `Benar`/`Salah`, `Pembahasan Konsep`, dan nol kotak `Kunci Jawaban`; `IN_PROGRESS` dilindungi guard resume. | `exercise_session_review_test.dart` | `[ ]` |
| `BB-13` | `M09` AI Socratic 3 Level | `MOB-FR-018` s.d. `021`, `MOB-FR-046` | Buka `Tanya AI` dari `M07`/`M08`, kirim pertanyaan, dan pilih Level 1, Level 2, Level 3. | Request menyertakan `hint_level` `1..3` dan konteks opsional, membalas dengan bimbingan Socratic, serta menyinkronkan sisa kuota WITA. | `learn_and_ai_flow_test.dart`, `api_plas_repository_test.dart` | `[ ]` |
| `BB-14` | `M09` Idempotensi & Kuota WITA | `MOB-FR-022` s.d. `024`, `P2` | Uji timeout `504 ai_timeout` lalu retry (`already_processed`), dan uji respons `403 quota_exceeded` / kuota `0/10`. | Retry mempertahankan `Idempotency-Key` sama dengan timeout 35 detik; status `0/10` menonaktifkan input & tombol kirim dengan info reset `00:00 WITA`. | `live_contract_e2e_test.dart` (#4), `wita_clock_test.dart` | `[ ]` |
| `BB-15` | `M05` / `M14` Gerbang `DBR-15` | `MOB-FR-045`, `DBR-15` | Periksa kartu Post-Test sebelum 7/7 latihan `SUBMITTED` vs setelah seluruh latihan `SUBMITTED`. | Sebelum 7/7 selesai, tombol Post-Test nonaktif (`Terkunci`); setelah 7/7 `SUBMITTED`, kartu otomatis terbuka untuk memulai Post-Test. | `learn_and_ai_flow_test.dart`, `live_contract_e2e_test.dart` (#3) | `[ ]` |
| `BB-16` | `M10` Tes Linear & Mode Fokus | `MOB-FR-027` s.d. `032`, `P12` | Mulai Pre-Test atau Post-Test; cek AppBar, Bottom Nav, `TanyaAiFab`, dan tombol Kirim sebelum memilih opsi. | Tanpa timer, tanpa `TanyaAiFab`, tanpa Bottom Nav, tanpa tombol Kembali ke soal sebelumnya, CTA nonaktif saat belum memilih, konfirmasi `PopScope` saat keluar sementara. | `test_eval_flow_test.dart`, `live_contract_e2e_test.dart` (#3) | `[ ]` |
| `BB-17` | `M11` Resume `IN_PROGRESS` (`P7`) | `MOB-FR-033` s.d. `036`, `P7` | Keluar sementara di tengah tes, jeda beberapa saat, lalu lanjutkan sesi. | Banner kuning `#FFFBEB` `IN_PROGRESS` tampil, urutan opsi snapshot MC dan `question_started_at` awal terjaga. | `test_eval_flow_test.dart`, `mock_plas_repository_test.dart` | `[ ]` |
| `BB-18` | `M12` Hasil Tes (`P13`) | `MOB-FR-037`, `P13` | Selesaikan seluruh soal tes dan konfirmasi `Kumpulkan`. | Menampilkan skor, total durasi, durasi & status `Benar`/`Salah` per butir soal, nol `Pembahasan`, dan nol `Kunci Jawaban`. | `test_eval_flow_test.dart`, `live_contract_e2e_test.dart` (#3) | `[ ]` |
| `BB-19` | `M14` Riwayat & Zona WITA | `MOB-FR-017` | Buka tab `Riwayat`, filter `Semua` / `Selesai` / `Berlangsung`, cek timestamp sekitar `16:00 UTC`. | Daftar terfilter akurat dan seluruh waktu diformat ke `Asia/Makassar` (`WITA`), bukan `WIB`. | `history_profile_flow_test.dart` | `[ ]` |
| `BB-20` | `M15` Profil, `DBR-14`, & Logout | `MOB-FR-002`, `DBR-14` | Ubah kelas sebelum Pre-Test `SUBMITTED`, setelah Pre-Test `SUBMITTED` dengan `kelas != null`, serta saat `preTestSubmitted == true` namun `kelas == null` (dikeluarkan dosen / kelas dihapus), lalu tekan `Keluar Akun`. | Sebelum Pre-Test kelas bebas diubah; pasca Pre-Test `SUBMITTED` dengan `kelas != null` input/tombol terkunci (`#FFFBEB` + `Symbols.lock` + `#E2E8F0`); bila `kelas == null` mahasiswa tetap masuk ke shell (`M15`), melihat catatan gabung kembali, dan dapat bergabung kelas baru via `PATCH /me/class` lalu terkunci kembali; logout butuh konfirmasi `PlasConfirmDialog` menuju `M02`. | `history_profile_flow_test.dart`, `live_contract_e2e_test.dart` (#3), `auth_onboarding_flow_test.dart` (`BUG-003`) | `[ ]` |

---

## Bagian B: Protokol Task-Based Usability Testing & Instrumen UEQ-S (8 Item)

Sesuai `PRD MOBILE.md §12.3`, evaluasi usability dilakukan menggunakan pendekatan *task-based usability testing* diikuti pengisian kuesioner **UEQ-S (User Experience Questionnaire - Short Version)** 8 item.

### 1. Daftar Skenario Tugas Responden Mahasiswa (`UT-01` s.d. `UT-06`)

| Kode Tugas | Instruksi Singkat ke Responden | Kriteria Berhasil | Target Waktu |
|---|---|---|---|
| `UT-01` | Daftar/masuk akun, lengkapi Nama & NIM, lalu bergabung ke kelas yang ditentukan dosen. | Akun berhasil masuk ke Beranda (`M05`) dengan badge kode kelas aktif. | <= 2 menit |
| `UT-02` | Kerjakan Pre-Test dari soal pertama sampai akhir dan lihat skor hasilnya. | Pre-Test berstatus `SUBMITTED`, halaman hasil (`M12`) terbuka. | <= 10 menit |
| `UT-03` | Buka Materi 01, baca SubMateri, lalu ajukan satu pertanyaan ke asisten AI (`Tanya AI`) pada Level 1 atau 2. | Responden menemukan blok kode materi dan menerima petunjuk Socratic di `M09`. | <= 3 menit |
| `UT-04` | Selesaikan Latihan pada SubMateri hingga muncul halaman Review Latihan (`M13`). | Responden menjawab seluruh soal, menekan konfirmasi Kumpulkan, dan membaca Pembahasan Konsep. | <= 4 menit |
| `UT-05` | Buka tab `Riwayat` (`M14`), saring aktivitas `Selesai`, lalu periksa ulang salah satu riwayat latihan. | Filter `Selesai` berfungsi dan membuka kembali halaman Review `M13`. | <= 1 menit |
| `UT-06` | Buka tab `Profil` (`M15`), periksa sisa kuota AI WITA serta status penguncian kelas, lalu lakukan logout. | Responden menemukan info kuota WITA, status kelas, dan berhasil keluar ke layar login. | <= 1 menit |

**Lembar Pencatatan Tugas per Responden:**

| ID Responden | `UT-01` (S/G, dt) | `UT-02` (S/G, dt) | `UT-03` (S/G, dt) | `UT-04` (S/G, dt) | `UT-05` (S/G, dt) | `UT-06` (S/G, dt) | Catatan Kendala / Kebingungan UI |
|---|---|---|---|---|---|---|---|
| `R-01` | | | | | | | |
| `R-02` | | | | | | | |

*(Keterangan: `S` = Sukses mandiri, `G` = Gagal/Butuh bantuan, `dt` = durasi dalam detik).*

### 2. Instrumen Kuesioner UEQ-S (8 Item)

Responden menilai pengalaman setelah menyelesaikan seluruh tugas pada skala diferensial semantik **1 s.d. 7** (skor dikonversi saat analisis ke rentang `-3` s.d. `+3`):

| No. | Dimensi | Kutub Kiri (1 / -3) | 1 | 2 | 3 | 4 | 5 | 6 | 7 | Kutub Kanan (7 / +3) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | *Pragmatic Quality* | Menghambat (*obstructive*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Mendukung (*supportive*) |
| 2 | *Pragmatic Quality* | Rumit (*complicated*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Mudah (*easy*) |
| 3 | *Pragmatic Quality* | Tidak efisien (*inefficient*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Efisien (*efficient*) |
| 4 | *Pragmatic Quality* | Membingungkan (*confusing*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Jelas (*clear*) |
| 5 | *Hedonic Quality* | Membosankan (*boring*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Menarik / Seru (*exciting*) |
| 6 | *Hedonic Quality* | Tidak menarik (*not interesting*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Menarik (*interesting*) |
| 7 | *Hedonic Quality* | Konvensional (*conventional*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Berdaya cipta (*inventive*) |
| 8 | *Hedonic Quality* | Lazim / Biasa saja (*usual*) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | ( ) | Terdepan / Baru (*leading edge*) |

---

## Bagian C: Runbook & Checklist Integrasi Live (`USE_MOCK=false`)

Jalankan daftar periksa berikut ketika backend REST API Next.js dan proyek Supabase Auth sudah aktif:

### 1. Persiapan Kredensial & Perangkat Android
1. Salin `env.example.json` menjadi `env.live.json` di root `D:\01 Projects\plasmobile\` lalu isi `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan `GOOGLE_WEB_CLIENT_ID`.
2. Untuk Google Sign-In di Android, catat SHA-1 keystore debug/rilis melalui:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Daftarkan SHA-1 tersebut ke OAuth Client Android di Google Cloud Console serta pastikan Web Client ID (`GOOGLE_WEB_CLIENT_ID`) sama dengan yang dikonfigurasi di Supabase Auth Provider Google.
3. Jika menguji backend Next.js lokal via HTTP (`http://10.0.2.2:3000/api` di emulator atau IP LAN di perangkat fisik), gunakan build **debug** (`android/app/src/debug/res/xml/network_security_config.xml` mengizinkan cleartext). Untuk build **release**, wajib menggunakan HTTPS.

### 2. Perintah Eksekusi & Build Live
```bash
# Menjalankan aplikasi terhubung ke server Next.js & Supabase live
flutter run --dart-define-from-file=env.live.json

# Membangun APK rilis live (minSdk 26)
flutter build apk --release --dart-define-from-file=env.live.json
```

### 3. Checklist Verifikasi Smoke Live End-to-End
- [ ] **Startup Validation:** Jalankan `--dart-define=USE_MOCK=false` tanpa key untuk memastikan `AppEnv.missingLiveConfigKeys()` gagal cepat dengan pesan jelas; jalankan ulang dengan `--dart-define-from-file=env.live.json` dan pastikan login berhasil.
- [ ] **Auth & Onboarding (`§4.1`):** Uji Email+Sandi, Google Sign-In, `POST /me` (termasuk `409 nim_conflict` dan `409 profile_conflict`), `GET /classes`, dan `PATCH /me/class` (`kelas_id: null` maupun UUID kelas).
- [ ] **Materi & Latihan (`§4.2`-`§4.3`):** Verifikasi ke-7 materi TypeScript dari PostgreSQL, batas `3/3` attempt (`409 attempt_limit_reached`), Levenshtein FIB >= 70%, dan payload jawaban `P6` diterima tanpa `422 invalid_answer`.
- [ ] **Offline Queue Live (`P2`):** Matikan Wi-Fi/data saat menjawab & submit latihan, nyalakan kembali, tekan `Kirim Ulang Sekarang`, dan periksa tabel database tidak memiliki attempt atau jawaban ganda.
- [ ] **Pre-Test / Post-Test (`§4.4`, `DBR-14`, `DBR-15`, `P7`):** Verifikasi Pre-Test mengunci kelas di `M15` saat `kelas != null` (`409 class_locked`), tetapi tetap mengizinkan mahasiswa tanpa kelas (`kelas == null`) bergabung ke kelas baru lewat `M15` dengan riwayat nilai otomatis tersinkron; verifikasi juga resume `IN_PROGRESS` menjaga snapshot opsi dan `question_started_at`, serta Post-Test terbuka setelah seluruh latihan `SUBMITTED`.
- [ ] **AI Socratic & Kuota WITA (`§4.5`, `P12`):** Uji `POST /ai/ask` Level 1-3 ke model AI backend (timeout 35 detik), retry idempoten (`already_processed` / `request_in_progress`), batas `10/10` (`403 quota_exceeded`), dan reset `00:00 WITA`.
- [ ] **Build APK Rilis Live (`minSdk 26`):** Pasang `build/app/outputs/flutter-apk/app-release.apk` ke perangkat Android fisik/emulator API >= 26 dan lakukan satu putaran penuh alur mahasiswa tanpa error konsol.
