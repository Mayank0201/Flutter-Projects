import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import '../../../widgets/challenge_cleared_overlay.dart';
import '../../../theme/settings_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/audio_manager.dart';
import '../../../utils/hint_manager.dart';
import '../../../utils/rules_helper.dart';
import '../../../widgets/auto_next_countdown.dart';
class FlagleLevel {
  final String country;
  final List<String> choices;
  final Widget flagWidget;
  const FlagleLevel({
    required this.country,
    required this.choices,
    required this.flagWidget,
  });
}

// Custom painted/widget flags so we don't need external image assets
final List<FlagleLevel> _kLevels = [
  // Easy
  FlagleLevel(
    country: 'GERMANY',
    choices: ['GERMANY', 'BELGIUM', 'AUSTRIA', 'NETHERLANDS'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: Colors.black)),
        Expanded(child: Container(color: const Color(0xFFDD0000))),
        Expanded(child: Container(color: const Color(0xFFFFCC00))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'FRANCE',
    choices: ['FRANCE', 'ITALY', 'BELGIUM', 'ROMANIA'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF002395))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFED2939))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GERMANY',
    choices: ['GERMANY', 'BELGIUM', 'AUSTRIA', 'NETHERLANDS'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: Colors.black)),
        Expanded(child: Container(color: const Color(0xFFDD0000))),
        Expanded(child: Container(color: const Color(0xFFFFCC00))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ITALY',
    choices: ['ITALY', 'FRANCE', 'MEXICO', 'IRELAND'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF009246))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFCE2B37))),
      ],
    ),
  ),
  // Medium
  FlagleLevel(
    country: 'SWITZERLAND',
    choices: ['SWITZERLAND', 'DENMARK', 'NORWAY', 'SWEDEN'],
    flagWidget: Container(
      color: const Color(0xFFD80A10),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 20, height: 60, color: Colors.white),
            Container(width: 60, height: 20, color: Colors.white),
          ],
        ),
      ),
    ),
  ),
  FlagleLevel(
    country: 'SWEDEN',
    choices: ['SWEDEN', 'FINLAND', 'NORWAY', 'ICELAND'],
    flagWidget: Container(
      color: const Color(0xFF006AA7),
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.3, 0),
            child: Container(width: 24, color: const Color(0xFFFECC00)),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(height: 24, color: const Color(0xFFFECC00)),
          ),
        ],
      ),
    ),
  ),
  FlagleLevel(
    country: 'FINLAND',
    choices: ['FINLAND', 'SWEDEN', 'NORWAY', 'GREECE'],
    flagWidget: Container(
      color: Colors.white,
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.3, 0),
            child: Container(width: 24, color: const Color(0xFF003580)),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(height: 24, color: const Color(0xFF003580)),
          ),
        ],
      ),
    ),
  ),
  // Hard
  FlagleLevel(
    country: 'AUSTRIA',
    choices: ['AUSTRIA', 'LATVIA', 'PERU', 'CANADA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFED2939))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFED2939))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'UKRAINE',
    choices: ['UKRAINE', 'SWEDEN', 'COLOMBIA', 'ECUADOR'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF0057B7))),
        Expanded(child: Container(color: const Color(0xFFFFD700))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'NETHERLANDS',
    choices: ['NETHERLANDS', 'LUXEMBOURG', 'FRANCE', 'RUSSIA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFAE1C28))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF21468B))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'POLAND',
    choices: ['POLAND', 'INDONESIA', 'MONACO', 'SINGAPORE'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFDC143C))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'MONACO',
    choices: ['MONACO', 'POLAND', 'INDONESIA', 'SINGAPORE'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFDC143C))),
        Expanded(child: Container(color: Colors.white)),
      ],
    ),
  ),
  FlagleLevel(
    country: 'BELGIUM',
    choices: ['BELGIUM', 'GERMANY', 'FRANCE', 'ITALY'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: Colors.black)),
        Expanded(child: Container(color: const Color(0xFFFFE300))),
        Expanded(child: Container(color: const Color(0xFFFF0000))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'YEMEN',
    choices: ['YEMEN', 'EGYPT', 'SYRIA', 'IRAQ'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFCE1126))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: Colors.black)),
      ],
    ),
  ),
  FlagleLevel(
    country: 'COLOMBIA',
    choices: ['COLOMBIA', 'ECUADOR', 'VENEZUELA', 'ROMANIA'],
    flagWidget: Column(
      children: [
        Expanded(flex: 2, child: Container(color: const Color(0xFFFCD116))),
        Expanded(child: Container(color: const Color(0xFF003893))),
        Expanded(child: Container(color: const Color(0xFFCE1126))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'INDONESIA',
    choices: ['INDONESIA', 'MONACO', 'POLAND', 'SINGAPORE'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFCE1126))),
        Expanded(child: Container(color: Colors.white)),
      ],
    ),
  ),
  FlagleLevel(
    country: 'HUNGARY',
    choices: ['HUNGARY', 'ITALY', 'BULGARIA', 'IRAN'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFCD2A3E))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF436F4D))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SIERRA LEONE',
    choices: ['SIERRA LEONE', 'GABON', 'LESOTHO', 'UZBEKISTAN'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF1EB53A))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF0072C6))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ESTONIA',
    choices: ['ESTONIA', 'LATVIA', 'LITHUANIA', 'FINLAND'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF0072CE))),
        Expanded(child: Container(color: Colors.black)),
        Expanded(child: Container(color: Colors.white)),
      ],
    ),
  ),
  FlagleLevel(
    country: 'BULGARIA',
    choices: ['BULGARIA', 'HUNGARY', 'ITALY', 'RUSSIA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF00966E))),
        Expanded(child: Container(color: const Color(0xFFD62612))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GABON',
    choices: ['GABON', 'SIERRA LEONE', 'RWANDA', 'CONGO'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF009E60))),
        Expanded(child: Container(color: const Color(0xFFFCD116))),
        Expanded(child: Container(color: const Color(0xFF3A75C4))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'PERU',
    choices: ['PERU', 'CANADA', 'AUSTRIA', 'BELGIUM'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFFD91429))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFD91429))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'RUSSIA',
    choices: ['RUSSIA', 'SLOVAKIA', 'SLOVENIA', 'NETHERLANDS'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF0039A6))),
        Expanded(child: Container(color: const Color(0xFFD52B1E))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'LUXEMBOURG',
    choices: ['LUXEMBOURG', 'NETHERLANDS', 'FRANCE', 'RUSSIA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFEA1423))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF00A3E0))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'LITHUANIA',
    choices: ['LITHUANIA', 'LATVIA', 'ESTONIA', 'UKRAINE'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFFDB913))),
        Expanded(child: Container(color: const Color(0xFF006A44))),
        Expanded(child: Container(color: const Color(0xFFC1272D))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ROMANIA',
    choices: ['ROMANIA', 'CHAD', 'BELGIUM', 'MALI'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF002B7F))),
        Expanded(child: Container(color: const Color(0xFFFCD116))),
        Expanded(child: Container(color: const Color(0xFFCE1126))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ARMENIA',
    choices: ['ARMENIA', 'COLOMBIA', 'GERMANY', 'RUSSIA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFD90012))),
        Expanded(child: Container(color: const Color(0xFF0033A0))),
        Expanded(child: Container(color: const Color(0xFFF2A800))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'BOLIVIA',
    choices: ['BOLIVIA', 'SENEGAL', 'GHANA', 'CAMEROON'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFD52B1E))),
        Expanded(child: Container(color: const Color(0xFFF9E300))),
        Expanded(child: Container(color: const Color(0xFF007A33))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GUINEA',
    choices: ['GUINEA', 'MALI', 'SENEGAL', 'CAMEROON'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFFCE1126))),
        Expanded(child: Container(color: const Color(0xFFFCD116))),
        Expanded(child: Container(color: const Color(0xFF009639))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'IRELAND',
    choices: ['IRELAND', 'ITALY', 'FRANCE', 'IVORY COAST'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF169B62))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFFF883E))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SWEDEN',
    choices: ['SWEDEN', 'FINLAND', 'NORWAY', 'DENMARK'],
    flagWidget: Stack(
      children: [
        Container(color: const Color(0xFF006AA7)),
        Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(width: 30, color: const Color(0xFFFECC00)),
        ),
        Center(child: Container(height: 30, color: const Color(0xFFFECC00))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'FINLAND',
    choices: ['FINLAND', 'SWEDEN', 'NORWAY', 'ICELAND'],
    flagWidget: Stack(
      children: [
        Container(color: Colors.white),
        Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(width: 30, color: const Color(0xFF003580)),
        ),
        Center(child: Container(height: 30, color: const Color(0xFF003580))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'AUSTRIA',
    choices: ['AUSTRIA', 'LATVIA', 'PERU', 'CANADA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFED2939))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFED2939))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'THAILAND',
    choices: ['THAILAND', 'COSTA RICA', 'FRANCE', 'NETHERLANDS'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFA2001D))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(flex: 2, child: Container(color: const Color(0xFF0A1E3F))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFFA2001D))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SWITZERLAND',
    choices: ['SWITZERLAND', 'AUSTRIA', 'DENMARK', 'TURKEY'],
    flagWidget: Container(
      color: const Color(0xFFDA291C),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 50, height: 16, color: Colors.white),
            Container(width: 16, height: 50, color: Colors.white),
          ],
        ),
      ),
    ),
  ),
  FlagleLevel(
    country: 'UKRAINE',
    choices: ['UKRAINE', 'SWEDEN', 'ROMANIA', 'POLAND'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF0057B7))),
        Expanded(child: Container(color: const Color(0xFFFFD700))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ESTONIA',
    choices: ['ESTONIA', 'LATVIA', 'LITHUANIA', 'FINLAND'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF0072CE))),
        Expanded(child: Container(color: Colors.black)),
        Expanded(child: Container(color: Colors.white)),
      ],
    ),
  ),
  FlagleLevel(
    country: 'LITHUANIA',
    choices: ['LITHUANIA', 'ESTONIA', 'LATVIA', 'ROMANIA'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFFDB913))),
        Expanded(child: Container(color: const Color(0xFF006A44))),
        Expanded(child: Container(color: const Color(0xFFC1272D))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'EGYPT',
    choices: ['EGYPT', 'SYRIA', 'IRAQ', 'YEMEN'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFC8102E))),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: Colors.black)),
          ],
        ),
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFC5A059),
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SENEGAL',
    choices: ['SENEGAL', 'MALI', 'GUINEA', 'GHANA'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Row(
          children: [
            Expanded(child: Container(color: const Color(0xFF00A35C))),
            Expanded(child: Container(color: const Color(0xFFFCD116))),
            Expanded(child: Container(color: const Color(0xFFE31B23))),
          ],
        ),
        const Icon(Icons.star, color: Color(0xFF00A35C), size: 28),
      ],
    ),
  ),
  FlagleLevel(
    country: 'BELGIUM',
    choices: ['BELGIUM', 'GERMANY', 'FRANCE', 'NETHERLANDS'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: Colors.black)),
        Expanded(child: Container(color: const Color(0xFFFFD300))),
        Expanded(child: Container(color: const Color(0xFFEF3340))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'PALAU',
    choices: ['PALAU', 'JAPAN', 'BANGLADESH', 'MICRONESIA'],
    flagWidget: Stack(
      children: [
        Container(color: const Color(0xFF07A6DF)),
        Align(
          alignment: const Alignment(-0.2, 0),
          child: Container(
            width: 45,
            height: 45,
            decoration: const BoxDecoration(
              color: Color(0xFFFFDE00),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SOMALIA',
    choices: ['SOMALIA', 'VIETNAM', 'SURINAME', 'MOROCCO'],
    flagWidget: Container(
      color: const Color(0xFF4189DD),
      child: const Center(
        child: Icon(Icons.star, color: Colors.white, size: 36),
      ),
    ),
  ),
  FlagleLevel(
    country: 'VIETNAM',
    choices: ['VIETNAM', 'SOMALIA', 'CHINA', 'ANGOLA'],
    flagWidget: Container(
      color: const Color(0xFFDA2128),
      child: const Center(
        child: Icon(Icons.star, color: Color(0xFFFFD700), size: 36),
      ),
    ),
  ),
  FlagleLevel(
    country: 'CHILE',
    choices: ['CHILE', 'TEXAS', 'CUBA', 'LIBERIA'],
    flagWidget: Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 60,
                color: const Color(0xFF0039A6),
                child: const Center(
                  child: Icon(Icons.star, color: Colors.white, size: 20),
                ),
              ),
              Expanded(child: Container(color: Colors.white)),
            ],
          ),
        ),
        Expanded(child: Container(color: const Color(0xFFD52B1E))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'CANADA',
    choices: ['CANADA', 'PERU', 'AUSTRIA', 'SWITZERLAND'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFFD80621))),
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            child: const Center(
              child: Icon(Icons.spa, color: Color(0xFFD80621), size: 36),
            ),
          ),
        ),
        Expanded(child: Container(color: const Color(0xFFD80621))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GREENLAND',
    choices: ['GREENLAND', 'POLAND', 'MONACO', 'INDONESIA'],
    flagWidget: Stack(
      children: [
        Column(
          children: [
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFFC8102E))),
          ],
        ),
        Align(
          alignment: const Alignment(-0.4, 0),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC8102E), width: 1.5),
            ),
            child: ClipOval(
              child: Column(
                children: [
                  Expanded(child: Container(color: const Color(0xFFC8102E))),
                  Expanded(child: Container(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ICELAND',
    choices: ['ICELAND', 'NORWAY', 'SWEDEN', 'FINLAND'],
    flagWidget: Stack(
      children: [
        Container(color: const Color(0xFF002F6C)),
        Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(width: 32, color: Colors.white),
        ),
        Center(child: Container(height: 32, color: Colors.white)),
        Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(width: 16, color: const Color(0xFFDC143C)),
        ),
        Center(child: Container(height: 16, color: const Color(0xFFDC143C))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'BENIN',
    choices: ['BENIN', 'TOGO', 'GUINEA', 'MADAGASCAR'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF008751))),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: Container(color: const Color(0xFFFFD600))),
              Expanded(child: Container(color: const Color(0xFFE8112D))),
            ],
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'MADAGASCAR',
    choices: ['MADAGASCAR', 'BENIN', 'ITALY', 'OMAN'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: Colors.white)),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(child: Container(color: const Color(0xFFFC3D21))),
              Expanded(child: Container(color: const Color(0xFF007E3A))),
            ],
          ),
        ),
      ],
    ),
  ),
  // 10 new levels
  FlagleLevel(
    country: 'INDIA',
    choices: ['INDIA', 'NIGER', 'IRELAND', 'ITALY'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFFF9933))),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFF138808))),
          ],
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF000080), width: 2),
          ),
          child: const Center(
            child: Icon(Icons.brightness_5, size: 12, color: Color(0xFF000080)),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SPAIN',
    choices: ['SPAIN', 'PORTUGAL', 'ANDORRA', 'FRANCE'],
    flagWidget: Stack(
      children: [
        Column(
          children: [
            Expanded(flex: 1, child: Container(color: const Color(0xFFC60B1E))),
            Expanded(flex: 2, child: Container(color: const Color(0xFFFFC400))),
            Expanded(flex: 1, child: Container(color: const Color(0xFFC60B1E))),
          ],
        ),
        Align(
          alignment: const Alignment(-0.6, 0),
          child: Container(
            width: 16,
            height: 24,
            color: const Color(0xFFC60B1E),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'ARGENTINA',
    choices: ['ARGENTINA', 'URUGUAY', 'PARAGUAY', 'HONDURAS'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Expanded(child: Container(color: const Color(0xFF74ACDF))),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFF74ACDF))),
          ],
        ),
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFF6B426),
            shape: BoxShape.circle,
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'SUDAN',
    choices: ['SUDAN', 'PALESTINE', 'JORDAN', 'EGYPT'],
    flagWidget: Stack(
      children: [
        Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFD21034))),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: Colors.black)),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ClipPath(
            clipper: _TriangleClipper(),
            child: Container(width: 50, color: const Color(0xFF007229)),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'KUWAIT',
    choices: ['KUWAIT', 'JORDAN', 'UAE', 'SUDAN'],
    flagWidget: Stack(
      children: [
        Column(
          children: [
            Expanded(child: Container(color: const Color(0xFF128C4F))),
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFFCE1126))),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ClipPath(
            clipper: _TrapezoidClipper(),
            child: Container(width: 40, color: Colors.black),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'MAURITIUS',
    choices: ['MAURITIUS', 'SEYCHELLES', 'MADAGASCAR', 'COMOROS'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFFEA1429))),
        Expanded(child: Container(color: const Color(0xFF0020C2))),
        Expanded(child: Container(color: const Color(0xFFFFD500))),
        Expanded(child: Container(color: const Color(0xFF00A04A))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'BOTSWANA',
    choices: ['BOTSWANA', 'LESOTHO', 'NAMIBIA', 'SOUTH AFRICA'],
    flagWidget: Column(
      children: [
        Expanded(flex: 3, child: Container(color: const Color(0xFF75AADB))),
        Expanded(flex: 1, child: Container(color: Colors.white)),
        Expanded(flex: 2, child: Container(color: Colors.black)),
        Expanded(flex: 1, child: Container(color: Colors.white)),
        Expanded(flex: 3, child: Container(color: const Color(0xFF75AADB))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'CONGO',
    choices: ['CONGO', 'DR CONGO', 'GABON', 'CAMEROON'],
    flagWidget: Stack(
      children: [
        Container(color: const Color(0xFF009543)),
        ClipPath(
          clipper: _DiagonalClipper(),
          child: Container(color: const Color(0xFFFBDE4A)),
        ),
        ClipPath(
          clipper: _DiagonalTriangleClipper(),
          child: Container(color: const Color(0xFFDC241A)),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'PANAMA',
    choices: ['PANAMA', 'COSTA RICA', 'COLOMBIA', 'CUBA'],
    flagWidget: Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: const Center(
                    child: Icon(Icons.star, color: Color(0xFF072357), size: 24),
                  ),
                ),
              ),
              Expanded(child: Container(color: const Color(0xFFDA121A))),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Container(color: const Color(0xFF072357))),
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: const Center(
                    child: Icon(Icons.star, color: Color(0xFFDA121A), size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GREECE',
    choices: ['GREECE', 'CYPRUS', 'TURKEY', 'FINLAND'],
    flagWidget: Stack(
      children: [
        Column(
          children: List.generate(
            9,
            (index) => Expanded(
              child: Container(
                color: index % 2 == 0 ? const Color(0xFF0D5EAF) : Colors.white,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            width: 70,
            height: 60,
            color: const Color(0xFF0D5EAF),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 10, height: 60, color: Colors.white),
                  Container(width: 70, height: 10, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'NIGERIA',
    choices: ['NIGERIA', 'GHANA', 'CAMEROON', 'SENEGAL'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF008751))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF008751))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'LATVIA',
    choices: ['LATVIA', 'ESTONIA', 'LITHUANIA', 'AUSTRIA'],
    flagWidget: Column(
      children: [
        Expanded(flex: 2, child: Container(color: const Color(0xFF9E3039))),
        Expanded(flex: 1, child: Container(color: Colors.white)),
        Expanded(flex: 2, child: Container(color: const Color(0xFF9E3039))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'COSTA RICA',
    choices: ['COSTA RICA', 'THAILAND', 'FRANCE', 'NETHERLANDS'],
    flagWidget: Column(
      children: [
        Expanded(child: Container(color: const Color(0xFF002F6C))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(flex: 2, child: Container(color: const Color(0xFFD21034))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF002F6C))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'CZECHIA',
    choices: ['CZECHIA', 'POLAND', 'SLOVAKIA', 'PHILIPPINES'],
    flagWidget: Stack(
      children: [
        Column(
          children: [
            Expanded(child: Container(color: Colors.white)),
            Expanded(child: Container(color: const Color(0xFFD21034))),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ClipPath(
            clipper: _TriangleClipper(),
            child: Container(width: 50, color: const Color(0xFF11457E)),
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GHANA',
    choices: ['GHANA', 'SENEGAL', 'MALI', 'BENIN'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFDA291C))),
            Expanded(child: Container(color: const Color(0xFFFCD116))),
            Expanded(child: Container(color: const Color(0xFF00AA47))),
          ],
        ),
        const Icon(Icons.star, color: Colors.black, size: 28),
      ],
    ),
  ),
  FlagleLevel(
    country: 'GUATEMALA',
    choices: ['GUATEMALA', 'ARGENTINA', 'HONDURAS', 'NICARAGUA'],
    flagWidget: Row(
      children: [
        Expanded(child: Container(color: const Color(0xFF4997D0))),
        Expanded(child: Container(color: Colors.white)),
        Expanded(child: Container(color: const Color(0xFF4997D0))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'QATAR',
    choices: ['QATAR', 'BAHRAIN', 'KUWAIT', 'UAE'],
    flagWidget: Row(
      children: [
        Expanded(flex: 1, child: Container(color: Colors.white)),
        Expanded(flex: 3, child: Container(color: const Color(0xFF8A1538))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'TURKEY',
    choices: ['TURKEY', 'TUNISIA', 'EGYPT', 'ALGERIA'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Container(color: const Color(0xFFE30A17)),
        Positioned(
          left: 30,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nightlight_round, color: Colors.white, size: 40),
              SizedBox(width: 4),
              Icon(Icons.star, color: Colors.white, size: 20),
            ],
          ),
        ),
      ],
    ),
  ),
  FlagleLevel(
    country: 'NORWAY',
    choices: ['NORWAY', 'SWEDEN', 'FINLAND', 'ICELAND'],
    flagWidget: Stack(
      children: [
        Container(color: const Color(0xFFEF2B2D)),
        Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(width: 32, color: Colors.white),
        ),
        Center(child: Container(height: 32, color: Colors.white)),
        Align(
          alignment: const Alignment(-0.3, 0),
          child: Container(width: 16, color: const Color(0xFF00205B)),
        ),
        Center(child: Container(height: 16, color: const Color(0xFF00205B))),
      ],
    ),
  ),
  FlagleLevel(
    country: 'MAURITANIA',
    choices: ['MAURITANIA', 'GHANA', 'SENEGAL', 'MALI'],
    flagWidget: Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            Expanded(flex: 1, child: Container(color: const Color(0xFFD21034))),
            Expanded(flex: 4, child: Container(color: const Color(0xFF006233))),
            Expanded(flex: 1, child: Container(color: const Color(0xFFD21034))),
          ],
        ),
        Positioned(
          top: 30,
          child: Icon(Icons.star, color: const Color(0xFFFFD700), size: 24),
        ),
      ],
    ),
  ),
];

class FlagFinderScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const FlagFinderScreen({super.key, this.dailyLevelIndex});
  @override
  State<FlagFinderScreen> createState() => _FlagFinderScreenState();
}

class _FlagFinderScreenState extends State<FlagFinderScreen> {
  int _levelIndex = 0;
  late FlagleLevel _level;
  List<bool> _revealed = List.filled(6, false); // 3x2 grid of cover tiles
  final TextEditingController _guessController = TextEditingController();
  bool _gameOver = false;
  bool _won = false;
  String _message = '';
  int _guessCount = 0;

  int _hintCount = 0;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  String _failedCountry = '';

  @override
  void initState() {
    super.initState();
    _level = _kLevels[0];
    _initLevel();
  }

  @override
  void dispose() {
    _guessController.dispose();
    super.dispose();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('flagle');
    final prefs = await SharedPreferences.getInstance();
    _failedCountry = prefs.getString('failed_flagle_country') ?? '';
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
    }

    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt('level_flagle') ?? 0;
    }

    if (mounted) {
      setState(() {
        _levelIndex = targetLevel;
        _loadLevel();
      });
    }

    if (!_playDailyMode) {
      Future.delayed(Duration.zero, () async {
        if (!mounted) return;
        final savedStateStr = prefs.getString('normal_flagle_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame =
                  await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: context.textMuted.withAlpha(40),
                        ),
                      ),
                      title: Text(
                        'Continue Game?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      content: Text(
                        'We found a saved state for this level. Would you like to continue playing or start a new game?',
                        style: GoogleFonts.outfit(color: context.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx, false); // New Game
                          },
                          child: Text(
                            'New Game',
                            style: GoogleFonts.outfit(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx, true); // Continue
                          },
                          child: Text(
                            'Continue',
                            style: GoogleFonts.outfit(
                              color: AppTheme.dustyMauve,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (continueGame) {
                final int levelIndexInKLevels = data['levelIndexInKLevels'];
                final List<dynamic> revealedData = data['revealed'];
                final List<bool> loadedRevealed = List<bool>.from(revealedData);
                setState(() {
                  _level = _kLevels[levelIndexInKLevels % _kLevels.length];
                  _revealed = loadedRevealed;
                  _gameOver = data['gameOver'];
                  _won = data['won'];
                  _message = data['message'] ?? '';
                  _guessCount = data['guessCount'] ?? _revealed.where((r) => r).length;
                });
              } else {
                await _clearNormalState();
              }
            } else {
              await _clearNormalState();
            }
          } catch (_) {
            await _clearNormalState();
          }
        }
      });
    }
  }

  Future<void> _saveNormalState() async {
    if (_playDailyMode || _won) return;
    final prefs = await SharedPreferences.getInstance();
    final levelIndexInKLevels = _kLevels.indexWhere(
      (l) => l.country == _level.country,
    );
    final state = {
      'levelIndex': _levelIndex,
      'levelIndexInKLevels': levelIndexInKLevels,
      'revealed': _revealed,
      'gameOver': _gameOver,
      'won': _won,
      'message': _message,
      'guessCount': _guessCount,
    };
    await prefs.setString('normal_flagle_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_flagle_state');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_flagle', lvl);
    final earned = await HintManager.onLevelCleared('flagle');
    final newCount = await HintManager.getHints('flagle');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Hint earned! (Total: $newCount)',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.accentFor('flagle'),
        ),
      );
    }
    await _clearNormalState();
  }

  Future<void> _useHint() async {
    if (_gameOver || _hintCount <= 0) return;

    await HintManager.useHint('flagle');
    final newCount = await HintManager.getHints('flagle');

    setState(() {
      _hintCount = newCount;
      final country = _level.country;
      String hintText = '';
      if (country.length > 2) {
        hintText = country.substring(0, 2);
      } else {
        hintText = country;
      }
      _guessController.text = hintText;
      _message = 'Starts with: "$hintText..."';
      AudioManager.playClick();
    });
  }

  void _loadLevel() {
    _level = _kLevels[_levelIndex % _kLevels.length];
    if (_level.country == _failedCountry) {
      final candidates = _kLevels.where((l) => l.country != _failedCountry).toList();
      if (candidates.isNotEmpty) {
        final rng = Random();
        _level = candidates[rng.nextInt(candidates.length)];
      }
    }
    _revealed = List.filled(6, false);
    _guessController.clear();
    _gameOver = false;
    _won = false;
    _message = '';
    _guessCount = 0;
  }

  void _reset() {
    setState(() {
      if (_gameOver && !_won) {
        final currentCountry = _level.country;
        _failedCountry = currentCountry;
        SharedPreferences.getInstance().then((p) => p.setString('failed_flagle_country', currentCountry));
        final candidates = <int>[];
        for (int i = 0; i < _kLevels.length; i++) {
          if (_kLevels[i].country != currentCountry) {
            candidates.add(i);
          }
        }
        if (candidates.isNotEmpty) {
          final randIndex = (candidates..shuffle()).first;
          _level = _kLevels[randIndex];
        } else {
          _level = _kLevels[_levelIndex % _kLevels.length];
        }
      } else {
        _level = _kLevels[_levelIndex % _kLevels.length];
      }
      _revealed = List.filled(6, false);
      _guessController.clear();
      _gameOver = false;
      _won = false;
      _message = '';
      _guessCount = 0;
    });
  }

  void _makeGuess(String guess) {
    if (_gameOver) return;
    final cleanGuess = guess.trim().toUpperCase();
    if (cleanGuess.isEmpty) return;

    setState(() {
      if (cleanGuess == _level.country) {
        _won = true;
        _gameOver = true;
        _revealed = List.filled(6, true);
        _message = 'Correct! It\'s ${_level.country}';
        _guessController.clear();
        AudioManager.playSuccess();
        _savePersistedLevel(_levelIndex + 1);
        _failedCountry = '';
        SharedPreferences.getInstance().then((p) => p.remove('failed_flagle_country'));
      } else {
        _guessController.clear();
        AudioManager.playFail();
        _guessCount++;
        // Auto-reveal the next clue tile sequentially
        final nextUnrevealed = _revealed.indexWhere((r) => !r);
        if (nextUnrevealed != -1) {
          _revealed[nextUnrevealed] = true;
        }
        
        if (_guessCount >= 6) {
          _message = 'Wrong! Out of guesses. It was ${_level.country}.';
          _gameOver = true;
          _failedCountry = _level.country;
          SharedPreferences.getInstance().then((p) => p.setString('failed_flagle_country', _failedCountry));
        } else {
          _message = 'Wrong! Clue ${nextUnrevealed != -1 ? (nextUnrevealed + 1) : 6} revealed. Guesses left: ${6 - _guessCount}';
        }
      }
    });
    if (_won || _gameOver) {
      _clearNormalState();
    } else {
      _saveNormalState();
    }
  }

  void _revealTile() {
    if (_gameOver) return;
    setState(() {
      final nextUnrevealed = _revealed.indexWhere((r) => !r);
      if (nextUnrevealed != -1) {
        _revealed[nextUnrevealed] = true;
        AudioManager.playClick();
        if (_revealed.every((r) => r)) {
          _message = 'All clues revealed! Can you guess the flag?';
        }
      }
    });
    _saveNormalState();
  }

  void _nextLevel() {
    if (!_won) return;
    if (_playDailyMode) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _levelIndex = _levelIndex + 1;
      _loadLevel();
    });
  }

  Widget _buildCoverTile(int idx) {
    return IgnorePointer(
      ignoring: _revealed[idx],
      child: AnimatedOpacity(
        opacity: _revealed[idx] ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          decoration: BoxDecoration(
            color: context.bgSurface,
            border: Border.all(
              color: context.isDarkMode
                  ? Colors.black26
                  : const Color(0xFFE5E7EB),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              '${idx + 1}',
              style: GoogleFonts.outfit(
                color: context.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: context.scale(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text(
          'Flag Finder',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 20,
                  color: context.textMuted,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
                      _hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_gameOver
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'flagle',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('flagle');
                          if (mounted) setState(() => _hintCount = newCount);
                        },
                      );
                    }
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 20),
            color: context.textMuted,
            onPressed: () => RulesHelper.showRulesBottomSheet(
              context,
              'flagle',
              'Flag Finder',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _reset,
            color: context.textMuted,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}',
                style: AppTheme.numberStyle(
                  color: AppTheme.flagleSky,
                  fontSize: context.scale(13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Guess the country flag',
                        style: GoogleFonts.outfit(
                          color: context.textSecondary,
                          fontSize: context.scale(14),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Flag Container
                      Center(
                        child: Container(
                          width: context.scale(270),
                          height: context.scale(180),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: context.textMuted.withAlpha(80),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Stack(
                              children: [
                                // The actual flag
                                Positioned.fill(
                                  child: Builder(
                                    builder: (context) {
                                      Widget flagContent = _level.flagWidget;
                                      if (_playDailyMode) {
                                        if (_dailyModifierType ==
                                            'monochrome') {
                                          flagContent = ColorFiltered(
                                            colorFilter:
                                                const ColorFilter.matrix(
                                                  <double>[
                                                    0.2126,
                                                    0.7152,
                                                    0.0722,
                                                    0,
                                                    0,
                                                    0.2126,
                                                    0.7152,
                                                    0.0722,
                                                    0,
                                                    0,
                                                    0.2126,
                                                    0.7152,
                                                    0.0722,
                                                    0,
                                                    0,
                                                    0,
                                                    0,
                                                    0,
                                                    1,
                                                    0,
                                                  ],
                                                ),
                                            child: flagContent,
                                          );
                                        } else if (_dailyModifierType ==
                                            'retro') {
                                          flagContent = Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ImageFiltered(
                                                  imageFilter:
                                                      ui.ImageFilter.blur(
                                                        sigmaX: 1.8,
                                                        sigmaY: 1.8,
                                                      ),
                                                  child: flagContent,
                                                ),
                                              ),
                                              Positioned.fill(
                                                child: CustomPaint(
                                                  painter:
                                                      _RetroPixelGridPainter(),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else if (_dailyModifierType ==
                                            'zoom') {
                                          flagContent = Center(
                                            child: ClipOval(
                                              child: SizedBox(
                                                width: 150,
                                                height: 150,
                                                child: Transform.scale(
                                                  scale: 3.0,
                                                  child: flagContent,
                                                ),
                                              ),
                                            ),
                                          );
                                        } else if (_dailyModifierType ==
                                            'prism') {
                                          flagContent = ColorFiltered(
                                            colorFilter: const ColorFilter.matrix(
                                              <double>[
                                                -1.0, 0.0, 0.0, 0.0, 255.0,
                                                0.0, -1.0, 0.0, 0.0, 255.0,
                                                0.0, 0.0, -1.0, 0.0, 255.0,
                                                0.0, 0.0, 0.0, 1.0, 0.0,
                                              ],
                                            ),
                                            child: flagContent,
                                          );
                                        }
                                      }
                                      return flagContent;
                                    },
                                  ),
                                ),
                                // Covering tiles (3 cols, 2 rows) - keyed to avoid flash on transition
                                Positioned.fill(
                                  key: ValueKey('covers_$_levelIndex'),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(child: _buildCoverTile(0)),
                                            Expanded(child: _buildCoverTile(1)),
                                            Expanded(child: _buildCoverTile(2)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(child: _buildCoverTile(3)),
                                            Expanded(child: _buildCoverTile(4)),
                                            Expanded(child: _buildCoverTile(5)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_message.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            _message,
                            style: GoogleFonts.outfit(
                              color: _won
                                  ? AppTheme.flagleSky
                                  : Colors.redAccent,
                              fontWeight: FontWeight.w600,
                              fontSize: context.scale(15),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      Text(
                        'Clues revealed: ${_revealed.where((r) => r).length}/6',
                        style: GoogleFonts.outfit(
                          color: context.textSecondary,
                          fontSize: context.scale(13),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Choices or Action
                      if (!_gameOver) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _guessController,
                                  style: GoogleFonts.outfit(
                                    color: context.textPrimary,
                                    fontSize: context.scale(14),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Type country name...',
                                    hintStyle: GoogleFonts.outfit(
                                      color: context.textMuted,
                                      fontSize: context.scale(14),
                                    ),
                                    filled: true,
                                    fillColor: context.bgCard,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: context.textMuted.withAlpha(40),
                                        width: 0.8,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: AppTheme.flagleSky,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: _makeGuess,
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.flagleSky,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () =>
                                    _makeGuess(_guessController.text),
                                child: Text(
                                  'Guess',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: context.scale(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextButton.icon(
                          onPressed: _revealed.every((r) => r)
                              ? null
                              : _revealTile,
                          icon: Icon(
                            Icons.help_outline,
                            size: context.scale(18),
                            color: context.textMuted,
                          ),
                          label: Text(
                            'Next Clue',
                            style: GoogleFonts.outfit(
                              color: context.textMuted,
                              fontSize: context.scale(13),
                            ),
                          ),
                        ),
                      ] else ...[
                        if (_won)
                          _playDailyMode
                              ? const SizedBox.shrink()
                              : AutoNextCountdown(
                                  onNext: _nextLevel,
                                  accentColor: AppTheme.flagleSky,
                                ),
                        if (!_won)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.flagleSky,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _reset,
                            child: Text(
                              'Try Again',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                fontSize: context.scale(14),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_won && _playDailyMode)
              Positioned.fill(
                child: ChallengeClearedOverlay(
                  accentColor: AppTheme.flagleSky,
                  onComplete: () {
                    Navigator.pop(context, true);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RetroPixelGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
        stops: const [0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TrapezoidClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.7, size.height / 2);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width * 0.35, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.65, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DiagonalTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.65, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
