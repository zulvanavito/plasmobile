class ClassInfoDto {
  const ClassInfoDto({
    required this.kelasId,
    required this.nama,
    required this.kode,
    required this.tahunAkademik,
    required this.semester,
    this.dosenNama,
  });

  final String kelasId;
  final String nama;
  final String kode;
  final String tahunAkademik;
  final String semester;
  final String? dosenNama;

  factory ClassInfoDto.fromJson(Map<String, dynamic> json) {
    return ClassInfoDto(
      kelasId: json['kelas_id'] as String,
      nama: json['nama'] as String,
      kode: json['kode'] as String,
      tahunAkademik: json['tahun_akademik'] as String,
      semester: json['semester'] as String,
      dosenNama: json['dosen_nama'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kelas_id': kelasId,
      'nama': nama,
      'kode': kode,
      'tahun_akademik': tahunAkademik,
      'semester': semester,
      'dosen_nama': dosenNama,
    };
  }
}

class StudentProfileDto {
  const StudentProfileDto({
    required this.mahasiswaId,
    required this.nama,
    required this.nim,
    this.kelas,
    required this.preTestSubmitted,
    required this.remainingAiQuota,
  });

  final String mahasiswaId;
  final String nama;
  final String nim;
  final ClassInfoDto? kelas;
  final bool preTestSubmitted;
  final int remainingAiQuota;

  factory StudentProfileDto.fromJson(Map<String, dynamic> json) {
    final rawKelas = json['kelas'];
    return StudentProfileDto(
      mahasiswaId: json['mahasiswa_id'] as String,
      nama: json['nama'] as String,
      nim: json['nim'] as String,
      kelas: rawKelas is Map
          ? ClassInfoDto.fromJson(Map<String, dynamic>.from(rawKelas))
          : null,
      preTestSubmitted: json['pre_test_submitted'] as bool,
      remainingAiQuota: (json['remaining_ai_quota'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mahasiswa_id': mahasiswaId,
      'nama': nama,
      'nim': nim,
      'kelas': kelas?.toJson(),
      'pre_test_submitted': preTestSubmitted,
      'remaining_ai_quota': remainingAiQuota,
    };
  }

  StudentProfileDto copyWith({
    String? nama,
    String? nim,
    ClassInfoDto? kelas,
    bool clearKelas = false,
    bool? preTestSubmitted,
    int? remainingAiQuota,
  }) {
    return StudentProfileDto(
      mahasiswaId: mahasiswaId,
      nama: nama ?? this.nama,
      nim: nim ?? this.nim,
      kelas: clearKelas ? null : (kelas ?? this.kelas),
      preTestSubmitted: preTestSubmitted ?? this.preTestSubmitted,
      remainingAiQuota: remainingAiQuota ?? this.remainingAiQuota,
    );
  }
}

class CreateProfileRequest {
  const CreateProfileRequest({
    required this.nama,
    required this.nim,
    this.kelasId,
  });

  final String nama;
  final String nim;
  final String? kelasId;

  factory CreateProfileRequest.fromJson(Map<String, dynamic> json) {
    return CreateProfileRequest(
      nama: json['nama'] as String,
      nim: json['nim'] as String,
      kelasId: json['kelas_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'nama': nama,
      'nim': nim,
      'kelas_id': kelasId,
    };
  }
}
