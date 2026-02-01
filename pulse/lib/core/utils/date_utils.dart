/// This file contains utility functions for working with dates.

class DateUtils {
  /// Formats a [DateTime] object into a readable string.
  static String formatDate(DateTime date) {
    return '${date.day}-${date.month}-${date.year}';
  }

  /// Checks if two [DateTime] objects represent the same day.
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
