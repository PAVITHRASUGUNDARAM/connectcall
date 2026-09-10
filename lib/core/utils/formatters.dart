import 'package:intl/intl.dart';

String formatCallDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String formatCallWhen(DateTime time) {
  final now = DateTime.now();
  final local = time.toLocal();
  if (now.year == local.year && now.month == local.month && now.day == local.day) {
    return DateFormat.jm().format(local);
  }
  if (now.difference(local).inDays < 7) {
    return DateFormat.E().add_jm().format(local);
  }
  return DateFormat.MMMd().add_jm().format(local);
}
