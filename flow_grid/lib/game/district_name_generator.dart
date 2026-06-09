import 'dart:math';
import '../models/district_profile.dart';

class DistrictNameGenerator {
  static final _random = Random();

  static final _industrialPrefixes = ['Iron', 'Steel', 'Forge', 'Coal', 'Motor', 'Rust', 'Gear', 'Smoke'];
  static final _industrialSuffixes = ['Works', 'Yards', 'Basin', 'Point', 'District', 'Sector'];

  static final _commercialPrefixes = ['Market', 'Grand', 'Mid', 'Harbor', 'Plaza', 'Neon', 'Diamond', 'Pearl'];
  static final _commercialSuffixes = ['Square', 'Town', 'Center', 'Avenue', 'Market', 'Mall'];

  static final _techPrefixes = ['Silicon', 'Cyber', 'Quantum', 'Nexus', 'Aero', 'Nova', 'Echo', 'Zenith'];
  static final _techSuffixes = ['Valley', 'Park', 'Labs', 'Hub', 'Campus', 'Ridge'];

  static final _residentialPrefixes = ['Oak', 'Maple', 'Pine', 'Sun', 'River', 'Green', 'Pleasant', 'Shady'];
  static final _residentialSuffixes = ['Heights', 'Hills', 'View', 'Woods', 'Brook', 'Meadow', 'Grove'];

  static String generate(DistrictType type) {
    List<String> prefixes;
    List<String> suffixes;

    switch (type) {
      case DistrictType.industrial:
        prefixes = _industrialPrefixes;
        suffixes = _industrialSuffixes;
        break;
      case DistrictType.commercial:
        prefixes = _commercialPrefixes;
        suffixes = _commercialSuffixes;
        break;
      case DistrictType.tech:
        prefixes = _techPrefixes;
        suffixes = _techSuffixes;
        break;
      case DistrictType.residential:
        prefixes = _residentialPrefixes;
        suffixes = _residentialSuffixes;
        break;
    }

    final prefix = prefixes[_random.nextInt(prefixes.length)];
    final suffix = suffixes[_random.nextInt(suffixes.length)];
    return '$prefix $suffix';
  }
}
