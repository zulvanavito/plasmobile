abstract final class ApiErrorCodes {
  static const String validationError = 'validation_error';
  static const String unauthorized = 'unauthorized';
  static const String forbidden = 'forbidden';
  static const String quotaExceeded = 'quota_exceeded';
  static const String notFound = 'not_found';
  static const String profileNotFound = 'profile_not_found';
  static const String idempotencyConflict = 'idempotency_conflict';
  static const String nimConflict = 'nim_conflict';
  static const String profileConflict = 'profile_conflict';
  static const String classLocked = 'class_locked';
  static const String prerequisiteNotMet = 'prerequisite_not_met';
  static const String attemptExists = 'attempt_exists';
  static const String attemptLimitReached = 'attempt_limit_reached';
  static const String attemptSubmitted = 'attempt_submitted';
  static const String alreadyAnswered = 'already_answered';
  static const String alreadySubmitted = 'already_submitted';
  static const String wrongSequence = 'wrong_sequence';
  static const String incompleteAnswers = 'incomplete_answers';
  static const String invalidStateTransition = 'invalid_state_transition';
  static const String requestInProgress = 'request_in_progress';
  static const String invalidAnswer = 'invalid_answer';
  static const String invalidOption = 'invalid_option';
  static const String typeMismatch = 'type_mismatch';
  static const String optionNotMc = 'option_not_mc';
  static const String testEmpty = 'test_empty';
  static const String aiServiceError = 'ai_service_error';
  static const String aiTimeout = 'ai_timeout';
  static const String networkOffline = 'network_offline';
  static const String serverError = 'server_error';

  static const Map<String, String> messages = {
    validationError: 'Data yang dikirim tidak valid. Periksa kembali isian Anda.',
    unauthorized: 'Sesi login Anda telah berakhir. Silakan masuk kembali.',
    forbidden: 'Akun Anda tidak memiliki izin untuk mengakses fitur ini.',
    quotaExceeded:
        'Kuota harian 10 permintaan AI telah habis (0/10). Kuota direset otomatis pukul 00:00 WITA.',
    notFound: 'Data yang diminta tidak ditemukan.',
    profileNotFound: 'Profil mahasiswa belum dilengkapi.',
    idempotencyConflict:
        'Permintaan gagal diproses karena konflik kunci idempotensi dengan data berbeda.',
    nimConflict:
        'NIM tersebut telah terdaftar pada akun mahasiswa lain. Periksa kembali NIM Anda.',
    profileConflict:
        'Akun ini sudah terdaftar dengan peran lain dan tidak dapat digunakan sebagai akun mahasiswa.',
    classLocked:
        'Kelas tidak dapat diubah karena Pre-test Anda telah dikumpulkan (SUBMITTED).',
    prerequisiteNotMet:
        'Post-test belum dapat dimulai. Selesaikan seluruh latihan wajib pada 7 materi terlebih dahulu.',
    attemptExists: 'Anda sudah memiliki sesi pengerjaan untuk tes ini.',
    attemptLimitReached:
        'Batas maksimal 3/3 percobaan latihan pada SubMateri ini telah tercapai. Anda tetap dapat meninjau riwayat attempt sebelumnya.',
    attemptSubmitted:
        'Sesi ini sudah dikumpulkan sebelumnya dan tidak dapat diubah lagi.',
    alreadyAnswered: 'Soal ini sudah dijawab sebelumnya.',
    alreadySubmitted: 'Percobaan ini sudah dikumpulkan sebelumnya.',
    wrongSequence: 'Soal harus dikerjakan secara berurutan sesuai sesi tes.',
    incompleteAnswers:
        'Masih ada soal yang belum dijawab. Lengkapi semua soal sebelum mengumpulkan.',
    invalidStateTransition:
        'Perubahan status sesi tidak valid. Muat ulang halaman untuk sinkronisasi.',
    requestInProgress:
        'Permintaan sebelumnya masih diproses. Tunggu sebentar sebelum mencoba lagi.',
    invalidAnswer:
        'Format jawaban tidak sesuai ketentuan atau melebihi batas 255 karakter.',
    invalidOption: 'Pilihan jawaban tidak ditemukan pada soal ini.',
    typeMismatch: 'Tipe soal dan format jawaban tidak sesuai.',
    optionNotMc: 'Opsi jawaban hanya berlaku untuk soal pilihan ganda.',
    testEmpty: 'Instrumen tes belum memiliki daftar soal yang tersedia.',
    aiServiceError:
        'Layanan AI sedang tidak dapat dijangkau. Kuota harian Anda tidak dikurangi; silakan coba lagi.',
    aiTimeout:
        'Layanan AI sedang tidak dapat dijangkau. Kuota harian Anda tidak dikurangi; silakan coba lagi.',
    networkOffline:
        'Koneksi terputus. Jawaban tersimpan sementara dengan kunci idempotensi aman dan siap dikirim ulang.',
    serverError:
        'Terjadi gangguan pada server. Silakan coba beberapa saat lagi.',
  };
}

String plasErrorMessage(String code, {String? fallback}) {
  final mapped = ApiErrorCodes.messages[code];
  if (mapped != null) return mapped;
  if (fallback != null && fallback.trim().isNotEmpty) return fallback.trim();
  return ApiErrorCodes.messages[ApiErrorCodes.serverError]!;
}
