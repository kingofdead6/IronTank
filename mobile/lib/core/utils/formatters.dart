import 'package:intl/intl.dart';

/// Display formatting for durations, dates and counts.
abstract final class Fmt {
  /// Timer style: "1:02:05" or "12:05".
  static String clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes.remainder(60)}:$s';
  }

  /// Compact: "1h 05m", "42m", "35s".
  static String duration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  static String dayMonth(DateTime d) => DateFormat.MMMd().format(d.toLocal());
  static String weekdayDayMonth(DateTime d) => DateFormat('EEE, MMM d').format(d.toLocal());
  static String fullDate(DateTime d) => DateFormat.yMMMd().format(d.toLocal());
  static String time(DateTime d) => DateFormat.jm().format(d.toLocal());

  /// Local calendar day as the API expects it (YYYY-MM-DD).
  static String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// "Today", "Yesterday", "3 days ago", else a date.
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = DateTime.now();
    final ref = now ?? today;
    final a = DateTime(ref.year, ref.month, ref.day);
    final b = DateTime(d.toLocal().year, d.toLocal().month, d.toLocal().day);
    final diff = a.difference(b).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return '$diff days ago';
    return dayMonth(d);
  }

  static String integer(num n) => NumberFormat.decimalPattern().format(n.round());

  /// "1 day", "3 days"; pass [plural] for irregular words.
  static String count(int n, String singular, [String? plural]) => '$n ${n == 1 ? singular : (plural ?? '${singular}s')}';

  /// Time-of-day greeting.
  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 5) return 'Late session';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }
}
