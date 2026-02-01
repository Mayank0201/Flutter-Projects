/// This file contains utility functions for generating unique IDs.

import 'package:uuid/uuid.dart';

class IdGenerator {
  /// Generates a unique ID using the UUID package.
  static String generateId() {
    return const Uuid().v4();
  }
}
