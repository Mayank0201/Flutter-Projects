class ContentModerator {
  // A list of severe slurs that are NEVER allowed anywhere.
  // Note: For a real app, this list should be comprehensive.
  static const List<String> _slurs = [
    'nigger',
    'faggot',
    'kike',
    'retard',
    'cunt',
    'nigga',
  ];

  // A list of general profanity that is blocked in usernames but allowed in reviews.
  static const List<String> _generalProfanity = [
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'piss',
    'dick',
    'bastard',
    'motherfucker',
    'fucker',
    'ass',
    'motherfucking',
    'fucking',
  ];

  /// Checks if the text contains any word from the provided list.
  static bool _containsWordFromList(String text, List<String> list) {
    final lowerText = text.toLowerCase();
    // Check for exact matches or matches within words to catch basic bypasses
    return list.any((word) => lowerText.contains(word));
  }

  /// Used for Usernames/Nicknames: Blocks everything.
  static String? validateUsername(String name) {
    if (name.isEmpty) return 'Name cannot be empty';

    // Normalize string: remove spaces and symbols to catch "f.u.c.k" style bypasses
    final normalized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (_containsWordFromList(normalized, _slurs) ||
        _containsWordFromList(normalized, _generalProfanity)) {
      return "Restricted language detected. Please refrain from using offensive words.";
    }
    return null;
  }

  /// Used for Reviews: Blocks only severe slurs.
  static String? validateReview(String? text) {
    if (text == null || text.isEmpty) return null;

    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (_containsWordFromList(normalized, _slurs)) {
      return "Contains offensive slurs. Please refrain from using them and be respectful.";
    }
    return null;
  }
}
