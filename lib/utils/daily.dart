/// Today's date as text, for example 2026-10-12.
/// It is the document id of the shared daily quiz.
String todayKey() {
  final n = DateTime.now();
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '${n.year}-$m-$d';
}