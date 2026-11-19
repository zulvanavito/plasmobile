const Duration kWitaOffset = Duration(hours: 8);

/// Returns a UTC-tagged DateTime shifted to Asia/Makassar (WITA, UTC+8)
/// wall-clock fields so date/hour calculations stay independent of device timezone.
DateTime nowInWita([DateTime? nowUtc]) {
  final baseUtc = (nowUtc ?? DateTime.now()).toUtc();
  return baseUtc.add(kWitaOffset);
}

String witaDateString([DateTime? nowUtc]) {
  final wita = nowInWita(nowUtc);
  final year = wita.year.toString().padLeft(4, '0');
  final month = wita.month.toString().padLeft(2, '0');
  final day = wita.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

Duration durationUntilNextWitaMidnight([DateTime? nowUtc]) {
  final wita = nowInWita(nowUtc);
  final nextMidnight = DateTime.utc(wita.year, wita.month, wita.day + 1);
  return nextMidnight.difference(wita);
}
