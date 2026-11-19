import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';

const String kMockConflictNim = '2115099999';

class MockSeedExerciseQuestion {
  const MockSeedExerciseQuestion({
    required this.questionId,
    required this.sequence,
    required this.questionText,
    required this.questionType,
    required this.hint,
    required this.explanation,
    this.options = const <QuestionOptionDto>[],
    this.correctOptionId,
    this.correctBoolean,
    this.correctText,
  });

  final String questionId;
  final int sequence;
  final String questionText;
  final QuestionType questionType;
  final String hint;
  final String explanation;
  final List<QuestionOptionDto> options;
  final String? correctOptionId;
  final bool? correctBoolean;
  final String? correctText;

  /// Safe DTO projection without explanation or answer keys (P13).
  ExerciseQuestionDto toExerciseQuestionDto() {
    return ExerciseQuestionDto(
      questionId: questionId,
      sequence: sequence,
      questionText: questionText,
      questionType: questionType,
      hint: hint,
      options: options,
    );
  }
}

class MockSeedMaterial {
  const MockSeedMaterial({
    required this.materialId,
    required this.sequence,
    required this.title,
    required this.description,
    required this.submaterialId,
    required this.submaterialSequence,
    required this.submaterialTitle,
    required this.contentMarkdown,
    required this.exerciseId,
    required this.exerciseTitle,
    required this.questionType,
    required this.questions,
  });

  final String materialId;
  final int sequence;
  final String title;
  final String description;
  final String submaterialId;
  final int submaterialSequence;
  final String submaterialTitle;
  final String contentMarkdown;
  final String exerciseId;
  final String exerciseTitle;
  final QuestionType questionType;
  final List<MockSeedExerciseQuestion> questions;
}

class MockSeedTestQuestion {
  const MockSeedTestQuestion({
    required this.questionId,
    required this.sequence,
    required this.questionText,
    required this.questionType,
    this.options = const <QuestionOptionDto>[],
    this.correctOptionId,
    this.correctBoolean,
    this.correctText,
  });

  final String questionId;
  final int sequence;
  final String questionText;
  final QuestionType questionType;
  final List<QuestionOptionDto> options;
  final String? correctOptionId;
  final bool? correctBoolean;
  final String? correctText;
}

class MockSeedTest {
  const MockSeedTest({
    required this.testId,
    required this.testType,
    required this.title,
    required this.questions,
  });

  final String testId;
  final TestType testType;
  final String title;
  final List<MockSeedTestQuestion> questions;
}

abstract final class MockSeedData {
  static const List<ClassInfoDto> classes = <ClassInfoDto>[
    ClassInfoDto(
      kelasId: 'kelas-ti2a-2026',
      nama: 'Pemrograman TypeScript A',
      kode: 'TI-2A-2026',
      tahunAkademik: '2026/2027',
      semester: 'Ganjil',
      dosenNama: 'Dr. Rina Kusuma, M.Kom.',
    ),
    ClassInfoDto(
      kelasId: 'kelas-ti2b-2026',
      nama: 'Pemrograman TypeScript B',
      kode: 'TI-2B-2026',
      tahunAkademik: '2026/2027',
      semester: 'Ganjil',
      dosenNama: 'Andi Pratama, M.T.',
    ),
  ];

  static const List<MockSeedMaterial> materials = <MockSeedMaterial>[
    MockSeedMaterial(
      materialId: 'mat-01',
      sequence: 1,
      title: 'Struktur Dasar Kode TypeScript',
      description:
          'Pengenalan struktur file .ts, proses kompilasi tsc, dan eksekusi dasar.',
      submaterialId: 'sub-01',
      submaterialSequence: 1,
      submaterialTitle: 'Berkas TypeScript dan Kompilasi tsc',
      contentMarkdown: '''
# Struktur Dasar Kode TypeScript

TypeScript adalah superset dari JavaScript yang menambahkan pemeriksaan tipe statis (*static typing*) sebelum kode dijalankan.

1. Berkas sumber TypeScript menggunakan ekstensi `.ts`.
2. Kompiler resmi TypeScript (`tsc`) memeriksa tipe dan mengubah kode `.ts` menjadi `.js`.
3. Pernyataan diakhiri titik koma (opsional tetapi direkomendasikan agar konsisten).

```ts
// File: halo.ts
const pesan: string = "Selamat belajar TypeScript!";
console.log(pesan);
```

Jalankan perintah `tsc halo.ts` untuk menghasilkan `halo.js` sebelum dieksekusi oleh runtime JavaScript.
''',
      exerciseId: 'ex-01',
      exerciseTitle: 'Latihan 1: Struktur Dasar TypeScript',
      questionType: QuestionType.mc,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-01-q1',
          sequence: 1,
          questionText:
              'Ekstensi berkas standar untuk kode sumber TypeScript murni (tanpa JSX) adalah ...',
          questionType: QuestionType.mc,
          hint: 'Perhatikan akhiran nama berkas pada contoh kode `halo.ts`.',
          explanation:
              'Berkas sumber TypeScript standar memakai ekstensi `.ts`, sedangkan `.tsx` dipakai khusus jika mengandung sintaks JSX.',
          options: <QuestionOptionDto>[
            QuestionOptionDto(optionId: 'ex-01-q1-opt-1', text: '.ts', sequence: 1),
            QuestionOptionDto(optionId: 'ex-01-q1-opt-2', text: '.js', sequence: 2),
            QuestionOptionDto(optionId: 'ex-01-q1-opt-3', text: '.tsx', sequence: 3),
            QuestionOptionDto(optionId: 'ex-01-q1-opt-4', text: '.json', sequence: 4),
          ],
          correctOptionId: 'ex-01-q1-opt-1',
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-01-q2',
          sequence: 2,
          questionText:
              'Perintah CLI resmi dari TypeScript untuk mengompilasi berkas `.ts` menjadi `.js` adalah ...',
          questionType: QuestionType.mc,
          hint: 'Singkatan dari TypeScript Compiler.',
          explanation:
              'Perintah `tsc` (TypeScript Compiler) melakukan pengecekan tipe dan mentranspilasi kode TypeScript menjadi JavaScript.',
          options: <QuestionOptionDto>[
            QuestionOptionDto(optionId: 'ex-01-q2-opt-1', text: 'node', sequence: 1),
            QuestionOptionDto(optionId: 'ex-01-q2-opt-2', text: 'tsc', sequence: 2),
            QuestionOptionDto(optionId: 'ex-01-q2-opt-3', text: 'npm', sequence: 3),
            QuestionOptionDto(optionId: 'ex-01-q2-opt-4', text: 'tsrun', sequence: 4),
          ],
          correctOptionId: 'ex-01-q2-opt-2',
        ),
      ],
    ),
    MockSeedMaterial(
      materialId: 'mat-02',
      sequence: 2,
      title: 'Variabel & Type Annotation',
      description:
          'Deklarasi let dan const serta penulisan anotasi tipe eksplisit.',
      submaterialId: 'sub-02',
      submaterialSequence: 1,
      submaterialTitle: 'Deklarasi let, const, dan Type Annotation',
      contentMarkdown: '''
# Variabel & Type Annotation

TypeScript mendukung `let` untuk nilai yang dapat berubah dan `const` untuk nilai tetap yang tidak dapat di-reassign. Anotasi tipe ditulis setelah nama variabel dengan tanda titik dua (`:`).

```ts
let skor: number = 80;
skor = 95;

const batasMaksimal: number = 100;
const aktif: boolean = true;
```

Gunakan `const` sebagai pilihan utama apabila referensi variabel tidak perlu diubah.
''',
      exerciseId: 'ex-02',
      exerciseTitle: 'Latihan 2: Variabel & Type Annotation',
      questionType: QuestionType.fib,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-02-q1',
          sequence: 1,
          questionText:
              'Kata kunci di TypeScript untuk mendeklarasikan variabel tetap yang tidak dapat di-reassign adalah ___',
          questionType: QuestionType.fib,
          hint: 'Kata kunci 5 huruf yang dipakai untuk nilai konstan.',
          explanation:
              '`const` membuat binding variabel bersifat tetap sehingga tidak bisa diberi nilai ulang setelah inisialisasi.',
          correctText: 'const',
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-02-q2',
          sequence: 2,
          questionText:
              'Pada deklarasi `let aktif: ___ = true;`, nama tipe data primitif yang tepat untuk mengisi bagian kosong adalah ___',
          questionType: QuestionType.fib,
          hint: 'Tipe data untuk nilai true atau false.',
          explanation:
              'Tipe `boolean` digunakan pada TypeScript untuk merepresentasikan nilai logika `true` dan `false`.',
          correctText: 'boolean',
        ),
      ],
    ),
    MockSeedMaterial(
      materialId: 'mat-03',
      sequence: 3,
      title: 'Tipe Data Dasar',
      description:
          'Memahami tipe primitif number, string, boolean, dan array.',
      submaterialId: 'sub-03',
      submaterialSequence: 1,
      submaterialTitle: 'Primitif number, string, boolean, dan Array',
      contentMarkdown: '''
# Tipe Data Dasar

TypeScript memiliki beberapa tipe data dasar yang paling sering digunakan:

- `number`: mencakup bilangan bulat maupun desimal.
- `string`: teks yang diapit tanda kutip tunggal, ganda, atau backtick.
- `boolean`: bernilai `true` atau `false`.
- `T[]` atau `Array<T>`: daftar elemen bertipe seragam.

```ts
const ipk: number = 3.85;
const nama: string = "Sari";
const nilaiList: number[] = [85, 90, 92];
```

Penetapan tipe mencegah kesalahan memasukkan angka ke variabel yang seharusnya berisi teks.
''',
      exerciseId: 'ex-03',
      exerciseTitle: 'Latihan 3: Tipe Data Dasar',
      questionType: QuestionType.tf,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-03-q1',
          sequence: 1,
          questionText:
              'Pada TypeScript, tipe data `number` digunakan untuk bilangan bulat maupun bilangan desimal.',
          questionType: QuestionType.tf,
          hint: 'Ingat bahwa TypeScript mewarisi model angka dari JavaScript.',
          explanation:
              'Benar. TypeScript tidak memisahkan `int` dan `float`; seluruh bilangan direpresentasikan oleh tipe `number`.',
          correctBoolean: true,
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-03-q2',
          sequence: 2,
          questionText:
              'Variabel bertipe `string` di TypeScript dapat langsung diisi nilai angka `42` tanpa error kompilasi.',
          questionType: QuestionType.tf,
          hint: 'Pikirkan fungsi utama pemeriksaan tipe statis pada TypeScript.',
          explanation:
              'Salah. Kompiler TypeScript akan menolak pengisian angka ke variabel bertipe `string` karena tipe tidak cocok.',
          correctBoolean: false,
        ),
      ],
    ),
    MockSeedMaterial(
      materialId: 'mat-04',
      sequence: 4,
      title: 'Operator dalam Ekspresi',
      description:
          'Operator aritmetika, perbandingan ketat, dan logika pada TypeScript.',
      submaterialId: 'sub-04',
      submaterialSequence: 1,
      submaterialTitle: 'Operator Aritmetika, Perbandingan, dan Logika',
      contentMarkdown: '''
# Operator dalam Ekspresi

Ekspresi di TypeScript menggabungkan operand dan operator:

- **Aritmetika:** `+`, `-`, `*`, `/`, `%` (sisa bagi / modulo).
- **Perbandingan ketat:** `===` dan `!==` membandingkan nilai sekaligus tipe data.
- **Logika:** `&&` (AND), `||` (OR), `!` (NOT).

```ts
const sisa: number = 10 % 3; // 1
const samaPersis: boolean = (5 === 5); // true
const lulus: boolean = (sisa === 1) && samaPersis;
```
''',
      exerciseId: 'ex-04',
      exerciseTitle: 'Latihan 4: Operator dalam Ekspresi',
      questionType: QuestionType.mc,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-04-q1',
          sequence: 1,
          questionText:
              'Operator perbandingan ketat yang memeriksa kesamaan nilai sekaligus tipe data di TypeScript adalah ...',
          questionType: QuestionType.mc,
          hint: 'Gunakan tiga tanda sama dengan untuk perbandingan ketat.',
          explanation:
              'Operator `===` membandingkan nilai dan tipe data tanpa melakukan konversi tipe otomatis (*type coercion*).',
          options: <QuestionOptionDto>[
            QuestionOptionDto(optionId: 'ex-04-q1-opt-1', text: '==', sequence: 1),
            QuestionOptionDto(optionId: 'ex-04-q1-opt-2', text: '===', sequence: 2),
            QuestionOptionDto(optionId: 'ex-04-q1-opt-3', text: '=', sequence: 3),
            QuestionOptionDto(optionId: 'ex-04-q1-opt-4', text: '!==', sequence: 4),
          ],
          correctOptionId: 'ex-04-q1-opt-2',
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-04-q2',
          sequence: 2,
          questionText:
              'Nilai hasil evaluasi ekspresi `10 % 3` dalam TypeScript adalah ...',
          questionType: QuestionType.mc,
          hint: 'Operator `%` menghitung sisa pembagian bulat.',
          explanation:
              '10 dibagi 3 menghasilkan 3 dengan sisa 1, sehingga `10 % 3` bernilai `1`.',
          options: <QuestionOptionDto>[
            QuestionOptionDto(optionId: 'ex-04-q2-opt-1', text: '0', sequence: 1),
            QuestionOptionDto(optionId: 'ex-04-q2-opt-2', text: '1', sequence: 2),
            QuestionOptionDto(optionId: 'ex-04-q2-opt-3', text: '3', sequence: 3),
            QuestionOptionDto(optionId: 'ex-04-q2-opt-4', text: '3.33', sequence: 4),
          ],
          correctOptionId: 'ex-04-q2-opt-2',
        ),
      ],
    ),
    MockSeedMaterial(
      materialId: 'mat-05',
      sequence: 5,
      title: 'Conditional',
      description:
          'Percabangan alur program menggunakan if-else dan switch-case.',
      submaterialId: 'sub-05',
      submaterialSequence: 1,
      submaterialTitle: 'Percabangan if-else dan switch',
      contentMarkdown: '''
# Conditional

Percabangan memungkinkan program memilih jalur eksekusi berdasarkan kondisi boolean.

```ts
const nilai: number = 78;

if (nilai >= 75) {
  console.log("Lulus");
} else {
  console.log("Perlu remedial");
}
```

Pada `switch`, gunakan `break` di akhir setiap `case` agar eksekusi tidak berlanjut (*fall-through*) ke `case` di bawahnya.
''',
      exerciseId: 'ex-05',
      exerciseTitle: 'Latihan 5: Conditional',
      questionType: QuestionType.tf,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-05-q1',
          sequence: 1,
          questionText:
              'Blok `else` pada struktur `if-else` hanya dijalankan ketika kondisi pada `if` bernilai `false`.',
          questionType: QuestionType.tf,
          hint: 'Blok `else` merupakan cabang alternatif jika syarat `if` tidak terpenuhi.',
          explanation:
              'Benar. Saat ekspresi kondisi `if` bernilai `false`, alur program masuk ke blok `else`.',
          correctBoolean: true,
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-05-q2',
          sequence: 2,
          questionText:
              'Pada pernyataan `switch`, menghilangkan kata kunci `break` tidak akan membuat eksekusi berlanjut ke `case` berikutnya.',
          questionType: QuestionType.tf,
          hint: 'Ingat perilaku *fall-through* pada pernyataan `switch`.',
          explanation:
              'Salah. Tanpa `break`, eksekusi akan terus berlanjut ke `case` di bawahnya hingga bertemu `break` atau akhir blok `switch`.',
          correctBoolean: false,
        ),
      ],
    ),
    MockSeedMaterial(
      materialId: 'mat-06',
      sequence: 6,
      title: 'Loop',
      description:
          'Perulangan for, while, serta pengendalian alur break dan continue.',
      submaterialId: 'sub-06',
      submaterialSequence: 1,
      submaterialTitle: 'Perulangan for, while, break, dan continue',
      contentMarkdown: '''
# Loop

Perulangan digunakan untuk menjalankan blok kode berulang kali selama kondisi terpenuhi:

- `for`: ideal ketika jumlah iterasi sudah diketahui.
- `while`: memeriksa kondisi sebelum setiap iterasi dijalankan.
- `continue`: melewati sisa kode pada iterasi sekarang dan lanjut ke iterasi berikutnya.
- `break`: menghentikan seluruh perulangan seketika.

```ts
for (let i: number = 1; i <= 5; i++) {
  if (i === 3) continue;
  console.log(i);
}
```
''',
      exerciseId: 'ex-06',
      exerciseTitle: 'Latihan 6: Loop',
      questionType: QuestionType.fib,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-06-q1',
          sequence: 1,
          questionText:
              'Kata kunci perulangan di TypeScript yang memeriksa kondisi sebelum setiap iterasi dijalankan adalah ___',
          questionType: QuestionType.fib,
          hint: 'Kata kunci 5 huruf dalam bahasa Inggris yang berarti "selama".',
          explanation:
              'Perulangan `while` mengevaluasi kondisi terlebih dahulu sebelum menjalankan blok kode di dalamnya.',
          correctText: 'while',
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-06-q2',
          sequence: 2,
          questionText:
              'Kata kunci untuk melewati sisa pernyataan pada iterasi saat ini dan langsung menuju iterasi berikutnya di dalam loop adalah ___',
          questionType: QuestionType.fib,
          hint: 'Berbeda dengan `break` yang menghentikan loop total, kata kunci ini melanjutkan ke putaran berikutnya.',
          explanation:
              '`continue` melompati sisa tubuh loop pada iterasi aktif dan langsung berpindah ke evaluasi iterasi berikutnya.',
          correctText: 'continue',
        ),
      ],
    ),
    MockSeedMaterial(
      materialId: 'mat-07',
      sequence: 7,
      title: 'Function',
      description:
          'Mendefinisikan fungsi, parameter bertipe, parameter opsional, dan return type.',
      submaterialId: 'sub-07',
      submaterialSequence: 1,
      submaterialTitle: 'Fungsi, Parameter Opsional, dan Return Type',
      contentMarkdown: '''
# Function

Fungsi di TypeScript dapat menetapkan tipe untuk setiap parameter maupun nilai kembaliannya (*return type*).

```ts
function hitungLuas(panjang: number, lebar: number): number {
  return panjang * lebar;
}

function sapa(nama?: string): void {
  console.log("Halo, " + (nama ?? "Mahasiswa"));
}
```

Tanda `?` menandakan parameter opsional, sedangkan `void` menunjukkan fungsi tidak mengembalikan nilai.
''',
      exerciseId: 'ex-07',
      exerciseTitle: 'Latihan 7: Function',
      questionType: QuestionType.mc,
      questions: <MockSeedExerciseQuestion>[
        MockSeedExerciseQuestion(
          questionId: 'ex-07-q1',
          sequence: 1,
          questionText:
              'Return type yang digunakan untuk menandakan bahwa fungsi TypeScript tidak mengembalikan nilai adalah ...',
          questionType: QuestionType.mc,
          hint: 'Lihat deklarasi fungsi `sapa` pada materi di atas.',
          explanation:
              'Tipe `void` menyatakan fungsi hanya menjalankan aksi (efek samping) tanpa mengembalikan nilai.',
          options: <QuestionOptionDto>[
            QuestionOptionDto(optionId: 'ex-07-q1-opt-1', text: 'void', sequence: 1),
            QuestionOptionDto(optionId: 'ex-07-q1-opt-2', text: 'string', sequence: 2),
            QuestionOptionDto(optionId: 'ex-07-q1-opt-3', text: 'number', sequence: 3),
            QuestionOptionDto(optionId: 'ex-07-q1-opt-4', text: 'boolean', sequence: 4),
          ],
          correctOptionId: 'ex-07-q1-opt-1',
        ),
        MockSeedExerciseQuestion(
          questionId: 'ex-07-q2',
          sequence: 2,
          questionText:
              'Simbol yang diletakkan setelah nama parameter fungsi untuk menandakan bahwa parameter tersebut opsional adalah ...',
          questionType: QuestionType.mc,
          hint: 'Simbol tanda tanya digunakan sebelum titik dua anotasi tipe.',
          explanation:
              'Menambahkan `?` setelah nama parameter (misalnya `nama?: string`) membuatnya opsional saat fungsi dipanggil.',
          options: <QuestionOptionDto>[
            QuestionOptionDto(optionId: 'ex-07-q2-opt-1', text: '!', sequence: 1),
            QuestionOptionDto(optionId: 'ex-07-q2-opt-2', text: '?', sequence: 2),
            QuestionOptionDto(optionId: 'ex-07-q2-opt-3', text: ':', sequence: 3),
            QuestionOptionDto(optionId: 'ex-07-q2-opt-4', text: '&', sequence: 4),
          ],
          correctOptionId: 'ex-07-q2-opt-2',
        ),
      ],
    ),
  ];

  static const MockSeedTest preTest = MockSeedTest(
    testId: 'test-pre-01',
    testType: TestType.pre,
    title: 'Pre-Test Pemrograman TypeScript',
    questions: <MockSeedTestQuestion>[
      MockSeedTestQuestion(
        questionId: 'pre-q1',
        sequence: 1,
        questionText:
            'Kata kunci mana yang paling tepat untuk mendeklarasikan variabel yang nilainya dapat berubah di dalam blok TypeScript?',
        questionType: QuestionType.mc,
        options: <QuestionOptionDto>[
          QuestionOptionDto(optionId: 'pre-q1-opt-1', text: 'let', sequence: 1),
          QuestionOptionDto(optionId: 'pre-q1-opt-2', text: 'const', sequence: 2),
          QuestionOptionDto(optionId: 'pre-q1-opt-3', text: 'type', sequence: 3),
          QuestionOptionDto(optionId: 'pre-q1-opt-4', text: 'void', sequence: 4),
        ],
        correctOptionId: 'pre-q1-opt-1',
      ),
      MockSeedTestQuestion(
        questionId: 'pre-q2',
        sequence: 2,
        questionText:
            'Operator logika DAN (AND) yang menghasilkan `true` hanya jika kedua kondisi bernilai `true` adalah ...',
        questionType: QuestionType.mc,
        options: <QuestionOptionDto>[
          QuestionOptionDto(optionId: 'pre-q2-opt-1', text: '||', sequence: 1),
          QuestionOptionDto(optionId: 'pre-q2-opt-2', text: '&&', sequence: 2),
          QuestionOptionDto(optionId: 'pre-q2-opt-3', text: '??', sequence: 3),
          QuestionOptionDto(optionId: 'pre-q2-opt-4', text: '!==', sequence: 4),
        ],
        correctOptionId: 'pre-q2-opt-2',
      ),
      MockSeedTestQuestion(
        questionId: 'pre-q3',
        sequence: 3,
        questionText:
            'TypeScript melakukan pemeriksaan kecocokan tipe data pada tahap kompilasi sebelum kode JavaScript dijalankan.',
        questionType: QuestionType.tf,
        correctBoolean: true,
      ),
      MockSeedTestQuestion(
        questionId: 'pre-q4',
        sequence: 4,
        questionText:
            'Nama tipe data primitif di TypeScript untuk menyimpan nilai teks adalah ___',
        questionType: QuestionType.fib,
        correctText: 'string',
      ),
      MockSeedTestQuestion(
        questionId: 'pre-q5',
        sequence: 5,
        questionText:
            'Kata kunci di dalam tubuh fungsi untuk mengirimkan nilai hasil kembali ke pemanggil fungsi adalah ___',
        questionType: QuestionType.fib,
        correctText: 'return',
      ),
    ],
  );

  static const MockSeedTest postTest = MockSeedTest(
    testId: 'test-post-01',
    testType: TestType.post,
    title: 'Post-Test Pemrograman TypeScript',
    questions: <MockSeedTestQuestion>[
      MockSeedTestQuestion(
        questionId: 'post-q1',
        sequence: 1,
        questionText:
            'Ekspresi `const hasil: boolean = (5 === 5) && (3 > 1);` menghasilkan nilai ...',
        questionType: QuestionType.mc,
        options: <QuestionOptionDto>[
          QuestionOptionDto(optionId: 'post-q1-opt-1', text: 'true', sequence: 1),
          QuestionOptionDto(optionId: 'post-q1-opt-2', text: 'false', sequence: 2),
          QuestionOptionDto(optionId: 'post-q1-opt-3', text: '5', sequence: 3),
          QuestionOptionDto(optionId: 'post-q1-opt-4', text: 'undefined', sequence: 4),
        ],
        correctOptionId: 'post-q1-opt-1',
      ),
      MockSeedTestQuestion(
        questionId: 'post-q2',
        sequence: 2,
        questionText:
            'Deklarasi fungsi `function cetak(teks?: string): void` menandakan bahwa fungsi tersebut ...',
        questionType: QuestionType.mc,
        options: <QuestionOptionDto>[
          QuestionOptionDto(
            optionId: 'post-q2-opt-1',
            text: 'Wajib menerima parameter teks dan mengembalikan string',
            sequence: 1,
          ),
          QuestionOptionDto(
            optionId: 'post-q2-opt-2',
            text: 'Memiliki parameter opsional dan tidak mengembalikan nilai',
            sequence: 2,
          ),
          QuestionOptionDto(
            optionId: 'post-q2-opt-3',
            text: 'Hanya menerima parameter number dan mengembalikan boolean',
            sequence: 3,
          ),
          QuestionOptionDto(
            optionId: 'post-q2-opt-4',
            text: 'Selalu melempar error ketika dipanggil tanpa argumen',
            sequence: 4,
          ),
        ],
        correctOptionId: 'post-q2-opt-2',
      ),
      MockSeedTestQuestion(
        questionId: 'post-q3',
        sequence: 3,
        questionText:
            'Pada percabangan `if (x > 10) { ... } else { ... }`, blok `else` tidak akan dieksekusi jika `x` bernilai `15`.',
        questionType: QuestionType.tf,
        correctBoolean: true,
      ),
      MockSeedTestQuestion(
        questionId: 'post-q4',
        sequence: 4,
        questionText:
            'Kata kunci untuk menghentikan eksekusi loop seketika sebelum kondisi selesai adalah ___',
        questionType: QuestionType.fib,
        correctText: 'break',
      ),
      MockSeedTestQuestion(
        questionId: 'post-q5',
        sequence: 5,
        questionText:
            'Tipe data primitif di TypeScript untuk nilai logika `true` atau `false` adalah ___',
        questionType: QuestionType.fib,
        correctText: 'boolean',
      ),
    ],
  );

  static ClassInfoDto? findClass(String kelasId) {
    for (final item in classes) {
      if (item.kelasId == kelasId) return item;
    }
    return null;
  }

  static MockSeedMaterial? findMaterial(String materialId) {
    for (final item in materials) {
      if (item.materialId == materialId) return item;
    }
    return null;
  }

  static MockSeedMaterial? findBySubmaterialId(String submaterialId) {
    for (final item in materials) {
      if (item.submaterialId == submaterialId) return item;
    }
    return null;
  }

  static MockSeedMaterial? findByExerciseId(String exerciseId) {
    for (final item in materials) {
      if (item.exerciseId == exerciseId) return item;
    }
    return null;
  }

  static MockSeedExerciseQuestion? findExerciseQuestion(String questionId) {
    for (final material in materials) {
      for (final question in material.questions) {
        if (question.questionId == questionId) return question;
      }
    }
    return null;
  }

  static MockSeedTest? findTest(String testId) {
    if (testId == preTest.testId) return preTest;
    if (testId == postTest.testId) return postTest;
    return null;
  }
}
