import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cogniq/widgets/buy_hints_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import'../../../utils/rules_helper.dart';
import'../../../theme/app_theme.dart';
import'../../../utils/hint_manager.dart';
import'../../../utils/audio_manager.dart';
import '../../../widgets/auto_next_countdown.dart';
import '../../../widgets/challenge_cleared_overlay.dart';

class WordBuilderLevel {
  final List<String> letters;
  final int targetCount;
  final Set<String> validWords;
  const WordBuilderLevel({required this.letters, required this.targetCount, required this.validWords});
}

const List<WordBuilderLevel> _kLevels = [
  // Easy
  WordBuilderLevel(
    letters: ['A', 'E', 'T'],
    targetCount: 2,
    validWords: {'AET', 'ATE', 'EAT', 'TAE', 'TEA'},
  ),
  WordBuilderLevel(
    letters: ['O', 'P', 'T', 'S'],
    targetCount: 3,
    validWords: {'OPTS', 'POS', 'POST', 'POT', 'POTS', 'SOP', 'SOT', 'SPOT', 'STOP', 'TOP', 'TOPS'},
  ),
  WordBuilderLevel(
    letters: ['A', 'R', 'T', 'S'],
    targetCount: 4,
    validWords: {'ARS', 'ART', 'ARTS', 'ASTR', 'RAS', 'RAT', 'RATS', 'SAR', 'SART', 'SAT', 'STAR', 'STRA', 'TAR', 'TARS', 'TAS', 'TRA', 'TSAR'},
  ),
  WordBuilderLevel(
    letters: ['O', 'D', 'G', 'S'],
    targetCount: 4,
    validWords: {'DOG', 'DOGS', 'DOS', 'GOD', 'GODS', 'SOD'},
  ),
  // Medium
  WordBuilderLevel(
    letters: ['E', 'I', 'N', 'S', 'T'],
    targetCount: 5,
    validWords: {'INSET', 'INST', 'ISNT', 'ITEN', 'ITS', 'NEI', 'NEIST', 'NEST', 'NET', 'NETI', 'NETS', 'NIES', 'NIS', 'NIST', 'NIT', 'NITS', 'SEIT', 'SENIT', 'SENT', 'SENTI', 'SET', 'SIE', 'SINE', 'SIT', 'SITE', 'SNIT', 'SNITE', 'STEIN', 'STEN', 'STINE', 'TENS', 'TIE', 'TIEN', 'TIENS', 'TIES', 'TINE', 'TINES', 'TINS', 'TSINE'},
  ),
  WordBuilderLevel(
    letters: ['A', 'C', 'E', 'R', 'S'],
    targetCount: 6,
    validWords: {'ACE', 'ACER', 'ACES', 'ACRE', 'ACRES', 'AER', 'AES', 'AESC', 'ARC', 'ARCES', 'ARCS', 'ARE', 'ARES', 'ARS', 'ARSE', 'ASE', 'CAR', 'CARE', 'CARES', 'CARS', 'CARSE', 'CASE', 'CASER', 'CERA', 'CERAS', 'CESAR', 'CRE', 'CREA', 'CRES', 'EAR', 'EARS', 'ERA', 'ERAS', 'ESCA', 'ESCAR', 'RACE', 'RACES', 'RAS', 'RASE', 'REA', 'REC', 'RECS', 'RES', 'SAC', 'SACRE', 'SAR', 'SARE', 'SCAR', 'SCARE', 'SCARS', 'SCRAE', 'SEA', 'SEAR', 'SERA', 'SERAC', 'SRAC'},
  ),
  WordBuilderLevel(
    letters: ['E', 'D', 'N', 'S'],
    targetCount: 4,
    validWords: {'DEN', 'DENS', 'DES', 'END', 'ENDS', 'NED', 'SEND', 'SNED'},
  ),
  // Hard
  WordBuilderLevel(
    letters: ['E', 'A', 'P', 'R', 'S'],
    targetCount: 6,
    validWords: {'AER', 'AES', 'APE', 'APER', 'APERS', 'APES', 'APRES', 'APSE', 'ARE', 'ARES', 'ARS', 'ARSE', 'ASE', 'ASP', 'ASPER', 'EAR', 'EARS', 'ERA', 'ERAS', 'PAR', 'PARE', 'PARES', 'PARS', 'PARSE', 'PAS', 'PASE', 'PEA', 'PEAR', 'PEARS', 'PEAS', 'PER', 'PERS', 'PES', 'PESA', 'PRASE', 'PRE', 'PRES', 'PRESA', 'RAP', 'RAPE', 'RAPES', 'RAPS', 'RAS', 'RASE', 'RASP', 'REA', 'REAP', 'REAPS', 'REPAS', 'REPS', 'RES', 'RESP', 'SAP', 'SAR', 'SARE', 'SEA', 'SEAR', 'SERA', 'SPA', 'SPAE', 'SPAER', 'SPAR', 'SPARE', 'SPEAR'},
  ),
  WordBuilderLevel(
    letters: ['I', 'N', 'G', 'S', 'T'],
    targetCount: 6,
    validWords: {'GIN', 'GINS', 'GIS', 'GIST', 'GIT', 'GITS', 'INST', 'ISNT', 'ITS', 'NIG', 'NIS', 'NIST', 'NIT', 'NITS', 'SIGN', 'SING', 'SIT', 'SNIG', 'SNIT', 'STING', 'TING', 'TINGS', 'TINS'},
  ),
  WordBuilderLevel(
    letters: ['E', 'L', 'A', 'T', 'S'],
    targetCount: 7,
    validWords: {'AES', 'AET', 'ALE', 'ALES', 'ALS', 'ALT', 'ALTS', 'ASE', 'ASTEL', 'ATE', 'ATES', 'ATLE', 'EAST', 'EAT', 'EATS', 'ELA', 'ELS', 'ELSA', 'ETAS', 'LAET', 'LAS', 'LASE', 'LAST', 'LAT', 'LATE', 'LATS', 'LEA', 'LEAS', 'LEAST', 'LEAT', 'LEST', 'LET', 'LETS', 'SAL', 'SALE', 'SALET', 'SALT', 'SAT', 'SATE', 'SEA', 'SEAL', 'SEAT', 'SELT', 'SET', 'SETA', 'SETAL', 'SLAE', 'SLAT', 'SLATE', 'STALE', 'STEAL', 'STELA', 'TAE', 'TAEL', 'TAELS', 'TAL', 'TALE', 'TALES', 'TAS', 'TEA', 'TEAL', 'TEALS', 'TEAS', 'TEL', 'TELA', 'TESLA'},
  ),
  // Expansions
  WordBuilderLevel(
    letters: ['P', 'I', 'N'],
    targetCount: 2,
    validWords: {'IN', 'NIP', 'PI', 'PIN'},
  ),
  WordBuilderLevel(
    letters: ['K', 'I', 'N', 'G'],
    targetCount: 3,
    validWords: {'GIN', 'GINK', 'INK', 'KIN', 'KING', 'NIG'},
  ),
  WordBuilderLevel(
    letters: ['M', 'A', 'T', 'E'],
    targetCount: 4,
    validWords: {'AET', 'AME', 'ATE', 'ATM', 'EAT', 'MAE', 'MAT', 'MATE', 'MEA', 'MEAT', 'MET', 'META', 'TAE', 'TAM', 'TAME', 'TEA', 'TEAM', 'TEMA'},
  ),
  WordBuilderLevel(
    letters: ['C', 'L', 'A', 'Y', 'S'],
    targetCount: 5,
    validWords: {'ACLYS', 'ACY', 'ACYL', 'ACYLS', 'ALC', 'ALS', 'ALY', 'AYS', 'CAL', 'CALS', 'CAY', 'CAYS', 'CLAY', 'CLAYS', 'LAC', 'LACS', 'LACY', 'LAS', 'LAY', 'LAYS', 'LYAS', 'SAC', 'SAL', 'SAY', 'SCALY', 'SLAY', 'SLY'},
  ),
  WordBuilderLevel(
    letters: ['B', 'R', 'E', 'A', 'D'],
    targetCount: 6,
    validWords: {'ABD', 'ABE', 'ABED', 'ADE', 'AER', 'ARB', 'ARDEB', 'ARE', 'ARED', 'BAD', 'BADE', 'BAE', 'BAR', 'BARD', 'BARDE', 'BARE', 'BARED', 'BEA', 'BEAD', 'BEAR', 'BEARD', 'BED', 'BER', 'BRA', 'BRAD', 'BRAE', 'BREAD', 'BRED', 'DAB', 'DAE', 'DAER', 'DAR', 'DARB', 'DARE', 'DEA', 'DEAR', 'DEB', 'DEBAR', 'DER', 'DRAB', 'EAR', 'ERA', 'RAB', 'RAD', 'REA', 'READ', 'REB', 'RED'},
  ),
  WordBuilderLevel(
    letters: ['C', 'A', 'T'],
    targetCount: 2,
    validWords: {'ACT', 'CAT'},
  ),
  WordBuilderLevel(
    letters: ['D', 'O', 'G'],
    targetCount: 2,
    validWords: {'DOG', 'GOD'},
  ),
  WordBuilderLevel(
    letters: ['A', 'R', 'T'],
    targetCount: 3,
    validWords: {'ART', 'RAT', 'TAR', 'TRA'},
  ),
  WordBuilderLevel(
    letters: ['E', 'A', 'R'],
    targetCount: 3,
    validWords: {'AER', 'ARE', 'EAR', 'ERA', 'REA'},
  ),
  WordBuilderLevel(
    letters: ['P', 'O', 'T', 'S'],
    targetCount: 4,
    validWords: {'OPTS', 'POS', 'POST', 'POT', 'POTS', 'SOP', 'SOT', 'SPOT', 'STOP', 'TOP', 'TOPS'},
  ),
  WordBuilderLevel(
    letters: ['R', 'A', 'T', 'S'],
    targetCount: 4,
    validWords: {'ARS', 'ART', 'ARTS', 'ASTR', 'RAS', 'RAT', 'RATS', 'SAR', 'SART', 'SAT', 'STAR', 'STRA', 'TAR', 'TARS', 'TAS', 'TRA', 'TSAR'},
  ),
  WordBuilderLevel(
    letters: ['N', 'O', 'T', 'E'],
    targetCount: 4,
    validWords: {'EON', 'ETON', 'NEO', 'NET', 'NOT', 'NOTE', 'ONE', 'TOE', 'TON', 'TONE'},
  ),
  WordBuilderLevel(
    letters: ['P', 'I', 'N', 'E'],
    targetCount: 4,
    validWords: {'EPI', 'NEI', 'NEP', 'NIP', 'PEIN', 'PEN', 'PIE', 'PIEN', 'PIN', 'PINE'},
  ),
  WordBuilderLevel(
    letters: ['R', 'O', 'S', 'E'],
    targetCount: 4,
    validWords: {'EROS', 'ORE', 'ORES', 'OSE', 'RES', 'ROE', 'ROES', 'ROS', 'ROSE', 'SEOR', 'SERO', 'SORE'},
  ),
  WordBuilderLevel(
    letters: ['S', 'P', 'I', 'N'],
    targetCount: 4,
    validWords: {'INSP', 'NIP', 'NIPS', 'NIS', 'PIN', 'PINS', 'PIS', 'PSI', 'SNIP', 'SPIN'},
  ),
  WordBuilderLevel(
    letters: ['L', 'I', 'O', 'N'],
    targetCount: 4,
    validWords: {'INO', 'ION', 'LIN', 'LINO', 'LION', 'LOIN', 'NIL', 'NOIL', 'NOL', 'OIL'},
  ),
  WordBuilderLevel(
    letters: ['P', 'E', 'A', 'R'],
    targetCount: 5,
    validWords: {'AER', 'APE', 'APER', 'ARE', 'EAR', 'ERA', 'PAR', 'PARE', 'PEA', 'PEAR', 'PER', 'PRE', 'RAP', 'RAPE', 'REA', 'REAP'},
  ),
  WordBuilderLevel(
    letters: ['S', 'M', 'A', 'R', 'T'],
    targetCount: 6,
    validWords: {'ARM', 'ARMS', 'ARS', 'ART', 'ARTS', 'ASTR', 'ATM', 'MAR', 'MARS', 'MART', 'MARTS', 'MAS', 'MAST', 'MAT', 'MATS', 'MRS', 'RAM', 'RAMS', 'RAS', 'RAT', 'RATS', 'SAM', 'SAR', 'SART', 'SAT', 'SMART', 'STAM', 'STAR', 'STRA', 'STRAM', 'TAM', 'TAMS', 'TAR', 'TARS', 'TAS', 'TRA', 'TRAM', 'TRAMS', 'TSAR'},
  ),
  WordBuilderLevel(
    letters: ['F', 'L', 'O', 'W', 'S'],
    targetCount: 6,
    validWords: {'FLO', 'FLOW', 'FLOWS', 'FOL', 'FOW', 'FOWL', 'FOWLS', 'LOF', 'LOW', 'LOWS', 'OWL', 'OWLS', 'SLOW', 'SOL', 'SOW', 'SOWF', 'SOWL', 'WOLF', 'WOLFS'},
  ),
  WordBuilderLevel(
    letters: ['C', 'R', 'A', 'B', 'S'],
    targetCount: 6,
    validWords: {'ABC', 'ABS', 'ARB', 'ARBS', 'ARC', 'ARCS', 'ARS', 'BAC', 'BAR', 'BARS', 'BAS', 'BRA', 'BRAS', 'CAB', 'CABS', 'CAR', 'CARS', 'CRAB', 'CRABS', 'RAB', 'RAS', 'SAC', 'SAR', 'SCAB', 'SCAR', 'SCRAB', 'SRAC'},
  ),
  WordBuilderLevel(
    letters: ['P', 'E', 'A', 'C', 'H'],
    targetCount: 5,
    validWords: {'ACE', 'ACH', 'ACHE', 'APE', 'APH', 'CAP', 'CAPE', 'CAPH', 'CEP', 'CEPA', 'CHA', 'CHAP', 'CHAPE', 'CHE', 'CHEAP', 'EACH', 'EPHA', 'HAE', 'HAEC', 'HAP', 'HEAP', 'HEP', 'PAC', 'PACE', 'PAH', 'PEA', 'PEACH', 'PECH'},
  ),
  WordBuilderLevel(
    letters: ['S', 'P', 'I', 'L', 'L'],
    targetCount: 4,
    validWords: {'ILL', 'ILLS', 'LIP', 'LIPS', 'LIS', 'LISP', 'PIL', 'PILL', 'PILLS', 'PIS', 'PLI', 'PSI', 'SILL', 'SLIP', 'SLIPS', 'SPILL'},
  ),
  WordBuilderLevel(
    letters: ['T', 'R', 'A', 'I', 'N'],
    targetCount: 5,
    validWords: {'AIN', 'AINT', 'AIR', 'AIRN', 'AIRT', 'AIT', 'ANI', 'ANT', 'ANTI', 'ARN', 'ARNI', 'ART', 'ATI', 'IAN', 'INTA', 'INTR', 'INTRA', 'IRA', 'IRAN', 'ITA', 'NAIR', 'NAR', 'NAT', 'NATR', 'NIT', 'RAIN', 'RAN', 'RANI', 'RANT', 'RAT', 'RIA', 'RIANT', 'RIN', 'RIT', 'RITA', 'TAI', 'TAIN', 'TAIRN', 'TAN', 'TAR', 'TARI', 'TARIN', 'TARN', 'TIAR', 'TINA', 'TRA', 'TRAIN', 'TRAN', 'TRI', 'TRIN', 'TRINA'},
  ),
  WordBuilderLevel(
    letters: ['S', 'M', 'A', 'R', 'T'],
    targetCount: 7,
    validWords: {'ARM', 'ARMS', 'ARS', 'ART', 'ARTS', 'ASTR', 'ATM', 'MAR', 'MARS', 'MART', 'MARTS', 'MAS', 'MAST', 'MAT', 'MATS', 'MRS', 'RAM', 'RAMS', 'RAS', 'RAT', 'RATS', 'SAM', 'SAR', 'SART', 'SAT', 'SMART', 'STAM', 'STAR', 'STRA', 'STRAM', 'TAM', 'TAMS', 'TAR', 'TARS', 'TAS', 'TRA', 'TRAM', 'TRAMS', 'TSAR'},
  ),
  WordBuilderLevel(
    letters: ['S', 'P', 'A', 'C', 'E'],
    targetCount: 5,
    validWords: {'ACE', 'ACES', 'AES', 'AESC', 'APE', 'APES', 'APSE', 'ASE', 'ASP', 'CAP', 'CAPE', 'CAPES', 'CAPS', 'CASE', 'CEP', 'CEPA', 'CEPS', 'ESCA', 'PAC', 'PACE', 'PACES', 'PACS', 'PAS', 'PASE', 'PEA', 'PEAS', 'PES', 'PESA', 'PSEC', 'SAC', 'SAP', 'SCAP', 'SCAPE', 'SEA', 'SPA', 'SPACE', 'SPAE', 'SPEC'},
  ),
  WordBuilderLevel(
    letters: ['L', 'E', 'M', 'O', 'N'],
    targetCount: 5,
    validWords: {'ELM', 'ELON', 'ENOL', 'EON', 'LEMON', 'LEN', 'LENO', 'LEO', 'LEON', 'LOE', 'LONE', 'MEL', 'MELON', 'MEN', 'MENO', 'MOE', 'MOL', 'MOLE', 'MON', 'MONE', 'MONEL', 'NEMO', 'NEO', 'NOEL', 'NOL', 'NOM', 'NOME', 'OLE', 'OMEN', 'ONE'},
  ),
  WordBuilderLevel(
    letters: ['S', 'T', 'O', 'R', 'M'],
    targetCount: 6,
    validWords: {'MOR', 'MORS', 'MORT', 'MORTS', 'MOS', 'MOST', 'MOT', 'MOTS', 'MRS', 'ORTS', 'ROM', 'ROMS', 'ROS', 'ROT', 'ROTS', 'SORT', 'SOT', 'STOR', 'STORM', 'STROM', 'TOM', 'TOMS', 'TOR', 'TORS'},
  ),
  WordBuilderLevel(
    letters: ['T', 'I', 'G', 'E', 'R'],
    targetCount: 5,
    validWords: {'ERG', 'GEIR', 'GET', 'GIE', 'GIRE', 'GIRT', 'GIT', 'GITE', 'GRE', 'GREIT', 'GRET', 'GRIT', 'IRE', 'ITER', 'REGT', 'REIT', 'RIE', 'RIG', 'RIT', 'RITE', 'TERI', 'TIE', 'TIER', 'TIGE', 'TIGER', 'TIGRE', 'TIRE', 'TRI', 'TRIG'},
  ),
  WordBuilderLevel(
    letters: ['B', 'R', 'E', 'A', 'D'],
    targetCount: 7,
    validWords: {'ABD', 'ABE', 'ABED', 'ADE', 'AER', 'ARB', 'ARDEB', 'ARE', 'ARED', 'BAD', 'BADE', 'BAE', 'BAR', 'BARD', 'BARDE', 'BARE', 'BARED', 'BEA', 'BEAD', 'BEAR', 'BEARD', 'BED', 'BER', 'BRA', 'BRAD', 'BRAE', 'BREAD', 'BRED', 'DAB', 'DAE', 'DAER', 'DAR', 'DARB', 'DARE', 'DEA', 'DEAR', 'DEB', 'DEBAR', 'DER', 'DRAB', 'EAR', 'ERA', 'RAB', 'RAD', 'REA', 'READ', 'REB', 'RED'},
  ),
  WordBuilderLevel(
    letters: ['F', 'L', 'U', 'T', 'E'],
    targetCount: 5,
    validWords: {'ELF', 'FELT', 'FET', 'FEU', 'FLET', 'FLU', 'FLUE', 'FLUTE', 'FUEL', 'FUTE', 'LEFT', 'LET', 'LUT', 'LUTE', 'TEL', 'TUE', 'TULE'},
  ),
  // 10 new levels
  WordBuilderLevel(
    letters: ['P', 'A', 'N'],
    targetCount: 2,
    validWords: {'AN', 'NAP', 'PA', 'PAN'},
  ),
  WordBuilderLevel(
    letters: ['L', 'I', 'P', 'S'],
    targetCount: 3,
    validWords: {'LIP', 'LIPS', 'LIS', 'LISP', 'PIL', 'PIS', 'PLI', 'PSI', 'SLIP'},
  ),
  WordBuilderLevel(
    letters: ['N', 'E', 'S', 'T'],
    targetCount: 4,
    validWords: {'NEST', 'NET', 'NETS', 'SENT', 'SET', 'STEN', 'TENS'},
  ),
  WordBuilderLevel(
    letters: ['F', 'A', 'S', 'T'],
    targetCount: 4,
    validWords: {'AFT', 'AS', 'AT', 'FAS', 'FAST', 'FAT', 'FATS', 'SAFT', 'SAT', 'TAS'},
  ),
  WordBuilderLevel(
    letters: ['H', 'E', 'A', 'R', 'T'],
    targetCount: 5,
    validWords: {'AER', 'AET', 'AHET', 'ARE', 'ARET', 'ART', 'ARTE', 'ATE', 'EAR', 'EARTH', 'EAT', 'EATH', 'ERA', 'ERAT', 'ERTH', 'HAE', 'HAET', 'HARE', 'HART', 'HAT', 'HATE', 'HATER', 'HEAR', 'HEART', 'HEAT', 'HER', 'HERA', 'HERAT', 'HERT', 'RAH', 'RAT', 'RATE', 'RATH', 'RATHE', 'REA', 'RHEA', 'RHET', 'TAE', 'TAHR', 'TAR', 'TARE', 'TEA', 'TEAR', 'TERA', 'THA', 'THAE', 'THAR', 'THE', 'THEA', 'TRA', 'TRAH'},
  ),
  WordBuilderLevel(
    letters: ['G', 'R', 'A', 'P', 'E'],
    targetCount: 5,
    validWords: {'AER', 'AGE', 'AGER', 'AGR', 'AGRE', 'APE', 'APER', 'ARE', 'AREG', 'ARG', 'EAR', 'ERA', 'ERG', 'GAE', 'GAP', 'GAPE', 'GAPER', 'GAR', 'GARE', 'GEAR', 'GRA', 'GRAPE', 'GRE', 'PAGE', 'PAGER', 'PAR', 'PARE', 'PARGE', 'PEA', 'PEAG', 'PEAR', 'PEG', 'PEGA', 'PER', 'PRE', 'RAG', 'RAGE', 'RAP', 'RAPE', 'REA', 'REAP'},
  ),
  WordBuilderLevel(
    letters: ['P', 'L', 'A', 'N', 'E', 'T'],
    targetCount: 6,
    validWords: {'AET', 'ALE', 'ALEN', 'ALP', 'ALPEN', 'ALT', 'ANE', 'ANET', 'ANLET', 'ANT', 'ANTE', 'APE', 'APT', 'ATE', 'ATEN', 'ATLE', 'EAT', 'ELA', 'ELAN', 'ENAPT', 'ENTAL', 'ETNA', 'LAEN', 'LAET', 'LAN', 'LANE', 'LANT', 'LAP', 'LAT', 'LATE', 'LATEN', 'LEA', 'LEAN', 'LEANT', 'LEAP', 'LEAPT', 'LEAT', 'LEN', 'LENA', 'LENT', 'LEPA', 'LEPTA', 'LET', 'NAE', 'NAEL', 'NALE', 'NAP', 'NAPE', 'NAT', 'NATE', 'NATL', 'NEA', 'NEAL', 'NEAP', 'NEAT', 'NEP', 'NEPA', 'NEPAL', 'NET', 'PAL', 'PALE', 'PALET', 'PALT', 'PAN', 'PANE', 'PANEL', 'PANT', 'PANTLE', 'PAT', 'PATE', 'PATEL', 'PATEN', 'PEA', 'PEAL', 'PEAN', 'PEAT', 'PELT', 'PELTA', 'PEN', 'PENAL', 'PENT', 'PENTA', 'PET', 'PETAL', 'PLAN', 'PLANE', 'PLANET', 'PLANT', 'PLAT', 'PLATE', 'PLATEN', 'PLEA', 'PLEAT', 'PLENA', 'TAE', 'TAEL', 'TAEN', 'TAL', 'TALE', 'TAN', 'TANE', 'TAP', 'TAPE', 'TAPEN', 'TEA', 'TEAL', 'TEAN', 'TEAP', 'TEL', 'TELA', 'TENLA', 'TEPA', 'TEPAL'},
  ),
  WordBuilderLevel(
    letters: ['S', 'I', 'L', 'V', 'E', 'R'],
    targetCount: 6,
    validWords: {'ELI', 'ELS', 'ELVES', 'ELVIS', 'ERIS', 'ERVIL', 'ERVILS', 'EVIL', 'EVILS', 'ILE', 'IRE', 'IRES', 'ISLE', 'LEI', 'LEIS', 'LEVI', 'LEVIR', 'LEVIS', 'LIE', 'LIER', 'LIERS', 'LIES', 'LIR', 'LIRE', 'LIS', 'LISE', 'LIV', 'LIVE', 'LIVER', 'LIVERS', 'LIVES', 'LIVRE', 'LIVRES', 'REIS', 'RES', 'REVS', 'RIE', 'RIEL', 'RIELS', 'RIES', 'RILE', 'RILES', 'RISE', 'RIVE', 'RIVEL', 'RIVES', 'SERI', 'SERV', 'SIE', 'SIER', 'SILE', 'SILVER', 'SIRE', 'SIVER', 'SLIER', 'SLIVE', 'SLIVER', 'VEI', 'VEIL', 'VEILS', 'VEL', 'VER', 'VERI', 'VERS', 'VIER', 'VIERS', 'VIES', 'VILE', 'VILER', 'VIRE', 'VIRES', 'VIRL', 'VIRLS', 'VISE', 'VLEI', 'VLSI', 'VRIL'},
  ),
  WordBuilderLevel(
    letters: ['F', 'I', 'N', 'G', 'E', 'R'],
    targetCount: 6,
    validWords: {'ENGR', 'ENIF', 'ERG', 'ERIN', 'FEI', 'FEIGN', 'FEN', 'FER', 'FERN', 'FIE', 'FIG', 'FIN', 'FINE', 'FINER', 'FINGER', 'FIR', 'FIRE', 'FIRN', 'FREN', 'FRIG', 'FRINGE', 'GEIN', 'GEIR', 'GEN', 'GIE', 'GIEN', 'GIF', 'GIN', 'GIRE', 'GIRN', 'GRE', 'GREIN', 'GRIEF', 'GRIF', 'GRIN', 'INFER', 'INGER', 'IRE', 'NEF', 'NEG', 'NEI', 'NEIF', 'NERI', 'NIFE', 'NIG', 'NIGRE', 'REF', 'REGIN', 'REIF', 'REIGN', 'REIN', 'RENIG', 'RGEN', 'RIE', 'RIFE', 'RIG', 'RIN', 'RINE', 'RING', 'RINGE'},
  ),
  WordBuilderLevel(
    letters: ['P', 'O', 'S', 'T', 'E', 'R'],
    targetCount: 6,
    validWords: {'EPOS', 'EROS', 'ERST', 'ESTOP', 'OPE', 'OPES', 'OPTS', 'ORE', 'ORES', 'ORTS', 'OSE', 'PER', 'PERS', 'PERT', 'PES', 'PESO', 'PEST', 'PET', 'PETO', 'PETOS', 'PETR', 'PETRO', 'PETS', 'POE', 'POET', 'POETS', 'POR', 'PORE', 'PORES', 'PORET', 'PORT', 'PORTE', 'PORTS', 'POS', 'POSE', 'POSER', 'POST', 'POSTER', 'POT', 'POTE', 'POTER', 'POTS', 'PRE', 'PRES', 'PREST', 'PRESTO', 'PRET', 'PRO', 'PROS', 'PROSE', 'PROST', 'PROTE', 'REPOST', 'REPOT', 'REPS', 'REPT', 'RES', 'RESP', 'RESPOT', 'REST', 'RETS', 'ROE', 'ROES', 'ROPE', 'ROPES', 'ROS', 'ROSE', 'ROSET', 'ROT', 'ROTE', 'ROTES', 'ROTS', 'ROTSE', 'SEOR', 'SEPT', 'SERO', 'SERT', 'SET', 'SOP', 'SOPE', 'SORE', 'SORT', 'SOT', 'SOTER', 'SPET', 'SPOR', 'SPORE', 'SPORT', 'SPOT', 'SPRET', 'SPROT', 'STEP', 'STER', 'STERO', 'STOEP', 'STOP', 'STOPE', 'STOPER', 'STOR', 'STORE', 'STRE', 'STREP', 'STROP', 'TEPOR', 'TERP', 'TOE', 'TOES', 'TOP', 'TOPE', 'TOPER', 'TOPERS', 'TOPES', 'TOPS', 'TOR', 'TORE', 'TORES', 'TORS', 'TORSE', 'TRES', 'TROP', 'TROPE', 'TROPES'},
  ),
  WordBuilderLevel(
    letters: ['T', 'U', 'B'],
    targetCount: 2,
    validWords: {'BUT', 'TUB'},
  ),
  WordBuilderLevel(
    letters: ['N', 'O', 'W'],
    targetCount: 2,
    validWords: {'NOW', 'OWN', 'WON'},
  ),
  WordBuilderLevel(
    letters: ['T', 'A', 'P', 'S'],
    targetCount: 4,
    validWords: {'APT', 'APTS', 'ASP', 'PAS', 'PAST', 'PAT', 'PATS', 'SAP', 'SAT', 'SPA', 'SPAT', 'STAP', 'TAP', 'TAPS', 'TAS'},
  ),
  WordBuilderLevel(
    letters: ['L', 'A', 'M', 'B'],
    targetCount: 3,
    validWords: {'ABL', 'ALB', 'BAL', 'BALM', 'BAM', 'BLAM', 'LAB', 'LAM', 'LAMB', 'MAB', 'MAL'},
  ),
  WordBuilderLevel(
    letters: ['M', 'I', 'N', 'D'],
    targetCount: 4,
    validWords: {'DIM', 'DIN', 'MID', 'MIDN', 'MIN', 'MIND', 'NID', 'NIM'},
  ),
  WordBuilderLevel(
    letters: ['W', 'I', 'N', 'D'],
    targetCount: 4,
    validWords: {'DIN', 'IN', 'NID', 'WIN', 'WIND'},
  ),
  WordBuilderLevel(
    letters: ['F', 'I', 'R', 'E'],
    targetCount: 4,
    validWords: {'FEI', 'FER', 'FIE', 'FIR', 'FIRE', 'IRE', 'REF', 'REIF', 'RIE', 'RIFE'},
  ),
  WordBuilderLevel(
    letters: ['G', 'A', 'T', 'E'],
    targetCount: 5,
    validWords: {'AET', 'AGE', 'AGET', 'AGT', 'ATE', 'EAT', 'GAE', 'GAET', 'GAT', 'GATE', 'GEAT', 'GET', 'GETA', 'TAE', 'TAG', 'TEA', 'TEGA'},
  ),
  WordBuilderLevel(
    letters: ['K', 'I', 'T', 'E', 'S'],
    targetCount: 5,
    validWords: {'ITS', 'KEIST', 'KET', 'KIE', 'KIST', 'KIT', 'KITE', 'KITES', 'KITS', 'SEIT', 'SET', 'SIE', 'SIKE', 'SIKET', 'SIT', 'SITE', 'SKET', 'SKI', 'SKIT', 'SKITE', 'TIE', 'TIES', 'TIKE', 'TIKES'},
  ),
  WordBuilderLevel(
    letters: ['S', 'P', 'I', 'K', 'E'],
    targetCount: 5,
    validWords: {'EPI', 'IPSE', 'KEP', 'KEPI', 'KEPIS', 'KEPS', 'KIE', 'KIP', 'KIPE', 'KIPS', 'PES', 'PIE', 'PIES', 'PIK', 'PIKE', 'PIKES', 'PIS', 'PISE', 'PISK', 'PSI', 'SIE', 'SIKE', 'SIPE', 'SKEP', 'SKI', 'SKIP', 'SPIE', 'SPIK', 'SPIKE'},
  ),
  WordBuilderLevel(
    letters: ['C', 'L', 'O', 'U', 'D'],
    targetCount: 5,
    validWords: {'CLO', 'CLOD', 'CLOU', 'CLOUD', 'COD', 'COL', 'COLD', 'COUD', 'COUL', 'COULD', 'CUD', 'CUL', 'DOC', 'DOL', 'DOUC', 'DUC', 'DUCO', 'DULC', 'DUO', 'LOC', 'LOD', 'LOU', 'LOUD', 'LUC', 'LUD', 'LUDO', 'LUO', 'OLD', 'UDO'},
  ),
  WordBuilderLevel(
    letters: ['S', 'T', 'O', 'V', 'E'],
    targetCount: 5,
    validWords: {'OSE', 'OVEST', 'SET', 'SOT', 'STOVE', 'TOE', 'TOES', 'VEST', 'VET', 'VETO', 'VETOS', 'VETS', 'VOES', 'VOET', 'VOTE', 'VOTES'},
  ),
  WordBuilderLevel(
    letters: ['B', 'R', 'A', 'I', 'N'],
    targetCount: 5,
    validWords: {'ABIR', 'ABRI', 'ABRIN', 'AIN', 'AIR', 'AIRN', 'ANI', 'ARB', 'ARN', 'ARNI', 'BAI', 'BAIN', 'BAIRN', 'BAN', 'BANI', 'BAR', 'BARI', 'BARN', 'BIN', 'BIRN', 'BRA', 'BRAIN', 'BRAN', 'BRIAN', 'BRIN', 'IAN', 'IBAN', 'IRA', 'IRAN', 'NAB', 'NAIB', 'NAIR', 'NAR', 'NIB', 'RAB', 'RABI', 'RABIN', 'RAIN', 'RAN', 'RANI', 'RIA', 'RIB', 'RIN'},
  ),
  WordBuilderLevel(
    letters: ['S', 'H', 'I', 'E', 'L', 'D'],
    targetCount: 6,
    validWords: {'DEIL', 'DEILS', 'DEIS', 'DEL', 'DELHI', 'DELI', 'DELIS', 'DELS', 'DES', 'DESI', 'DIE', 'DIEL', 'DIES', 'DIS', 'DISH', 'EDH', 'EDHS', 'EILD', 'ELD', 'ELDS', 'ELHI', 'ELI', 'ELS', 'HEIL', 'HEILD', 'HEILS', 'HEL', 'HELD', 'HID', 'HIDE', 'HIDEL', 'HIDES', 'HIE', 'HIED', 'HIELD', 'HIES', 'HILE', 'HIS', 'IDE', 'IDES', 'IDLE', 'IDLES', 'ILE', 'ISED', 'ISLE', 'ISLED', 'LED', 'LEDS', 'LEHI', 'LEI', 'LEIS', 'LID', 'LIDE', 'LIDS', 'LIE', 'LIED', 'LIES', 'LIESH', 'LIS', 'LISE', 'LISH', 'SEID', 'SELD', 'SHE', 'SHED', 'SHEL', 'SHELD', 'SHI', 'SHIDE', 'SHIED', 'SHIEL', 'SHIELD', 'SID', 'SIDE', 'SIDHE', 'SIDLE', 'SIE', 'SILD', 'SILE', 'SLED', 'SLID', 'SLIDE'},
  ),
  WordBuilderLevel(
    letters: ['C', 'A', 'S', 'T', 'L', 'E'],
    targetCount: 6,
    validWords: {'ACE', 'ACES', 'ACLE', 'ACT', 'ACTS', 'AES', 'AESC', 'AET', 'ALC', 'ALCE', 'ALCES', 'ALE', 'ALEC', 'ALECS', 'ALES', 'ALS', 'ALT', 'ALTS', 'ASE', 'ASTEL', 'ATE', 'ATES', 'ATLE', 'CAL', 'CALS', 'CASE', 'CASEL', 'CAST', 'CASTE', 'CASTLE', 'CAT', 'CATE', 'CATEL', 'CATES', 'CATS', 'CELT', 'CELTS', 'CEST', 'CESTA', 'CLAES', 'CLAST', 'CLAT', 'CLEAT', 'CLEATS', 'EAST', 'EAT', 'EATS', 'ECLAT', 'ECLATS', 'ECTAL', 'ELA', 'ELS', 'ELSA', 'ESCA', 'ETAS', 'LAC', 'LACE', 'LACES', 'LACET', 'LACS', 'LAET', 'LAS', 'LASE', 'LAST', 'LAT', 'LATE', 'LATS', 'LEA', 'LEAS', 'LEAST', 'LEAT', 'LECT', 'LEST', 'LET', 'LETS', 'SAC', 'SAL', 'SALE', 'SALET', 'SALT', 'SAT', 'SATE', 'SCALE', 'SCALET', 'SCALT', 'SCAT', 'SCEAT', 'SCLAT', 'SCLATE', 'SEA', 'SEAL', 'SEAT', 'SECT', 'SELT', 'SET', 'SETA', 'SETAL', 'SLAE', 'SLAT', 'SLATE', 'STALE', 'STEAL', 'STELA', 'TACE', 'TACES', 'TAE', 'TAEL', 'TAELS', 'TAL', 'TALC', 'TALCS', 'TALE', 'TALES', 'TAS', 'TEA', 'TEAL', 'TEALS', 'TEAS', 'TEC', 'TECA', 'TECLA', 'TEL', 'TELA', 'TESLA'},
  ),
  WordBuilderLevel(
    letters: ['G', 'A', 'R', 'D', 'E', 'N'],
    targetCount: 6,
    validWords: {'ADE', 'ADEN', 'AER', 'AGE', 'AGED', 'AGEN', 'AGEND', 'AGER', 'AGR', 'AGRE', 'AND', 'ANDE', 'ANDRE', 'ANE', 'ANGER', 'ANRE', 'ARE', 'ARED', 'AREG', 'AREN', 'AREND', 'ARENG', 'ARG', 'ARN', 'ARNE', 'DAE', 'DAER', 'DAG', 'DAN', 'DANE', 'DANG', 'DANGER', 'DAR', 'DARE', 'DAREN', 'DARG', 'DARN', 'DEA', 'DEAN', 'DEAR', 'DEARN', 'DEN', 'DENAR', 'DER', 'DERN', 'DRAG', 'DRANG', 'DREG', 'DRENG', 'EAR', 'EARN', 'EDGAR', 'EDNA', 'EGAD', 'END', 'ENGR', 'ERA', 'ERG', 'GAD', 'GADE', 'GADER', 'GAE', 'GAED', 'GAEN', 'GAN', 'GANDER', 'GANE', 'GAR', 'GARD', 'GARDE', 'GARDEN', 'GARE', 'GARN', 'GEAN', 'GEAR', 'GED', 'GEN', 'GENA', 'GNAR', 'GRA', 'GRAD', 'GRADE', 'GRAND', 'GRANDE', 'GRANE', 'GRE', 'NAD', 'NAE', 'NAG', 'NAR', 'NARD', 'NARE', 'NEA', 'NEAR', 'NED', 'NEG', 'NERD', 'RAD', 'RAG', 'RAGE', 'RAGED', 'RAN', 'RAND', 'RANE', 'RANG', 'RANGE', 'RANGED', 'REA', 'READ', 'RED', 'REDAN', 'REGD', 'REGNA', 'REND', 'RENGA', 'RGEN'},
  ),
  WordBuilderLevel(
    letters: ['F', 'L', 'O', 'W', 'E', 'R'],
    targetCount: 6,
    validWords: {'ELF', 'FER', 'FEW', 'FLEW', 'FLO', 'FLOE', 'FLOR', 'FLOW', 'FLOWE', 'FLOWER', 'FLOWERED', 'FLOWN', 'FOE', 'FOL', 'FOLE', 'FOR', 'FORE', 'FOREL', 'FOW', 'FOWL', 'FOWLER', 'FRO', 'FROE', 'FROW', 'FROWL', 'LEO', 'LOE', 'LOF', 'LOR', 'LORE', 'LOW', 'LOWE', 'LOWER', 'OFER', 'OLE', 'ORE', 'ORF', 'ORFE', 'ORLE', 'OWE', 'OWER', 'OWL', 'OWLER', 'REF', 'REFL', 'REFLEW', 'REFLOW', 'REFLOWN', 'REFOEL', 'REFOWL', 'ROE', 'ROLE', 'ROLF', 'ROLFE', 'ROW', 'ROWE', 'ROWEL', 'ROWER', 'WELF', 'WERF', 'WOE', 'WOLF', 'WOLFER', 'WOLFERS', 'WORE'},
  ),
  WordBuilderLevel(
    letters: ['C', 'L', 'I', 'M', 'B', 'E', 'R'],
    targetCount: 6,
    validWords: {'BEC', 'BEL', 'BER', 'BERI', 'BERM', 'BICE', 'BICER', 'BIER', 'BILE', 'BIM', 'BIREME', 'BIRL', 'BIRLE', 'BLIER', 'BREI', 'BRIE', 'BRIM', 'CEBIL', 'CEIL', 'CIE', 'CIR', 'CIRE', 'CIRL', 'CLEM', 'CLI', 'CLIMB', 'CLIMBED', 'CLIMBER', 'CLIMBING', 'CLIME', 'CRE', 'CRIB', 'CRIBLE', 'CRILE', 'CRIM', 'CRIMBLE', 'CRIME', 'ELI', 'ELM', 'ELRIC', 'EMBLIC', 'EMIC', 'EMIL', 'EMIR', 'ERIC', 'ICBM', 'ICE', 'ILE', 'IMBE', 'IMBER', 'IMER', 'IRE', 'LEI', 'LIB', 'LIBER', 'LIBR', 'LIBRE', 'LICE', 'LIE', 'LIER', 'LIM', 'LIMB', 'LIMBEC', 'LIMBER', 'LIME', 'LIMER', 'LIR', 'LIRE', 'MEL', 'MELIC', 'MER', 'MERC', 'MERCI', 'MERIL', 'MERL', 'MIB', 'MICE', 'MIL', 'MILE', 'MILER', 'MIR', 'MIRE', 'REB', 'REC', 'RECLIMB', 'REIM', 'RELIC', 'REMI', 'RIB', 'RIBE', 'RIC', 'RICE', 'RIE', 'RIEL', 'RIEM', 'RILE', 'RIM', 'RIME'},
  ),
  WordBuilderLevel(
    letters: ['V', 'I', 'C', 'T', 'O', 'R', 'Y'],
    targetCount: 6,
    validWords: {'CIR', 'CIT', 'CITY', 'CIV', 'CIVORY', 'CIVY', 'COIR', 'COIT', 'COR', 'CORT', 'CORV', 'CORY', 'COT', 'COY', 'CRIT', 'CRO', 'CROY', 'CRY', 'ICY', 'ITO', 'IVORY', 'IVY', 'ORC', 'OTIC', 'RIC', 'RIO', 'RIOT', 'RIT', 'RIVO', 'ROC', 'ROI', 'ROIT', 'ROT', 'ROTI', 'ROY', 'ROYT', 'RYOT', 'TIC', 'TIRO', 'TIVY', 'TOR', 'TORC', 'TORI', 'TORIC', 'TORY', 'TOY', 'TRI', 'TRIO', 'TROIC', 'TROY', 'TRY', 'TYRO', 'VICTOR', 'VICTORY', 'VITO', 'VITRO', 'VITRY'},
  ),
  WordBuilderLevel(
    letters: ['H', 'A', 'P', 'P', 'I', 'N', 'E', 'S', 'S'],
    targetCount: 6,
    validWords: {'AES', 'AHI', 'AHS', 'AIN', 'AINE', 'AINS', 'AIS', 'ANE', 'ANES', 'ANESIS', 'ANI', 'ANIS', 'ANISE', 'ANISES', 'ANSEIS', 'ANSI', 'APE', 'APES', 'APH', 'APHESIS', 'APHIS', 'APIS', 'APISH', 'APSE', 'APSES', 'APSIS', 'ASE', 'ASH', 'ASHEN', 'ASHES', 'ASHINE', 'ASP', 'ASPEN', 'ASPENS', 'ASPIS', 'ASPISH', 'ASPS', 'ASS', 'ASSE', 'ASSI', 'ASSN', 'ENPIA', 'EPHA', 'EPHAS', 'EPI', 'ESHIN', 'HAE', 'HAEN', 'HAES', 'HAIN', 'HAINE', 'HAN', 'HANS', 'HANSE', 'HANSES', 'HAP', 'HAPI', 'HAPPEN', 'HAPPENS', 'HAPPINESS', 'HAPPINESSES', 'HAPPY', 'HAPS', 'HAS', 'HASN', 'HASP', 'HASPS', 'HEAP', 'HEAPS', 'HEIN', 'HEN', 'HENS', 'HEP', 'HESSIAN', 'HIE', 'HIES', 'HIN', 'HINE', 'HINS', 'HIP', 'HIPE', 'HIPNESS', 'HIPPA', 'HIPPEN', 'HIPS', 'HIS', 'HISN', 'HISPA', 'HISS', 'HSIEN', 'HYPE', 'HYPES', 'IAN', 'INPHASE', 'INPHASES', 'INSEA', 'INSEP', 'INSP', 'IPSE', 'NAE', 'NAIS', 'NAISH', 'NAP', 'NAPE', 'NAPES', 'NAPPE', 'NAPPES', 'NAPPIE', 'NAPPIES', 'NAPS', 'NASH', 'NASI', 'NEA', 'NEAP', 'NEAPS', 'NEI', 'NEP', 'NEPA', 'NESH', 'NESS', 'NIAS', 'NIEPA', 'NIES', 'NIP', 'NIPA', 'NIPAS', 'NIPS', 'NIS', 'NISSE', 'PAH', 'PAHI', 'PAIN', 'PAINE', 'PAINS', 'PAIP', 'PAIS', 'PAISE', 'PAN', 'PANE', 'PANES', 'PANI', 'PANS', 'PANSE', 'PANSIES', 'PAP', 'PAPE', 'PAPESS', 'PAPISH', 'PAPS', 'PAS', 'PASE', 'PASES', 'PASH', 'PASHES', 'PASI', 'PASIS', 'PASS', 'PASSE', 'PASSEN', 'PAYS', 'PEA', 'PEAI', 'PEAN', 'PEANS', 'PEAS', 'PEIN', 'PEINS', 'PEN', 'PENIS', 'PENS', 'PENSHIP', 'PEP', 'PEPS', 'PEPSI', 'PEPSIN', 'PEPSINS', 'PEPSIS', 'PES', 'PESA', 'PESAH', 'PESS', 'PHANE', 'PHASE', 'PHASES', 'PHASIS', 'PHI', 'PHIES', 'PHINEAS', 'PHIS', 'PIA', 'PIAN', 'PIANS', 'PIAS', 'PIE', 'PIEN', 'PIEPAN', 'PIES', 'PIN', 'PINA', 'PINAS', 'PINE', 'PINES', 'PINESAP', 'PINESAPS', 'PINS', 'PIP', 'PIPA', 'PIPE', 'PIPES', 'PIPS', 'PIS', 'PISA', 'PISAN', 'PISE', 'PISH', 'PISHES', 'PISS', 'PSHA', 'PSI', 'PSIA', 'PSIS', 'SAI', 'SAIN', 'SAINS', 'SAIP', 'SAIPH', 'SAN', 'SANE', 'SANES', 'SANIES', 'SANS', 'SANSEI', 'SANSI', 'SAP', 'SAPHIE', 'SAPIENS', 'SAPIN', 'SAPS', 'SASH', 'SASIN', 'SASINE', 'SEA', 'SEAH', 'SEAN', 'SEAS', 'SEIS', 'SENA', 'SENSA', 'SEPIA', 'SEPIAN', 'SEPIAS', 'SEPN', 'SEPPA', 'SEPS', 'SEPSIN', 'SESIA', 'SHA', 'SHAI', 'SHAN', 'SHANE', 'SHAP', 'SHAPE', 'SHAPEN', 'SHAPES', 'SHAPS', 'SHAY', 'SHE', 'SHEA', 'SHEAN', 'SHEAS', 'SHED', 'SHEN', 'SHES', 'SHI', 'SHIA', 'SHIES', 'SHIN', 'SHINA', 'SHINE', 'SHINES', 'SHINS', 'SHIP', 'SHIPPEN', 'SHIPPENS', 'SHIPS', 'SHISN', 'SHNAPS', 'SIE', 'SIENA', 'SINA', 'SINAE', 'SINE', 'SINES', 'SINH', 'SINHS', 'SINS', 'SIPE', 'SIPES', 'SIPS', 'SISE', 'SISH', 'SNAP', 'SNAPE', 'SNAPPE', 'SNAPPISH', 'SNAPPS', 'SNAPS', 'SNASH', 'SNEAP', 'SNEAPS', 'SNIES', 'SNIP', 'SNIPE', 'SNIPES', 'SNIPS', 'SPA', 'SPAE', 'SPAES', 'SPAHI', 'SPAHIS', 'SPAIN', 'SPAN', 'SPANE', 'SPANISH', 'SPANS', 'SPAS', 'SPEAN', 'SPEANS', 'SPIES', 'SPIN', 'SPINA', 'SPINAE', 'SPINE', 'SPINES', 'SPINS', 'SPISE'},
  ),
  WordBuilderLevel(
    letters: ['P', 'L', 'A', 'S', 'T', 'I', 'C'],
    targetCount: 8,
    validWords: {'ACIS', 'ACPT', 'ACT', 'ACTS', 'AIL', 'AILS', 'AIS', 'AIT', 'AITS', 'ALC', 'ALISP', 'ALIST', 'ALIT', 'ALP', 'ALPIST', 'ALPS', 'ALS', 'ALT', 'ALTS', 'APIS', 'APT', 'APTS', 'ASCI', 'ASP', 'ASPIC', 'ATI', 'ATIP', 'ATIS', 'ATLI', 'CAI', 'CAL', 'CALP', 'CALS', 'CAP', 'CAPS', 'CAST', 'CAT', 'CATS', 'CIA', 'CIS', 'CIST', 'CISTA', 'CIT', 'CITAL', 'CLAP', 'CLAPS', 'CLAPT', 'CLASP', 'CLASPT', 'CLAST', 'CLAT', 'CLI', 'CLIP', 'CLIPS', 'CLIPT', 'CLIT', 'ILA', 'ITA', 'ITAL', 'ITS', 'LAC', 'LACIS', 'LACS', 'LAI', 'LAIC', 'LAICS', 'LAIT', 'LAP', 'LAPIS', 'LAPS', 'LAPSI', 'LAS', 'LASI', 'LAST', 'LAT', 'LATI', 'LATS', 'LIAS', 'LIP', 'LIPA', 'LIPS', 'LIS', 'LISA', 'LISP', 'LIST', 'LIT', 'LITAS', 'LITS', 'PAC', 'PACS', 'PACT', 'PACTS', 'PAIL', 'PAILS', 'PAIS', 'PAL', 'PALI', 'PALIS', 'PALS', 'PALT', 'PAS', 'PASI', 'PAST', 'PASTIL', 'PAT', 'PATS', 'PIA', 'PIAL', 'PIAS', 'PIAST', 'PIC', 'PICA', 'PICAL', 'PICAS', 'PICS', 'PICT', 'PIL', 'PIS', 'PISA', 'PIST', 'PIT', 'PITA', 'PITAS', 'PITS', 'PLACIT', 'PLAIT', 'PLAITS', 'PLASTIC', 'PLAT', 'PLATIC', 'PLATS', 'PLI', 'PLICA', 'PSI', 'PSIA', 'SAC', 'SAI', 'SAIC', 'SAIL', 'SAIP', 'SAL', 'SALIC', 'SALP', 'SALT', 'SAP', 'SAPIT', 'SAT', 'SATI', 'SCALP', 'SCALT', 'SCAP', 'SCAT', 'SCI', 'SCIL', 'SCLAT', 'SIAL', 'SIC', 'SILT', 'SIT', 'SITA', 'SLAIT', 'SLAP', 'SLAT', 'SLIP', 'SLIPT', 'SLIT', 'SPA', 'SPAIL', 'SPAIT', 'SPALT', 'SPAT', 'SPIAL', 'SPIC', 'SPICA', 'SPICAL', 'SPILT', 'SPIT', 'SPITAL', 'SPLAT', 'SPLIT', 'STAIL', 'STAP', 'STIPA', 'TAI', 'TAIL', 'TAILS', 'TAL', 'TALC', 'TALCS', 'TALI', 'TALIS', 'TAP', 'TAPIS', 'TAPS', 'TAS', 'TIC', 'TICAL', 'TICALS', 'TICS', 'TIL', 'TILS', 'TIPS', 'TSIA'},
  ),
  WordBuilderLevel(
    letters: ['C', 'O', 'M', 'P', 'A', 'S', 'S'],
    targetCount: 8,
    validWords: {'ACOP', 'AMOS', 'AMP', 'AMPS', 'ASOP', 'ASP', 'ASPS', 'ASS', 'ASSOC', 'CAM', 'CAMP', 'CAMPO', 'CAMPOS', 'CAMPS', 'CAMS', 'CAP', 'CAPO', 'CAPOS', 'CAPS', 'CASS', 'COM', 'COMA', 'COMAS', 'COMP', 'COMPASS', 'COMPS', 'COMS', 'COP', 'COPA', 'COPS', 'COS', 'COSS', 'CSMP', 'MAC', 'MACO', 'MACS', 'MAO', 'MAP', 'MAPO', 'MAPS', 'MAS', 'MASC', 'MASS', 'MOA', 'MOAS', 'MOC', 'MOCA', 'MOP', 'MOPS', 'MOS', 'MOSS', 'OCAS', 'OSSA', 'PAC', 'PACO', 'PACOS', 'PACS', 'PAM', 'PAMS', 'PAS', 'PASMO', 'PASO', 'PASS', 'PASSO', 'POA', 'POM', 'POS', 'POSCA', 'POSS', 'PSOAS', 'SAC', 'SACO', 'SACS', 'SAM', 'SAMP', 'SAMPS', 'SAP', 'SAPO', 'SAPS', 'SCAM', 'SCAMP', 'SCAMPS', 'SCAMS', 'SCAP', 'SCOP', 'SCOPA', 'SCOPS', 'SOAM', 'SOAP', 'SOAPS', 'SODA', 'SOMA', 'SOMAS', 'SOP', 'SOPS', 'SOS', 'SPA', 'SPAM', 'SPAS', 'SPASM'},
  ),
  WordBuilderLevel(
    letters: ['B', 'A', 'N', 'Q', 'U', 'E', 'T'],
    targetCount: 8,
    validWords: {'ABE', 'ABET', 'ABNET', 'ABU', 'ABUNE', 'ABUT', 'AET', 'ANE', 'ANET', 'ANT', 'ANTE', 'ANTU', 'ATE', 'ATEN', 'ATUNE', 'AUBE', 'AUNE', 'AUNT', 'AUTE', 'BAE', 'BAN', 'BANE', 'BANQUE', 'BANQUET', 'BANT', 'BANTU', 'BAT', 'BATE', 'BAUN', 'BEA', 'BEAN', 'BEANT', 'BEAT', 'BEAU', 'BEAUT', 'BEN', 'BENA', 'BENT', 'BENU', 'BET', 'BETA', 'BUAT', 'BUN', 'BUNA', 'BUNT', 'BUT', 'BUTANE', 'BUTE', 'BUTEA', 'EAT', 'EAU', 'EQUANT', 'ETNA', 'ETUA', 'NAB', 'NABU', 'NAE', 'NAT', 'NATE', 'NATU', 'NAUT', 'NEA', 'NEAT', 'NEB', 'NET', 'NEUT', 'NUB', 'NUBA', 'NUT', 'QAT', 'QUA', 'QUAB', 'QUAE', 'QUAN', 'QUANT', 'QUAT', 'QUATE', 'QUE', 'QUEAN', 'QUENT', 'QUET', 'QUITE', 'TAB', 'TABU', 'TAE', 'TAEN', 'TAN', 'TANE', 'TAU', 'TAUBE', 'TAUN', 'TEA', 'TEAN', 'TEBU', 'TUAN', 'TUB', 'TUBA', 'TUBAE', 'TUBE', 'TUE', 'TUNA', 'TUNE', 'UNBE', 'UNBET', 'UNTA'},
  ),
  WordBuilderLevel(
    letters: ['S', 'U', 'N', 'S', 'H', 'I', 'N', 'E'],
    targetCount: 12,
    validWords: {'ENNUI', 'ENNUIS', 'ESHIN', 'HEIN', 'HEN', 'HENS', 'HIE', 'HIES', 'HIN', 'HINE', 'HINS', 'HIS', 'HISN', 'HISS', 'HSIEN', 'HUE', 'HUES', 'HUI', 'HUN', 'HUNS', 'HUSE', 'HUSS', 'INN', 'INNE', 'INNESS', 'INNS', 'INSUE', 'ISSUE', 'NEI', 'NEIN', 'NESH', 'NESS', 'NIES', 'NINE', 'NINES', 'NIS', 'NISSE', 'NISUS', 'NIUE', 'NUN', 'NUNS', 'NUS', 'SEIN', 'SEIS', 'SENSU', 'SENUSI', 'SHE', 'SHEN', 'SHES', 'SHI', 'SHIES', 'SHIN', 'SHINE', 'SHINES', 'SHINS', 'SHISN', 'SHU', 'SHUN', 'SHUNE', 'SHUNS', 'SIE', 'SINE', 'SINES', 'SINH', 'SINHS', 'SINS', 'SINUS', 'SISE', 'SISH', 'SNIES', 'SUE', 'SUES', 'SUI', 'SUINE', 'SUN', 'SUNE', 'SUNN', 'SUNNI', 'SUNNS', 'SUNS', 'SUNSHINE', 'SUS', 'SUSHI', 'SUSI', 'SUSIE', 'UNIE', 'UNNESS', 'UNSIN', 'USE', 'USES', 'USINE', 'USNIN'},
  ),
  WordBuilderLevel(
    letters: ['F', 'E', 'S', 'T', 'I', 'V', 'A', 'L'],
    targetCount: 12,
    validWords: {'AES', 'AET', 'AFT', 'AIEL', 'AIL', 'AILE', 'AILS', 'AIS', 'AISLE', 'AIT', 'AITS', 'ALE', 'ALEF', 'ALEFS', 'ALEFT', 'ALES', 'ALF', 'ALFET', 'ALIET', 'ALIF', 'ALIFE', 'ALIFS', 'ALIST', 'ALIT', 'ALITE', 'ALIVE', 'ALIVES', 'ALS', 'ALT', 'ALTS', 'ALVITE', 'ASE', 'ASTEL', 'ATE', 'ATEF', 'ATES', 'ATI', 'ATIS', 'ATLE', 'ATLI', 'AVE', 'AVES', 'AVIE', 'AVILE', 'AVIS', 'EAST', 'EAT', 'EATS', 'EFTS', 'EILA', 'ELA', 'ELF', 'ELI', 'ELIA', 'ELIAS', 'ELS', 'ELSA', 'ELVIS', 'ESTIVAL', 'ETAS', 'EVA', 'EVAL', 'EVIL', 'EVILS', 'FAE', 'FAIL', 'FAILS', 'FAIT', 'FAITS', 'FALSE', 'FALSIE', 'FAS', 'FAST', 'FASTI', 'FAT', 'FATE', 'FATES', 'FATIL', 'FATS', 'FAVEL', 'FAVI', 'FEAL', 'FEAST', 'FEAT', 'FEATS', 'FEI', 'FEIL', 'FEIS', 'FEIST', 'FELIS', 'FELS', 'FELT', 'FELTS', 'FEST', 'FESTA', 'FESTAL', 'FESTIVAL', 'FET', 'FETA', 'FETAL', 'FETAS', 'FETIAL', 'FETIALS', 'FETIS', 'FETS', 'FIAT', 'FIATS', 'FIE', 'FIEL', 'FIESTA', 'FIL', 'FILA', 'FILATE', 'FILE', 'FILEA', 'FILES', 'FILET', 'FILETS', 'FILS', 'FILT', 'FISE', 'FIST', 'FISTLE', 'FIT', 'FITS', 'FIVE', 'FIVES', 'FLAITE', 'FLAT', 'FLATIVE', 'FLATS', 'FLAV', 'FLEA', 'FLEAS', 'FLET', 'FLETA', 'FLIES', 'FLIEST', 'FLIT', 'FLITE', 'FLITES', 'FLITS', 'ILA', 'ILE', 'ILEA', 'ISLE', 'ISLET', 'ISLETA', 'ISTLE', 'ITA', 'ITAL', 'ITAVES', 'ITEA', 'ITEL', 'ITS', 'ITSELF', 'LAET', 'LAETI', 'LAFITE', 'LAFT', 'LAI', 'LAIT', 'LAS', 'LASE', 'LASI', 'LAST', 'LAT', 'LATE', 'LATI', 'LATIVE', 'LATS', 'LAV', 'LAVE', 'LAVES', 'LEA', 'LEAF', 'LEAFIT', 'LEAFS', 'LEAS', 'LEAST', 'LEAT', 'LEFT', 'LEFTS', 'LEI', 'LEIF', 'LEIS', 'LEST', 'LET', 'LETS', 'LEVA', 'LEVI', 'LEVIS', 'LIAS', 'LIE', 'LIEF', 'LIES', 'LIEST', 'LIF', 'LIFE', 'LIFT', 'LIFTS', 'LIS', 'LISA', 'LISE', 'LIST', 'LIT', 'LITAS', 'LITE', 'LITES', 'LITS', 'LITSEA', 'LIV', 'LIVE', 'LIVES', 'LIVEST', 'SAFE', 'SAFI', 'SAFT', 'SAI', 'SAIL', 'SAITE', 'SAL', 'SALE', 'SALET', 'SALITE', 'SALT', 'SALTIE', 'SALVE', 'SAT', 'SATE', 'SATI', 'SATIVE', 'SAVE', 'SAVILE', 'SEA', 'SEAL', 'SEAT', 'SEIF', 'SEIT', 'SELF', 'SELT', 'SELVA', 'SET', 'SETA', 'SETAL', 'SIAL', 'SIE', 'SIEVA', 'SIFE', 'SIFT', 'SILE', 'SILT', 'SILVA', 'SILVAE', 'SIT', 'SITA', 'SITE', 'SIVA', 'SLAE', 'SLAIT', 'SLAT', 'SLATE', 'SLAV', 'SLAVE', 'SLAVI', 'SLIT', 'SLITE', 'SLIVE', 'STAIL', 'STALE', 'STAVE', 'STEAL', 'STELA', 'STELAI', 'STEVIA', 'STIFE', 'STIFLE', 'STILE', 'STIVE', 'SVELT', 'TAE', 'TAEL', 'TAELS', 'TAI', 'TAIL', 'TAILS', 'TAISE', 'TAL', 'TALE', 'TALES', 'TALI', 'TALIS', 'TAS', 'TAVE', 'TAVS', 'TEA', 'TEAL', 'TEALS', 'TEAS', 'TEIL', 'TEL', 'TELA', 'TELI', 'TELIA', 'TESLA', 'TIE', 'TIES', 'TIL', 'TILE', 'TILES', 'TILS', 'TSIA', 'VAIL', 'VAILS', 'VALE', 'VALES', 'VALET', 'VALETS', 'VALI', 'VALISE', 'VALSE', 'VASE', 'VAST', 'VATES', 'VATS', 'VEAL', 'VEALS', 'VEI', 'VEIL', 'VEILS', 'VEL', 'VELA', 'VEST', 'VESTA', 'VESTAL', 'VET', 'VETA', 'VETS', 'VIAL', 'VIALS', 'VIAS', 'VIES', 'VILA', 'VILE', 'VILEST', 'VISA', 'VISE', 'VISTA', 'VISTAL', 'VITA', 'VITAE', 'VITAL', 'VITALS', 'VITE', 'VLEI', 'VLSI'},
  ),
  WordBuilderLevel(
    letters: ['B', 'U', 'T', 'T', 'E', 'R', 'F', 'L'],
    targetCount: 12,
    validWords: {'BEF', 'BEFUR', 'BEL', 'BELT', 'BER', 'BERT', 'BET', 'BLET', 'BLEU', 'BLUE', 'BLUER', 'BLUET', 'BLUFTER', 'BLUR', 'BLURT', 'BRET', 'BRETT', 'BRUET', 'BRULE', 'BRUT', 'BRUTE', 'BUL', 'BULT', 'BULTER', 'BUR', 'BURE', 'BUREL', 'BURET', 'BURL', 'BURLET', 'BURT', 'BUT', 'BUTE', 'BUTLE', 'BUTLER', 'BUTT', 'BUTTE', 'BUTTER', 'BUTTERFLY', 'BUTTLE', 'ELF', 'FELT', 'FER', 'FERU', 'FET', 'FEU', 'FLET', 'FLEUR', 'FLU', 'FLUB', 'FLUE', 'FLUER', 'FLURT', 'FLUTE', 'FLUTER', 'FLUTTER', 'FLY', 'FRET', 'FRETT', 'FUEL', 'FUR', 'FURL', 'FUTE', 'FUTTER', 'LEFT', 'LET', 'LETT', 'LUB', 'LUBE', 'LURE', 'LUT', 'LUTE', 'LUTER', 'REB', 'REBUT', 'REF', 'REFL', 'REFT', 'REUB', 'RUB', 'RUBE', 'RUBLE', 'RUE', 'RULE', 'RUT', 'RUTTLE', 'TEBU', 'TEL', 'TELT', 'TREF', 'TRET', 'TRUB', 'TRUE', 'TUB', 'TUBE', 'TUBER', 'TUBLET', 'TUE', 'TUFT', 'TUFTER', 'TULE', 'TURB', 'TURBLE', 'TURF', 'TURTLE', 'TUTE', 'TUTLER', 'UFER', 'UTTER'},
  ),
  WordBuilderLevel(
    letters: ['C', 'O', 'M', 'P', 'U', 'T', 'E', 'R'],
    targetCount: 12,
    validWords: {'CEP', 'CEPTOR', 'CERO', 'CERT', 'COE', 'COEMPT', 'COM', 'COME', 'COMER', 'COMET', 'COMP', 'COMPERT', 'COMPT', 'COMPTE', 'COMPTER', 'COMPUTE', 'COMPUTER', 'COMR', 'COMTE', 'COP', 'COPE', 'COPER', 'COPR', 'COPT', 'COPTER', 'COR', 'CORE', 'CORM', 'CORP', 'CORT', 'COT', 'COTE', 'COUE', 'COUP', 'COUPE', 'COUPER', 'COURT', 'COUTER', 'CRE', 'CREPT', 'CRO', 'CROM', 'CROME', 'CROP', 'CROUP', 'CROUPE', 'CROUT', 'CROUTE', 'CRPE', 'CRU', 'CRUET', 'CRUM', 'CRUMP', 'CRUMPET', 'CRUP', 'CRUT', 'CUE', 'CUERPO', 'CUM', 'CUMP', 'CUP', 'CUR', 'CURE', 'CURET', 'CURT', 'CUT', 'CUTE', 'CUTER', 'ECRU', 'ECU', 'EMPT', 'EMPTOR', 'EMU', 'ERUC', 'ERUCT', 'ERUMP', 'ERUPT', 'EURO', 'MER', 'MERC', 'MERO', 'MEROP', 'MET', 'METRO', 'MOC', 'MOE', 'MOET', 'MOP', 'MOPE', 'MOPER', 'MOR', 'MORE', 'MORT', 'MOT', 'MOTE', 'MOTER', 'MOU', 'MOUE', 'MOUP', 'MOUT', 'MPRET', 'MUCOR', 'MUCRO', 'MURE', 'MUT', 'MUTE', 'MUTER', 'OMER', 'OPE', 'OPEC', 'ORC', 'ORE', 'OUR', 'OUT', 'OUTER', 'OUTR', 'OUTRE', 'PER', 'PERM', 'PERT', 'PERU', 'PET', 'PETO', 'PETR', 'PETRO', 'PETUM', 'POE', 'POEM', 'POET', 'POM', 'POME', 'POR', 'PORC', 'PORE', 'PORET', 'PORT', 'PORTE', 'POT', 'POTE', 'POTER', 'POUCE', 'POUCER', 'POUR', 'POUT', 'POUTER', 'PRE', 'PREC', 'PRECUT', 'PREM', 'PRET', 'PRO', 'PROC', 'PROEM', 'PROM', 'PROTE', 'PRUE', 'PRUT', 'PUCE', 'PUERTO', 'PUME', 'PUR', 'PURE', 'PUT', 'RCPT', 'REC', 'RECOUP', 'RECPT', 'RECT', 'RECTO', 'RECTUM', 'RECUT', 'REMOP', 'REPOT', 'REPT', 'ROC', 'ROE', 'ROM', 'ROME', 'ROMP', 'ROMPU', 'ROPE', 'ROT', 'ROTE', 'ROUE', 'ROUP', 'ROUPET', 'ROUT', 'ROUTE', 'RUE', 'RUM', 'RUME', 'RUMP', 'RUMPOT', 'RUT', 'TEC', 'TECO', 'TECUM', 'TEMP', 'TEMPO', 'TEPOR', 'TERM', 'TERP', 'TOE', 'TOM', 'TOME', 'TOP', 'TOPE', 'TOPER', 'TOR', 'TORC', 'TORE', 'TORU', 'TOU', 'TOUP', 'TOUR', 'TROMP', 'TROMPE', 'TROP', 'TROPE', 'TROUE', 'TROUPE', 'TRUCE', 'TRUE', 'TRUMP', 'TUE', 'TUME', 'TUMOR', 'TUMP', 'TURCO', 'TURM', 'TURP', 'UPCOME', 'UPTORE', 'UTERO'},
  ),
  WordBuilderLevel(
    letters: ['M', 'O', 'U', 'N', 'T', 'A', 'I', 'N'],
    targetCount: 12,
    validWords: {'AIM', 'AIN', 'AINT', 'AINU', 'AION', 'AIT', 'AMI', 'AMIN', 'AMINO', 'AMIT', 'AMNION', 'AMOUNT', 'AMU', 'ANI', 'ANIM', 'ANIMO', 'ANION', 'ANN', 'ANNI', 'ANNO', 'ANNOT', 'ANNUM', 'ANOINT', 'ANON', 'ANT', 'ANTI', 'ANTON', 'ANTU', 'ANTUM', 'ATI', 'ATIMON', 'ATM', 'ATMO', 'ATOM', 'AUM', 'AUNT', 'AUTO', 'IAN', 'IMA', 'IMAN', 'INN', 'INO', 'INOMA', 'INTA', 'INTO', 'ION', 'IOTA', 'ITA', 'ITMO', 'ITO', 'MAIN', 'MAINT', 'MAN', 'MANI', 'MANIT', 'MANITO', 'MANITOU', 'MANITU', 'MANIU', 'MANN', 'MANO', 'MANT', 'MANTO', 'MANTON', 'MAO', 'MAT', 'MATIN', 'MAU', 'MAUN', 'MAUT', 'MIA', 'MIAN', 'MIAO', 'MIAOU', 'MIN', 'MINA', 'MINO', 'MINOAN', 'MINOT', 'MINT', 'MIT', 'MITU', 'MITUA', 'MOA', 'MOAN', 'MOAT', 'MOI', 'MOIT', 'MON', 'MONA', 'MONT', 'MONTIA', 'MONTU', 'MOT', 'MOTA', 'MOU', 'MOUN', 'MOUNT', 'MOUNTAIN', 'MOUT', 'MOUTAN', 'MUN', 'MUNIA', 'MUNT', 'MUNTIN', 'MUON', 'MUT', 'MUTA', 'NAIM', 'NAIN', 'NAIO', 'NAM', 'NAN', 'NANMU', 'NANT', 'NAOI', 'NAOMI', 'NAT', 'NATION', 'NATO', 'NATU', 'NAUNT', 'NAUT', 'NIM', 'NINA', 'NINTU', 'NINUT', 'NIOTA', 'NIT', 'NITO', 'NITON', 'NIUAN', 'NOA', 'NOAM', 'NOINT', 'NOM', 'NOMA', 'NOMINA', 'NON', 'NONA', 'NOT', 'NOTA', 'NOTAN', 'NOTUM', 'NOU', 'NOUN', 'NUM', 'NUMA', 'NUMINA', 'NUN', 'NUT', 'OAT', 'OINT', 'OMAN', 'OMANI', 'OMINA', 'OMIT', 'OMNI', 'ONAN', 'ONIUM', 'ONMUN', 'OTIUM', 'OUT', 'OUTMAN', 'RAIN', 'TAI', 'TAIN', 'TAINO', 'TAM', 'TAN', 'TANO', 'TAO', 'TAU', 'TAUM', 'TAUN', 'TIAM', 'TIAO', 'TIMO', 'TIMON', 'TINA', 'TINAMOU', 'TINMAN', 'TINO', 'TIOU', 'TOA', 'TOM', 'TOMA', 'TOMAN', 'TOMIA', 'TOMIN', 'TON', 'TONN', 'TONNA', 'TOU', 'TUAN', 'TUMAIN', 'TUMION', 'TUNA', 'TUNNA', 'TUNO', 'UINTA', 'UNAI', 'UNAMI', 'UNAMO', 'UNIAT', 'UNIO', 'UNION', 'UNIT', 'UNMAN', 'UNONA', 'UNTA', 'UNTIN', 'UNTO', 'UTAI', 'UTINAM'},
  ),
  WordBuilderLevel(
    letters: ['P', 'L', 'A', 'T', 'I', 'N', 'U', 'M'],
    targetCount: 12,
    validWords: {'AIL', 'AIM', 'AIN', 'AINT', 'AINU', 'AIT', 'ALIN', 'ALIT', 'ALP', 'ALT', 'ALTIN', 'ALTUN', 'ALUM', 'ALUMIN', 'ALUMNI', 'AMI', 'AMIL', 'AMIN', 'AMIT', 'AMLI', 'AMP', 'AMPUL', 'AMU', 'ANI', 'ANIL', 'ANIM', 'ANT', 'ANTI', 'ANTU', 'ANTUM', 'APIUM', 'APT', 'ATI', 'ATIP', 'ATLI', 'ATM', 'AUL', 'AUM', 'AUMIL', 'AUNT', 'IAN', 'ILA', 'IMA', 'IMAN', 'IMP', 'IMPLANT', 'IMPUT', 'INAPT', 'INLAUT', 'INPUT', 'INTA', 'INTL', 'INULA', 'ITA', 'ITAL', 'LAI', 'LAIN', 'LAIT', 'LAM', 'LAMIN', 'LAMP', 'LAMUT', 'LAN', 'LANT', 'LANTUM', 'LANUM', 'LAP', 'LAPIN', 'LAT', 'LATI', 'LATIN', 'LAUN', 'LIM', 'LIMA', 'LIMAN', 'LIMN', 'LIMP', 'LIMU', 'LIN', 'LINA', 'LINT', 'LINUM', 'LIP', 'LIPA', 'LIPAN', 'LIT', 'LITU', 'LUI', 'LUIAN', 'LUM', 'LUMINA', 'LUMP', 'LUNA', 'LUNT', 'LUPIN', 'LUT', 'MAIL', 'MAIN', 'MAINT', 'MAL', 'MALI', 'MALT', 'MAN', 'MANI', 'MANIT', 'MANITU', 'MANIU', 'MANT', 'MANUL', 'MAP', 'MAT', 'MATIN', 'MAU', 'MAUL', 'MAUN', 'MAUT', 'MIA', 'MIAN', 'MIAUL', 'MIL', 'MILA', 'MILAN', 'MILPA', 'MILT', 'MIN', 'MINA', 'MINT', 'MIT', 'MITU', 'MITUA', 'MULITA', 'MULT', 'MULTANI', 'MULTI', 'MUN', 'MUNIA', 'MUNT', 'MUT', 'MUTA', 'NAIL', 'NAIM', 'NAM', 'NAP', 'NAPU', 'NAT', 'NATL', 'NATU', 'NAUT', 'NIL', 'NIM', 'NIP', 'NIPA', 'NIT', 'NUL', 'NUM', 'NUMA', 'NUMP', 'NUPTIAL', 'NUT', 'PAIL', 'PAIN', 'PAINT', 'PAL', 'PALE', 'PALI', 'PALM', 'PALMIN', 'PALT', 'PAM', 'PAN', 'PANI', 'PANT', 'PAT', 'PATIN', 'PATU', 'PATULIN', 'PAU', 'PAUL', 'PAULIN', 'PAUT', 'PIA', 'PIAL', 'PIAN', 'PIL', 'PILAU', 'PILM', 'PILUM', 'PIM', 'PIMA', 'PIMAN', 'PIN', 'PINA', 'PINAL', 'PINT', 'PINTA', 'PIT', 'PITA', 'PITAU', 'PITMAN', 'PIU', 'PLAIN', 'PLAINT', 'PLAIT', 'PLAN', 'PLANT', 'PLANUM', 'PLAT', 'PLATINUM', 'PLI', 'PLIANT', 'PLIM', 'PLU', 'PLUM', 'PLUMA', 'PUA', 'PUAN', 'PUL', 'PULI', 'PULIAN', 'PUMA', 'PUN', 'PUNA', 'PUNT', 'PUNTA', 'PUNTAL', 'PUNTI', 'PUNTIL', 'PUT', 'PUTAIN', 'TAI', 'TAIL', 'TAIN', 'TAL', 'TALI', 'TALINUM', 'TAM', 'TAMIL', 'TAMP', 'TAMPIN', 'TAMUL', 'TAN', 'TAP', 'TAPU', 'TAPUL', 'TAU', 'TAULI', 'TAUM', 'TAUN', 'TIAM', 'TIL', 'TINA', 'TIPMAN', 'TIPULA', 'TUAN', 'TULA', 'TULIP', 'TULIPA', 'TUMAIN', 'TUMLI', 'TUMP', 'TUNA', 'TUNAL', 'TUPI', 'TUPIAN', 'TUPMAN', 'UINAL', 'UINTA', 'ULAN', 'ULMIN', 'ULNA', 'ULPAN', 'ULPANIM', 'ULTA', 'ULTIMA', 'UNAI', 'UNAL', 'UNAMI', 'UNAPT', 'UNIAT', 'UNIT', 'UNITAL', 'UNLAP', 'UNLIMP', 'UNLIT', 'UNMAIL', 'UNPLAIT', 'UNPLAT', 'UNTA', 'UNTAP', 'UNTIL', 'UPLA', 'UPLIT', 'UTAI', 'UTIL', 'UTINAM'},
  ),
  WordBuilderLevel(
    letters: ['S', 'I', 'N', 'G', 'U', 'L', 'A', 'R'],
    targetCount: 12,
    validWords: {'AGIN', 'AGNUS', 'AGR', 'AGRILUS', 'AGRIN', 'AIL', 'AILS', 'AIN', 'AINS', 'AINU', 'AINUS', 'AIR', 'AIRN', 'AIRNS', 'AIRS', 'AIS', 'ALG', 'ALGIN', 'ALGINS', 'ALIGN', 'ALIGNS', 'ALIN', 'ALNUS', 'ALS', 'ALUR', 'ANGUIS', 'ANGUS', 'ANI', 'ANIL', 'ANILS', 'ANIS', 'ANSI', 'ANSU', 'ANUS', 'ARG', 'ARGIL', 'ARGILS', 'ARGIN', 'ARGUS', 'ARIL', 'ARILS', 'ARIUS', 'ARLING', 'ARN', 'ARNI', 'ARS', 'ARUI', 'ASURI', 'AUG', 'AUL', 'AURIN', 'AURIS', 'AUS', 'GAIL', 'GAIN', 'GAINS', 'GAIR', 'GAIUS', 'GAL', 'GALI', 'GALS', 'GAN', 'GAR', 'GARN', 'GARNI', 'GARS', 'GARSIL', 'GAS', 'GAU', 'GAUL', 'GAULIN', 'GAULS', 'GAUN', 'GAUR', 'GAURS', 'GAUS', 'GIL', 'GILA', 'GILS', 'GIN', 'GINS', 'GIRL', 'GIRLS', 'GIRN', 'GIRNAL', 'GIRNS', 'GIS', 'GISLA', 'GLAIR', 'GLAIRS', 'GLANIS', 'GLANS', 'GLAR', 'GLAUR', 'GLIA', 'GLIS', 'GNAR', 'GNARL', 'GNARLS', 'GNARS', 'GNU', 'GNUS', 'GRA', 'GRAIL', 'GRAILS', 'GRAIN', 'GRAINS', 'GRAS', 'GRASNI', 'GRIN', 'GRINS', 'GRIS', 'GRUIS', 'GRUN', 'GRUS', 'GRUSIAN', 'GUAN', 'GUANS', 'GUAR', 'GUARS', 'GUL', 'GULA', 'GULAR', 'GULARIS', 'GULAS', 'GULS', 'GUN', 'GUNA', 'GUNL', 'GUNS', 'GUR', 'GURAN', 'GURIAN', 'GURL', 'GUS', 'GUSAIN', 'GUSLA', 'IAN', 'IANUS', 'IGLU', 'IGLUS', 'ILA', 'INGA', 'INGLU', 'INSULA', 'INSULAR', 'INULA', 'IRA', 'IRAN', 'IRGUN', 'LAG', 'LAGS', 'LAI', 'LAIN', 'LAIR', 'LAIRS', 'LAIUS', 'LAN', 'LANG', 'LANGI', 'LANGUR', 'LANGURS', 'LANIUS', 'LAR', 'LARI', 'LARIN', 'LARN', 'LARS', 'LARUS', 'LAS', 'LASI', 'LASING', 'LAUN', 'LAUR', 'LAURIN', 'LAUS', 'LIANG', 'LIANGS', 'LIAR', 'LIARS', 'LIAS', 'LIGAN', 'LIGANS', 'LIGAS', 'LIN', 'LINA', 'LING', 'LINGA', 'LINGAS', 'LINGS', 'LINGUA', 'LINS', 'LINUS', 'LIR', 'LIRA', 'LIRAS', 'LIS', 'LISA', 'LUG', 'LUGNAS', 'LUGS', 'LUI', 'LUIAN', 'LUIS', 'LUNA', 'LUNAR', 'LUNARS', 'LUNAS', 'LUNG', 'LUNGI', 'LUNGIS', 'LUNGS', 'LURA', 'LURG', 'LURI', 'LURING', 'LUSIAN', 'NAG', 'NAGS', 'NAIG', 'NAIL', 'NAILS', 'NAIR', 'NAIS', 'NAR', 'NARGIL', 'NARIS', 'NASI', 'NAUR', 'NGAI', 'NIAS', 'NIG', 'NIGUA', 'NIL', 'NILGAU', 'NILGAUS', 'NILS', 'NIRLS', 'NIS', 'NUL', 'NURL', 'NURLS', 'NUS', 'RAG', 'RAGI', 'RAGIS', 'RAGLIN', 'RAGS', 'RAIL', 'RAILS', 'RAIN', 'RAINS', 'RAIS', 'RALS', 'RAN', 'RANG', 'RANI', 'RANIS', 'RANLI', 'RAS', 'RASING', 'RAUL', 'RAULI', 'RAUN', 'RIA', 'RIAL', 'RIALS', 'RIG', 'RIGA', 'RIGS', 'RIN', 'RING', 'RINGS', 'RINS', 'RUA', 'RUG', 'RUGA', 'RUGAL', 'RUGS', 'RUIN', 'RUING', 'RUINS', 'RULING', 'RULINGS', 'RUN', 'RUNG', 'RUNGS', 'RUNS', 'RUS', 'RUSA', 'RUSIN', 'SAG', 'SAI', 'SAIL', 'SAIN', 'SAIR', 'SAL', 'SALUGI', 'SALUNG', 'SAN', 'SANG', 'SANGIL', 'SANGIR', 'SANGU', 'SAR', 'SARI', 'SARIN', 'SAU', 'SAUL', 'SAUR', 'SIAL', 'SIGLA', 'SIGN', 'SIGNA', 'SIGNAL', 'SINA', 'SINAL', 'SING', 'SINGULAR', 'SLAG', 'SLAIN', 'SLANG', 'SLING', 'SLUG', 'SLUIG', 'SLUING', 'SLUNG', 'SLUR', 'SNAG', 'SNAIL', 'SNARL', 'SNIG', 'SNIRL', 'SNUG', 'SNUR', 'SNURL', 'SUGAN', 'SUGAR', 'SUGI', 'SUI', 'SUINA', 'SUING', 'SULA', 'SULING', 'SUN', 'SUNG', 'SUNGAR', 'SUNIL', 'SUR', 'SURA', 'SURAL', 'SURG', 'SURIGA', 'SURNAI', 'UALIS', 'UANG', 'UGALI', 'UGLI', 'UGLIS', 'UGRIAN', 'UINAL', 'ULAN', 'ULANS', 'ULNA', 'ULNAR', 'ULNAS', 'UNAI', 'UNAIS', 'UNAL', 'UNRIG', 'UNRIGS', 'URAL', 'URALI', 'URAN', 'URIA', 'URIAL', 'URIAN', 'URINAL', 'URINALS', 'URLING', 'URNA', 'URNAL', 'URNS', 'URSA', 'URSAL', 'USAR', 'USING'},
  ),
  WordBuilderLevel(
    letters: ['C', 'A', 'R', 'N', 'I', 'V', 'A', 'L'],
    targetCount: 12,
    validWords: {'AAL', 'AANI', 'ACARI', 'ACINAR', 'AIL', 'AIN', 'AIR', 'AIRA', 'AIRAN', 'AIRN', 'AIVR', 'ALA', 'ALAI', 'ALAIN', 'ALAN', 'ALANI', 'ALAR', 'ALARIC', 'ALC', 'ALCA', 'ALIA', 'ALIN', 'ALVAN', 'ALVAR', 'ALVIA', 'ALVIN', 'ALVINA', 'ANA', 'ANAL', 'ANI', 'ANIL', 'ANLIA', 'ANVIL', 'ARA', 'ARAIN', 'ARC', 'ARCA', 'ARIA', 'ARIAN', 'ARID', 'ARIL', 'ARN', 'ARNA', 'ARNI', 'ARNICA', 'ARVAL', 'AVA', 'AVAIL', 'AVAL', 'AVAR', 'AVIAN', 'CAI', 'CAIN', 'CAIR', 'CAIRN', 'CAL', 'CALF', 'CALIN', 'CALINA', 'CALVIN', 'CAN', 'CANA', 'CANAL', 'CANALI', 'CANARI', 'CANLI', 'CAR', 'CARA', 'CARIAN', 'CARINA', 'CARINAL', 'CARL', 'CARLI', 'CARLIN', 'CARLINA', 'CARN', 'CARNAL', 'CARNIVAL', 'CARVAL', 'CAV', 'CAVA', 'CAVAL', 'CAVIA', 'CAVIAR', 'CAVIL', 'CAVIN', 'CAVINA', 'CIA', 'CIR', 'CIRL', 'CIV', 'CLAIR', 'CLAN', 'CLAR', 'CLARA', 'CLARAIN', 'CLARIN', 'CLARINA', 'CLAVA', 'CLAVI', 'CLAW', 'CLI', 'CLIN', 'CLIV', 'COAL', 'CRAAL', 'CRAIN', 'CRAN', 'CRANIA', 'CRANIAL', 'CRIN', 'CRINAL', 'IAN', 'ILA', 'INCA', 'INCL', 'INCR', 'INCRA', 'INVAR', 'IRA', 'IRAN', 'IVAN', 'LAC', 'LAI', 'LAIC', 'LAIN', 'LAIR', 'LAN', 'LANA', 'LANAI', 'LAR', 'LARCIN', 'LARI', 'LARIA', 'LARIN', 'LARN', 'LARVA', 'LAV', 'LAVA', 'LAVIC', 'LIANA', 'LIAR', 'LIN', 'LINA', 'LINAC', 'LIR', 'LIRA', 'LIV', 'NAA', 'NAIL', 'NAIR', 'NAIRA', 'NAR', 'NARC', 'NARIAL', 'NARIC', 'NARICA', 'NAV', 'NAVAL', 'NAVAR', 'NAVI', 'NIL', 'NIVAL', 'RACIAL', 'RAIA', 'RAIL', 'RAIN', 'RAN', 'RANA', 'RANAL', 'RANI', 'RANLI', 'RAVI', 'RAVIN', 'RIA', 'RIAL', 'RIC', 'RIN', 'RIVA', 'RIVAL', 'VAIL', 'VAIN', 'VAIR', 'VALI', 'VANIR', 'VARA', 'VARAN', 'VARI', 'VARIA', 'VARIAC', 'VARICAL', 'VARNA', 'VIAL', 'VICA', 'VICAR', 'VICARA', 'VILA', 'VINA', 'VINAL', 'VINCA', 'VIRA', 'VIRAL', 'VIRL', 'VRAIC', 'VRIL'},
  ),
  WordBuilderLevel(
    letters: ['D', 'I', 'S', 'C', 'O', 'V', 'E', 'R'],
    targetCount: 12,
    validWords: {'CEDI', 'CEDIS', 'CERO', 'CEROID', 'CEROS', 'CERVID', 'CERVOID', 'CID', 'CIDER', 'CIDERS', 'CIE', 'CIR', 'CIRE', 'CIRES', 'CIS', 'CISE', 'CIV', 'CIVE', 'COD', 'CODE', 'CODER', 'CODERS', 'CODES', 'CODS', 'COE', 'COED', 'COEDS', 'COES', 'COIR', 'COIRS', 'COR', 'CORD', 'CORDIES', 'CORDIS', 'CORDS', 'CORE', 'CORED', 'COREID', 'CORES', 'CORSE', 'CORSIE', 'CORV', 'CORVE', 'CORVED', 'CORVES', 'COS', 'COSE', 'COSED', 'COSIE', 'COSIER', 'COVE', 'COVED', 'COVER', 'COVERS', 'COVES', 'COVID', 'CRE', 'CREDO', 'CREDOS', 'CRES', 'CREVIS', 'CRIED', 'CRIES', 'CRIS', 'CRO', 'CROIS', 'CROISE', 'CROSE', 'DCOR', 'DEC', 'DECO', 'DECOR', 'DECORS', 'DEIS', 'DER', 'DERIC', 'DERIV', 'DERO', 'DERV', 'DES', 'DESC', 'DESI', 'DEV', 'DEVI', 'DEVISOR', 'DEVOIR', 'DEVOIRS', 'DEVS', 'DICE', 'DICER', 'DICERS', 'DICES', 'DIE', 'DIER', 'DIES', 'DIOC', 'DIOSE', 'DIRE', 'DIS', 'DISC', 'DISCO', 'DISCOVER', 'DIV', 'DIVE', 'DIVER', 'DIVERS', 'DIVES', 'DIVORCE', 'DIVORCES', 'DOC', 'DOCS', 'DOE', 'DOER', 'DOERS', 'DOES', 'DOR', 'DORI', 'DORIC', 'DORIES', 'DORIS', 'DORS', 'DORSE', 'DORSI', 'DOS', 'DOSE', 'DOSER', 'DOVE', 'DOVER', 'DOVES', 'DRIE', 'DRIES', 'DRIVE', 'DRIVES', 'DROVE', 'DROVES', 'DSRI', 'ECOD', 'ECOID', 'EIDOS', 'ERIC', 'ERIS', 'EROS', 'ESCROD', 'ESODIC', 'ICE', 'ICED', 'ICES', 'ICOD', 'IDE', 'IDEO', 'IDES', 'IDO', 'IDOSE', 'IOCS', 'IODE', 'IRE', 'IRED', 'IREOS', 'IRES', 'ISED', 'ODE', 'ODES', 'ODIC', 'OECI', 'ORC', 'ORCS', 'ORD', 'ORE', 'ORED', 'ORES', 'OSE', 'OSIDE', 'OSIER', 'OVER', 'OVERS', 'OVID', 'OVIS', 'REC', 'RECD', 'RECS', 'RED', 'REDO', 'REDOS', 'REDS', 'REID', 'REIS', 'RES', 'RESID', 'REVS', 'RIC', 'RICE', 'RICED', 'RICES', 'RID', 'RIDE', 'RIDES', 'RIDS', 'RIE', 'RIES', 'RIO', 'RISE', 'RIVE', 'RIVED', 'RIVES', 'RIVO', 'RIVOSE', 'ROC', 'ROCS', 'ROD', 'RODE', 'RODS', 'ROE', 'ROED', 'ROES', 'ROI', 'ROID', 'ROS', 'ROSCID', 'ROSE', 'ROSED', 'ROSIED', 'ROVE', 'ROVED', 'ROVES', 'SCI', 'SCORE', 'SCORED', 'SCOVE', 'SCRIDE', 'SCRIVE', 'SCRIVED', 'SCROD', 'SEDOVIC', 'SEID', 'SEOR', 'SERI', 'SERIC', 'SERIO', 'SERO', 'SERV', 'SERVO', 'SIC', 'SICE', 'SICER', 'SID', 'SIDE', 'SIDER', 'SIE', 'SIER', 'SIRE', 'SIRED', 'SIROC', 'SIVER', 'SOCE', 'SOD', 'SODIC', 'SOIR', 'SORD', 'SORE', 'SORI', 'SVCE', 'VEDIC', 'VEDRO', 'VEI', 'VER', 'VERD', 'VERDI', 'VERI', 'VERS', 'VERSO', 'VICE', 'VICED', 'VICES', 'VIDE', 'VIDEO', 'VIDEOS', 'VIED', 'VIER', 'VIERS', 'VIES', 'VIRE', 'VIREO', 'VIREOS', 'VIRES', 'VIROSE', 'VISE', 'VISED', 'VISOR', 'VISORED', 'VOCE', 'VOCES', 'VODER', 'VOES', 'VOICE', 'VOICED', 'VOICER', 'VOICERS', 'VOICES', 'VOID', 'VOIDER', 'VOIDERS', 'VOIDS'},
  ),
  WordBuilderLevel(
    letters: ['K', 'E', 'Y', 'B', 'O', 'A', 'R', 'D'],
    targetCount: 12,
    validWords: {'ABD', 'ABE', 'ABED', 'ABEY', 'ABO', 'ABODE', 'ABODY', 'ABORD', 'ABY', 'ABYE', 'ADE', 'ADO', 'ADOBE', 'ADOR', 'ADORE', 'ADRY', 'ADY', 'AER', 'AERO', 'AERY', 'AKE', 'AKED', 'AKER', 'AKEY', 'AKRE', 'ARB', 'ARDEB', 'ARE', 'ARED', 'ARK', 'ARO', 'ARY', 'AYE', 'AYRE', 'BAD', 'BADE', 'BAE', 'BAKE', 'BAKED', 'BAKER', 'BAKERY', 'BAR', 'BARD', 'BARDE', 'BARDO', 'BARDY', 'BARE', 'BARED', 'BARK', 'BARKED', 'BARKEY', 'BARKY', 'BARYE', 'BAY', 'BAYED', 'BAYOK', 'BEA', 'BEAD', 'BEADY', 'BEAK', 'BEAKY', 'BEAR', 'BEARD', 'BEARDY', 'BED', 'BEDARK', 'BEDAY', 'BER', 'BERAY', 'BERK', 'BEY', 'BOA', 'BOAR', 'BOARD', 'BOARDY', 'BOD', 'BODE', 'BODER', 'BODY', 'BOE', 'BOER', 'BOKARD', 'BOKE', 'BOR', 'BORA', 'BORAK', 'BORD', 'BORE', 'BOREAD', 'BORED', 'BOY', 'BOYAR', 'BOYARD', 'BOYD', 'BOYER', 'BRA', 'BRAD', 'BRAE', 'BRAKE', 'BRAKED', 'BRAKY', 'BRAY', 'BRAYE', 'BRAYED', 'BREAD', 'BREAK', 'BRED', 'BREY', 'BRO', 'BROAD', 'BROD', 'BROKE', 'BYARD', 'BYE', 'BYRE', 'BYROAD', 'DAB', 'DAE', 'DAER', 'DAKER', 'DAR', 'DARB', 'DARBY', 'DARE', 'DARK', 'DARKEY', 'DARKY', 'DAY', 'DEA', 'DEAR', 'DEARY', 'DEB', 'DEBAR', 'DEBARK', 'DER', 'DERAY', 'DERBY', 'DERK', 'DERO', 'DEY', 'DOA', 'DOAB', 'DOB', 'DOBE', 'DOBRA', 'DOBY', 'DOCK', 'DOE', 'DOEK', 'DOER', 'DOKE', 'DOR', 'DORA', 'DORAB', 'DORAY', 'DOREY', 'DORY', 'DRAB', 'DRAKE', 'DRAY', 'DREK', 'DREY', 'DRY', 'DYAK', 'DYE', 'DYER', 'DYKE', 'DYKER', 'EAR', 'ERA', 'EYRA', 'KARO', 'KAY', 'KAYO', 'KAYOED', 'KBAR', 'KEA', 'KEB', 'KEBAR', 'KEBYAR', 'KED', 'KEDAR', 'KER', 'KERB', 'KERO', 'KEY', 'KEYBOARD', 'KOA', 'KOAE', 'KODA', 'KORA', 'KORE', 'KOREA', 'KORY', 'KYAR', 'OAK', 'OAKY', 'OAR', 'OARED', 'OARY', 'OBEY', 'ODE', 'ODEA', 'OKAY', 'OKAYED', 'OKER', 'OKEY', 'OKRA', 'ORA', 'ORAD', 'ORAE', 'ORB', 'ORBED', 'ORBY', 'ORD', 'ORE', 'OREAD', 'ORED', 'ORKEY', 'OYER', 'RAB', 'RAD', 'RADEK', 'RAKE', 'RAKED', 'RAOB', 'RAY', 'RAYED', 'REA', 'READ', 'READY', 'REAK', 'REB', 'RED', 'REDBAY', 'REDO', 'ROAD', 'ROAK', 'ROB', 'ROBE', 'ROBED', 'ROD', 'RODE', 'ROE', 'ROED', 'ROEY', 'ROK', 'ROKA', 'ROKE', 'ROKEY', 'ROKY', 'ROY', 'RYE', 'RYKE', 'RYKED', 'YADE', 'YAK', 'YAR', 'YARB', 'YARD', 'YARE', 'YARK', 'YARKE', 'YEA', 'YEAR', 'YEARD', 'YERB', 'YERBA', 'YERD', 'YERK', 'YODE', 'YOKE', 'YOKED', 'YOKER', 'YORE', 'YORK', 'YRBK'},
  ),
];

class WordBuilderScreen extends StatefulWidget {
  final int? dailyLevelIndex;
  const WordBuilderScreen({super.key, this.dailyLevelIndex});
  @override
  State<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends State<WordBuilderScreen> {
  int _levelIndex = 0;
  late WordBuilderLevel _level;
  final List<String> _currentGuess = [];
  final List<int> _selectedIndices = [];
  final Set<String> _foundWords = {};
  String _message ='';
  bool _won = false;
  bool _playDailyMode = false;
  String _dailyModifierType = '';
  late final Set<String> _allWordsPool;

  final GlobalKey _honeycombKey = GlobalKey();
  final List<Offset> _linePoints = [];
  final ValueNotifier<Offset?> _currentDragNotifier = ValueNotifier<Offset?>(null);

  int _hintCount = 0;
  late final List<WordBuilderLevel> _sortedLevels;

  @override
  void dispose() {
    _currentDragNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final Set<String> pool = {};
    for (final l in _kLevels) {
      pool.addAll(l.validWords);
    }
    pool.addAll(_kCommonEnglishWords);
    _allWordsPool = pool;

    final allSorted = List<WordBuilderLevel>.from(_kLevels)
      ..sort((a, b) => a.letters.length.compareTo(b.letters.length));

    _sortedLevels = List<WordBuilderLevel>.generate(50, (i) {
      final tier = i ~/ 4;
      final int lettersCount = min(9, 4 + tier);
      final int targetCount = 3 + tier * 2;

      // Try to find a level in _kLevels that has exactly lettersCount
      var matches = _kLevels.where((l) => l.letters.length == lettersCount).toList();
      if (matches.isNotEmpty) {
        final baseLevel = matches[i % matches.length];
        final expanded = _expandValidWords(baseLevel.letters, baseLevel.validWords);
        return WordBuilderLevel(
          letters: baseLevel.letters,
          targetCount: min(targetCount, expanded.length),
          validWords: expanded,
        );
      }

      // Fallback: grab from allSorted list
      final idx = (i * allSorted.length / 50).floor();
      final baseLevel = allSorted[idx];
      final expanded = _expandValidWords(baseLevel.letters, baseLevel.validWords);
      return WordBuilderLevel(
        letters: baseLevel.letters,
        targetCount: min(targetCount, expanded.length),
        validWords: expanded,
      );
    });
    // Default synchronous initialization to avoid LateInitializationError
    _level = _sortedLevels[0];
    _initLevel();
  }

  Future<void> _initLevel() async {
    _hintCount = await HintManager.getHints('wordbuilder');
    final prefs = await SharedPreferences.getInstance();
    _playDailyMode = prefs.getBool('play_daily_mode') ?? false;
    if (_playDailyMode) {
      _dailyModifierType = prefs.getString('daily_modifier_type') ?? '';
    } else {
      _dailyModifierType = '';
    }

    int targetLevel = 0;
    if (widget.dailyLevelIndex != null) {
      targetLevel = widget.dailyLevelIndex!;
    } else {
      targetLevel = prefs.getInt('level_wordbuilder') ?? 0;
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
        final savedStateStr = prefs.getString('normal_wordbuilder_state');
        if (savedStateStr != null) {
          try {
            final data = jsonDecode(savedStateStr);
            if (data['levelIndex'] == _levelIndex) {
              final continueGame = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: context.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.textMuted.withAlpha(40)),
                  ),
                  title: Text(
                    'Continue Game?',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
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
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx, true); // Continue
                      },
                      child: Text(
                        'Continue',
                        style: GoogleFonts.outfit(color: AppTheme.dustyMauve, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ) ?? false;

              if (continueGame) {
                final List<dynamic> wordsData = data['foundWords'];
                final Set<String> loadedFoundWords = Set<String>.from(wordsData.cast<String>());
                final List<dynamic>? lettersData = data['letters'];
                final List<dynamic>? validWordsData = data['validWords'];
                setState(() {
                  _foundWords.clear();
                  _foundWords.addAll(loadedFoundWords);
                  _won = data['won'];
                  if (lettersData != null && validWordsData != null) {
                    final List<String> loadedLetters = List<String>.from(lettersData.cast<String>());
                    final Set<String> loadedValidWords = Set<String>.from(validWordsData.cast<String>());
                    _level = WordBuilderLevel(
                      letters: loadedLetters,
                      targetCount: _playDailyMode && _dailyModifierType == 'whisper' ? 15 : _level.targetCount,
                      validWords: loadedValidWords,
                    );
                  }
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
    final state = {
      'levelIndex': _levelIndex,
      'foundWords': _foundWords.toList(),
      'won': _won,
      'letters': _level.letters,
      'validWords': _level.validWords.toList(),
    };
    await prefs.setString('normal_wordbuilder_state', jsonEncode(state));
  }

  Future<void> _clearNormalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('normal_wordbuilder_state');
  }

  Future<void> _savePersistedLevel(int lvl) async {
    if (_playDailyMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level_wordbuilder', lvl);
    final earned = await HintManager.onLevelCleared('wordbuilder');
    final newCount = await HintManager.getHints('wordbuilder');
    setState(() {
      _hintCount = newCount;
    });
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hint earned! (Total: $newCount)', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.accentFor('wordbuilder'),
        ),
      );
    }
    await _clearNormalState();
  }

  Future<void> _useHint() async {
    if (_won || _hintCount <= 0) return;
    String? targetWord;
    for (final word in _level.validWords) {
      if (!_foundWords.contains(word)) {
        targetWord = word;
        break;
      }
    }
    if (targetWord == null) return;

    await HintManager.useHint('wordbuilder');
    final newCount = await HintManager.getHints('wordbuilder');

    setState(() {
      _hintCount = newCount;
      final clue = targetWord!.substring(0, 1).toUpperCase();
      _message = 'Hint: Try a word starting with "$clue" (${targetWord.length} letters)';
      AudioManager.playClick();
    });
  }

  void _loadLevel() {
    final baseLevel = _sortedLevels[_levelIndex % _sortedLevels.length];
    final int target = _playDailyMode && _dailyModifierType == 'whisper' ? 15 : baseLevel.targetCount;
    final Set<String> vWords = _playDailyMode && _dailyModifierType == 'whisper'
        ? _expandValidWords(baseLevel.letters, _allWordsPool)
        : baseLevel.validWords;
    _level = WordBuilderLevel(
      letters: List<String>.from(baseLevel.letters),
      targetCount: target,
      validWords: vWords,
    );
    _currentGuess.clear();
    _selectedIndices.clear();
    _foundWords.clear();
    _linePoints.clear();
    _currentDragNotifier.value = null;
    _message ='';
    _won = false;
  }

  void _reset() => setState(() => _loadLevel());

  void _addLetterToGuess(int index, Offset center) {
    if (_won) return;
    if (_selectedIndices.length >= 2 && _selectedIndices[_selectedIndices.length - 2] == index) {
      setState(() {
        _currentGuess.removeLast();
        _selectedIndices.removeLast();
        _linePoints.removeLast();
        _currentDragNotifier.value = center;
      });
      return;
    }
    if (!_selectedIndices.contains(index)) {
      setState(() {
        _currentGuess.add(_level.letters[index]);
        _selectedIndices.add(index);
        _linePoints.add(center);
        _currentDragNotifier.value = center;
        _message ='';
        if (_selectedIndices.length == 1) {
          AudioManager.playClick();
        }
      });
    }
  }

  void _handlePan(Offset globalPos) {
    final box = _honeycombKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPos);
    final size = box.size.width;
    final ctr = Offset(size / 2, size / 2);
    final scaleVal = size / 220.0;
    final n = _level.letters.length;
    final radius = 78.0 * scaleVal;

    for (int i = 0; i < n; i++) {
      final angle = i * 2 * pi / n - pi / 2;
      final buttonCenter = ctr + Offset(radius * cos(angle), radius * sin(angle));
      final dist = (local - buttonCenter).distance;
      if (dist < 22.0 * scaleVal) {
        _addLetterToGuess(i, buttonCenter);
        return;
      }
    }

    _currentDragNotifier.value = local;
  }

  void _handlePanEnd() {
    if (_currentGuess.isNotEmpty) {
      _submitWord();
    }
    _currentDragNotifier.value = null;
    setState(() {
      _selectedIndices.clear();
      _linePoints.clear();
    });
  }

  void _backspace() {
    if (_won || _currentGuess.isEmpty) return;
    setState(() {
      _currentGuess.removeLast();
      if (_selectedIndices.isNotEmpty) {
        _selectedIndices.removeLast();
      }
      if (_linePoints.isNotEmpty) {
        _linePoints.removeLast();
      }
    });
  }


  void _submitWord() {
    if (_won || _currentGuess.isEmpty) return;
    final word = _currentGuess.join();
    if (_foundWords.contains(word)) {
      setState(() {
        _message ='Already found"$word"!';
        _currentGuess.clear();
        _selectedIndices.clear();
        _linePoints.clear();
        _currentDragNotifier.value = null;
        AudioManager.playFail();
      });
      return;
    }
    if (_level.validWords.contains(word)) {
      setState(() {
        _foundWords.add(word);
        _message ='Nice! +1 word';
        _currentGuess.clear();
        _selectedIndices.clear();
        _linePoints.clear();
        _currentDragNotifier.value = null;
        if (_foundWords.length >= _level.targetCount) {
          _won = true;
          _message ='Level Complete!';
          AudioManager.playSuccess();
          _savePersistedLevel(_levelIndex + 1);
        } else {
          AudioManager.playClick();
        }
      });
      if (_playDailyMode && _dailyModifierType == 'whisper' && !_won) {
        if (_foundWords.length % 5 == 0) {
          _whisperMutateGrid();
        }
      }
      _saveNormalState();
    } else {
      setState(() {
        _message ='"$word"is not a valid word!';
        _currentGuess.clear();
        _selectedIndices.clear();
        _linePoints.clear();
        _currentDragNotifier.value = null;
        AudioManager.playFail();
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final accentColor = AppTheme.accentFor('wordbuilder');
    final n = _level.letters.length;
    return Scaffold(
      backgroundColor: context.bgDark,
      appBar: AppBar(
        backgroundColor: context.bgDark,
        foregroundColor: context.textPrimary,
        title: Text('Word Builder', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: context.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.lightbulb_outline, size: 20, color: context.textMuted),
                Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 6,
                    backgroundColor: Colors.amber,
                    child: Text(
_hintCount == 0 ? '+' : '$_hintCount',
                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: !_won
                ? () async {
                    if (_hintCount > 0) {
                      _useHint();
                    } else {
                      await BuyHintsDialog.show(
                        context,
                        initialGameId: 'wordbuilder',
                        onPurchaseComplete: () async {
                          final newCount = await HintManager.getHints('wordbuilder');
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
            onPressed: () => RulesHelper.showRulesBottomSheet(context,'wordbuilder','Word Builder'),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _reset, color: context.textMuted),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                _playDailyMode ? 'Daily' : 'Level ${_levelIndex + 1}',
                style: AppTheme.numberStyle(color: accentColor, fontSize: context.scale(13)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Column(
            children: [
              Text(
                'Drag over letters to connect and build words',
                style: GoogleFonts.outfit(color: context.textSecondary, fontSize: context.scale(13)),
              ),
              const SizedBox(height: 8),
              Text(
                'Find ${_level.targetCount} words to pass',
                style: GoogleFonts.outfit(color: accentColor, fontSize: context.scale(13), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Guessed words scrollable area taking all remaining upper space
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: List.generate(_level.targetCount, (index) {
                        final list = _foundWords.toList();
                        final hasWord = index < list.length;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: hasWord ? accentColor.withOpacity(0.2) : context.bgCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasWord ? accentColor : context.textMuted.withAlpha(50),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            hasWord ? list[index] : '• • •',
                            style: GoogleFonts.outfit(
                              fontSize: context.scale(13),
                              fontWeight: FontWeight.w700,
                              color: hasWord ? context.textPrimary : context.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Message / Display Current Guess
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _message,
                        style: GoogleFonts.outfit(
                          color: _won ? accentColor : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: context.scale(13),
                        ),
                      ),
                    ),
                  // Current selection display - tap to submit
                  GestureDetector(
                    onTap: () {
                      if (_currentGuess.isNotEmpty) _submitWord();
                    },
                    child: Container(
                      height: 45,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: context.textMuted.withAlpha(30), width: 1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentGuess.join(),
                            style: GoogleFonts.outfit(
                              fontSize: context.scale(24),
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              letterSpacing: 4,
                            ),
                          ),
                          if (_currentGuess.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle_outline, size: context.scale(18), color: accentColor.withOpacity(0.7)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Circular Letter Selector (Letters Wheel pushed to bottom)
              Center(
                child: RepaintBoundary(
                  child: GestureDetector(
                    onPanStart: (d) => _handlePan(d.globalPosition),
                    onPanUpdate: (d) => _handlePan(d.globalPosition),
                    onPanEnd: (d) => _handlePanEnd(),
                    child: SizedBox(
                      key: _honeycombKey,
                      width: context.scale(220),
                      height: context.scale(220),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Line paint behind letters
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LineConnectorPainter(
                                points: _linePoints,
                                currentDragNotifier: _currentDragNotifier,
                                color: accentColor,
                              ),
                            ),
                          ),
                        // Circular letter buttons
                        ...List.generate(n, (index) {
                          final angle = index * 2 * pi / n - pi / 2;
                          final radius = context.scale(78.0);
                          final x = radius * cos(angle);
                          final y = radius * sin(angle);
                          final letter = _level.letters[index];
                          final isSel = _selectedIndices.contains(index);

                          return Positioned(
                            left: context.scale(110) + x - context.scale(22),
                            top: context.scale(110) + y - context.scale(22),
                            child: Container(
                              width: context.scale(44),
                              height: context.scale(44),
                              decoration: BoxDecoration(
                                color: isSel ? accentColor : context.bgCard,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.transparent : context.textMuted.withAlpha(100),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  letter,
                                  style: GoogleFonts.outfit(
                                    fontSize: context.scale(20),
                                    fontWeight: FontWeight.w800,
                                    color: isSel ? Colors.white : context.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
              // Action button - backspace only (drag auto-submits, tap guess to submit)
              if (!_won)
                Center(
                  child: IconButton(
                    icon: Icon(Icons.backspace_outlined, size: context.scale(22)),
                    onPressed: _backspace,
                    color: context.textSecondary,
                  ),
                ),
              if (_won) ...[
                const SizedBox(height: 12),
                Center(
                  child: AutoNextCountdown(
                    onNext: _nextLevel,
                    accentColor: accentColor,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      if (_won && _playDailyMode)
        Positioned.fill(
          child: ChallengeClearedOverlay(
            accentColor: accentColor,
            onComplete: () {
              Navigator.pop(context, true);
            },
          ),
        ),
      ],
    ),
  );
}

  void _whisperMutateGrid() {
    if (_level.letters.isEmpty) return;
    final rng = Random();
    final lettersList = List<String>.from(_level.letters);
    final count = (lettersList.length / 2).floor();

    final indices = List.generate(lettersList.length, (i) => i)..shuffle(rng);
    final selectedIndices = indices.take(count).toList();

    final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

    for (final idx in selectedIndices) {
      final available = alphabet.where((l) => !lettersList.contains(l)).toList();
      if (available.isNotEmpty) {
        final newLetter = available[rng.nextInt(available.length)];
        lettersList[idx] = newLetter;
      }
    }

    // Ensure at least one vowel in the mutated grid
    final vowels = {'A', 'E', 'I', 'O', 'U'};
    bool hasVowel = lettersList.any((l) => vowels.contains(l));
    if (!hasVowel) {
      final randVowel = ['A', 'E', 'I', 'O', 'U'][rng.nextInt(5)];
      if (selectedIndices.isNotEmpty) {
        lettersList[selectedIndices[0]] = randVowel;
      } else {
        lettersList[0] = randVowel;
      }
    }

    setState(() {
      final newValidWords = _expandValidWords(lettersList, _allWordsPool);
      _level = WordBuilderLevel(
        letters: lettersList,
        targetCount: _playDailyMode && _dailyModifierType == 'whisper' ? 15 : _level.targetCount,
        validWords: newValidWords,
      );
      _message = 'Whisper! Half of the letters changed!';
    });
    AudioManager.playFail();
  }
}

class _LineConnectorPainter extends CustomPainter {
  final List<Offset> points;
  final ValueNotifier<Offset?> currentDragNotifier;
  final Color color;
  _LineConnectorPainter({required this.points, required this.currentDragNotifier, required this.color})
      : super(repaint: currentDragNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    final currentDrag = currentDragNotifier.value;
    if (currentDrag != null) {
      path.lineTo(currentDrag.dx, currentDrag.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LineConnectorPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
           oldDelegate.color != color;
  }
}

bool _canSpell(String word, List<String> letters) {
  final tempLetters = List<String>.from(letters);
  for (int i = 0; i < word.length; i++) {
    final char = word[i];
    if (!tempLetters.remove(char)) {
      return false;
    }
  }
  return true;
}

Set<String> _expandValidWords(List<String> letters, Set<String> pool) {
  final Set<String> result = {};
  for (final word in pool) {
    if (word.length >= 3 && _canSpell(word, letters)) {
      result.add(word);
    }
  }
  return result;
}

const Set<String> _kCommonEnglishWords = {
  'ABOUT', 'SEARCH', 'OTHER', 'WHICH', 'THEIR', 'THERE', 'CONTACT', 'BUSINESS', 'ONLINE', 'FIRST', 'WOULD', 'SERVICES',
  'THESE', 'CLICK', 'SERVICE', 'PRICE', 'PEOPLE', 'STATE', 'EMAIL', 'HEALTH', 'WORLD', 'PRODUCTS', 'MUSIC', 'SHOULD',
  'PRODUCT', 'SYSTEM', 'POLICY', 'NUMBER', 'PLEASE', 'SUPPORT', 'MESSAGE', 'AFTER', 'SOFTWARE', 'VIDEO', 'WHERE', 'RIGHTS',
  'PUBLIC', 'BOOKS', 'SCHOOL', 'THROUGH', 'LINKS', 'REVIEW', 'YEARS', 'ORDER', 'PRIVACY', 'ITEMS', 'COMPANY', 'GROUP',
  'UNDER', 'GENERAL', 'RESEARCH', 'JANUARY', 'REVIEWS', 'PROGRAM', 'GAMES', 'COULD', 'GREAT', 'UNITED', 'HOTEL', 'CENTER',
  'STORE', 'TRAVEL', 'COMMENTS', 'REPORT', 'MEMBER', 'DETAILS', 'TERMS', 'BEFORE', 'HOTELS', 'RIGHT', 'BECAUSE', 'LOCAL',
  'THOSE', 'USING', 'RESULTS', 'OFFICE', 'NATIONAL', 'DESIGN', 'POSTED', 'INTERNET', 'ADDRESS', 'WITHIN', 'STATES', 'PHONE',
  'SHIPPING', 'RESERVED', 'SUBJECT', 'BETWEEN', 'FORUM', 'FAMILY', 'BASED', 'BLACK', 'CHECK', 'SPECIAL', 'PRICES', 'WEBSITE',
  'INDEX', 'BEING', 'WOMEN', 'TODAY', 'SOUTH', 'PROJECT', 'PAGES', 'VERSION', 'SECTION', 'FOUND', 'SPORTS', 'HOUSE',
  'RELATED', 'SECURITY', 'COUNTY', 'AMERICAN', 'PHOTO', 'MEMBERS', 'POWER', 'WHILE', 'NETWORK', 'COMPUTER', 'SYSTEMS', 'THREE',
  'TOTAL', 'PLACE', 'DOWNLOAD', 'WITHOUT', 'ACCESS', 'THINK', 'NORTH', 'CURRENT', 'POSTS', 'MEDIA', 'CONTROL', 'WATER',
  'HISTORY', 'PICTURES', 'PERSONAL', 'SINCE', 'GUIDE', 'BOARD', 'LOCATION', 'CHANGE', 'WHITE', 'SMALL', 'RATING', 'CHILDREN',
  'DURING', 'RETURN', 'STUDENTS', 'SHOPPING', 'ACCOUNT', 'TIMES', 'SITES', 'LEVEL', 'DIGITAL', 'PROFILE', 'PREVIOUS', 'EVENTS',
  'HOURS', 'IMAGE', 'TITLE', 'ANOTHER', 'SHALL', 'PROPERTY', 'CLASS', 'STILL', 'MONEY', 'QUALITY', 'EVERY', 'LISTING',
  'CONTENT', 'COUNTRY', 'PRIVATE', 'LITTLE', 'VISIT', 'TOOLS', 'REPLY', 'CUSTOMER', 'DECEMBER', 'COMPARE', 'MOVIES', 'INCLUDE',
  'COLLEGE', 'VALUE', 'ARTICLE', 'PROVIDE', 'SOURCE', 'AUTHOR', 'PRESS', 'LEARN', 'AROUND', 'PRINT', 'COURSE', 'CANADA',
  'PROCESS', 'STOCK', 'TRAINING', 'CREDIT', 'POINT', 'SCIENCE', 'ADVANCED', 'SALES', 'ENGLISH', 'ESTATE', 'SELECT', 'WINDOWS',
  'PHOTOS', 'THREAD', 'CATEGORY', 'LARGE', 'GALLERY', 'TABLE', 'REGISTER', 'HOWEVER', 'OCTOBER', 'NOVEMBER', 'MARKET', 'LIBRARY',
  'REALLY', 'ACTION', 'START', 'SERIES', 'MODEL', 'FEATURES', 'INDUSTRY', 'HUMAN', 'PROVIDED', 'REQUIRED', 'SECOND', 'MOVIE',
  'FORUMS', 'MARCH', 'BETTER', 'YAHOO', 'GOING', 'MEDICAL', 'FRIEND', 'SERVER', 'STUDY', 'STAFF', 'ARTICLES', 'FEEDBACK',
  'AGAIN', 'LOOKING', 'ISSUES', 'APRIL', 'NEVER', 'USERS', 'COMPLETE', 'STREET', 'TOPIC', 'COMMENT', 'THINGS', 'WORKING',
  'AGAINST', 'STANDARD', 'PERSON', 'BELOW', 'MOBILE', 'PARTY', 'PAYMENT', 'LOGIN', 'STUDENT', 'PROGRAMS', 'OFFERS', 'LEGAL',
  'ABOVE', 'RECENT', 'STORES', 'PROBLEM', 'MEMORY', 'SOCIAL', 'AUGUST', 'QUOTE', 'LANGUAGE', 'STORY', 'OPTIONS', 'RATES',
  'CREATE', 'YOUNG', 'AMERICA', 'FIELD', 'PAPER', 'SINGLE', 'EXAMPLE', 'GIRLS', 'PASSWORD', 'LATEST', 'QUESTION', 'CHANGES',
  'NIGHT', 'TEXAS', 'POKER', 'STATUS', 'BROWSE', 'ISSUE', 'RANGE', 'BUILDING', 'SELLER', 'COURT', 'FEBRUARY', 'ALWAYS',
  'RESULT', 'AUDIO', 'LIGHT', 'WRITE', 'OFFER', 'GROUPS', 'GIVEN', 'FILES', 'EVENT', 'RELEASE', 'ANALYSIS', 'REQUEST',
  'CHINA', 'MAKING', 'PICTURE', 'NEEDS', 'POSSIBLE', 'MIGHT', 'MONTH', 'MAJOR', 'AREAS', 'FUTURE', 'SPACE', 'CARDS',
  'PROBLEMS', 'LONDON', 'MEETING', 'BECOME', 'INTEREST', 'CHILD', 'ENTER', 'SHARE', 'SIMILAR', 'GARDEN', 'SCHOOLS', 'MILLION',
  'ADDED', 'LISTED', 'LEARNING', 'ENERGY', 'DELIVERY', 'POPULAR', 'STORIES', 'JOURNAL', 'REPORTS', 'WELCOME', 'CENTRAL', 'IMAGES',
  'NOTICE', 'ORIGINAL', 'RADIO', 'UNTIL', 'COLOR', 'COUNCIL', 'INCLUDES', 'TRACK', 'ARCHIVE', 'OTHERS', 'FORMAT', 'LEAST',
  'SOCIETY', 'MONTHS', 'SAFETY', 'FRIENDS', 'TRADE', 'EDITION', 'MESSAGES', 'FURTHER', 'UPDATED', 'HAVING', 'PROVIDES', 'DAVID',
  'ALREADY', 'GREEN', 'STUDIES', 'CLOSE', 'COMMON', 'DRIVE', 'SPECIFIC', 'SEVERAL', 'LIVING', 'CALLED', 'SHORT', 'DISPLAY',
  'LIMITED', 'POWERED', 'MEANS', 'DIRECTOR', 'DAILY', 'BEACH', 'NATURAL', 'WHETHER', 'PERIOD', 'PLANNING', 'DATABASE', 'OFFICIAL',
  'WEATHER', 'AVERAGE', 'WINDOW', 'FRANCE', 'REGION', 'ISLAND', 'RECORD', 'DIRECT', 'RECORDS', 'DISTRICT', 'CALENDAR', 'COSTS',
  'STYLE', 'FRONT', 'UPDATE', 'PARTS', 'EARLY', 'MILES', 'SOUND', 'RESOURCE', 'PRESENT', 'EITHER', 'DOCUMENT', 'WORKS',
  'MATERIAL', 'WRITTEN', 'FEDERAL', 'HOSTING', 'RULES', 'FINAL', 'ADULT', 'TICKETS', 'THING', 'CENTRE', 'CHEAP', 'FINANCE',
  'MINUTES', 'THIRD', 'GIFTS', 'EUROPE', 'READING', 'TOPICS', 'COVER', 'USUALLY', 'TOGETHER', 'VIDEOS', 'PERCENT', 'FUNCTION',
  'GETTING', 'GLOBAL', 'ECONOMIC', 'PLAYER', 'PROJECTS', 'LYRICS', 'OFTEN', 'SUBMIT', 'GERMANY', 'AMOUNT', 'WATCH', 'INCLUDED',
  'THOUGH', 'THANKS', 'DEALS', 'VARIOUS', 'WORDS', 'LINUX', 'JAMES', 'WEIGHT', 'HEART', 'RECEIVED', 'CHOOSE', 'ARCHIVES',
  'POINTS', 'MAGAZINE', 'ERROR', 'CAMERA', 'CLEAR', 'RECEIVE', 'DOMAIN', 'METHODS', 'CHAPTER', 'MAKES', 'POLICIES', 'BEAUTY',
  'MANAGER', 'INDIA', 'POSITION', 'TAKEN', 'LISTINGS', 'MODELS', 'MICHAEL', 'KNOWN', 'CASES', 'FLORIDA', 'SIMPLE', 'QUICK',
  'WIRELESS', 'LICENSE', 'FRIDAY', 'WHOLE', 'ANNUAL', 'LATER', 'BASIC', 'SHOWS', 'GOOGLE', 'CHURCH', 'METHOD', 'PURCHASE',
  'ACTIVE', 'RESPONSE', 'PRACTICE', 'HARDWARE', 'FIGURE', 'HOLIDAY', 'ENOUGH', 'DESIGNED', 'ALONG', 'AMONG', 'DEATH', 'WRITING',
  'SPEED', 'BRAND', 'DISCOUNT', 'HIGHER', 'EFFECTS', 'CREATED', 'REMEMBER', 'YELLOW', 'INCREASE', 'KINGDOM', 'THOUGHT', 'STUFF',
  'FRENCH', 'STORAGE', 'JAPAN', 'DOING', 'LOANS', 'SHOES', 'ENTRY', 'NATURE', 'ORDERS', 'AFRICA', 'SUMMARY', 'GROWTH',
  'NOTES', 'AGENCY', 'MONDAY', 'EUROPEAN', 'ACTIVITY', 'ALTHOUGH', 'WESTERN', 'INCOME', 'FORCE', 'OVERALL', 'RIVER', 'PACKAGE',
  'CONTENTS', 'PLAYERS', 'ENGINE', 'ALBUM', 'REGIONAL', 'SUPPLIES', 'STARTED', 'VIEWS', 'PLANS', 'DOUBLE', 'BUILD', 'SCREEN',
  'EXCHANGE', 'TYPES', 'LINES', 'CONTINUE', 'ACROSS', 'BENEFITS', 'NEEDED', 'SEASON', 'APPLY', 'SOMEONE', 'ANYTHING', 'PRINTER',
  'BELIEVE', 'EFFECT', 'ASKED', 'SUNDAY', 'CASINO', 'VOLUME', 'CROSS', 'ANYONE', 'MORTGAGE', 'SILVER', 'INSIDE', 'SOLUTION',
  'MATURE', 'RATHER', 'WEEKS', 'ADDITION', 'SUPPLY', 'NOTHING', 'CERTAIN', 'RUNNING', 'LOWER', 'UNION', 'JEWELRY', 'CLOTHING',
  'NAMES', 'ROBERT', 'HOMEPAGE', 'SKILLS', 'ISLANDS', 'ADVICE', 'CAREER', 'MILITARY', 'RENTAL', 'DECISION', 'LEAVE', 'BRITISH',
  'TEENS', 'WOMAN', 'SELLERS', 'MIDDLE', 'CABLE', 'TAKING', 'VALUES', 'DIVISION', 'COMING', 'TUESDAY', 'OBJECT', 'LESBIAN',
  'MACHINE', 'LENGTH', 'ACTUALLY', 'SCORE', 'CLIENT', 'RETURNS', 'CAPITAL', 'FOLLOW', 'SAMPLE', 'SHOWN', 'SATURDAY', 'ENGLAND',
  'CULTURE', 'FLASH', 'GEORGE', 'CHOICE', 'STARTING', 'THURSDAY', 'COURSES', 'CONSUMER', 'AIRPORT', 'FOREIGN', 'ARTIST', 'OUTSIDE',
  'LEVELS', 'CHANNEL', 'LETTER', 'PHONES', 'IDEAS', 'SUMMER', 'ALLOW', 'DEGREE', 'CONTRACT', 'BUTTON', 'RELEASES', 'HOMES',
  'SUPER', 'MATTER', 'CUSTOM', 'VIRGINIA', 'ALMOST', 'LOCATED', 'MULTIPLE', 'ASIAN', 'EDITOR', 'CAUSE', 'FOCUS', 'FEATURED',
  'ROOMS', 'FEMALE', 'THOMAS', 'PRIMARY', 'CANCER', 'NUMBERS', 'REASON', 'BROWSER', 'SPRING', 'ANSWER', 'VOICE', 'FRIENDLY',
  'SCHEDULE', 'PURPOSE', 'FEATURE', 'COMES', 'POLICE', 'EVERYONE', 'APPROACH', 'CAMERAS', 'BROWN', 'PHYSICAL', 'MEDICINE', 'RATINGS',
  'CHICAGO', 'FORMS', 'GLASS', 'HAPPY', 'SMITH', 'WANTED', 'THANK', 'UNIQUE', 'SURVEY', 'PRIOR', 'SPORT', 'READY',
  'ANIMAL', 'SOURCES', 'MEXICO', 'REGULAR', 'SECURE', 'SIMPLY', 'EVIDENCE', 'STATION', 'ROUND', 'PAYPAL', 'FAVORITE', 'OPTION',
  'MASTER', 'VALLEY', 'RECENTLY', 'PROBABLY', 'RENTALS', 'BUILT', 'BLOOD', 'IMPROVE', 'LARGER', 'NETWORKS', 'EARTH', 'PARENTS',
  'NOKIA', 'IMPACT', 'TRANSFER', 'KITCHEN', 'STRONG', 'CAROLINA', 'WEDDING', 'HOSPITAL', 'GROUND', 'OVERVIEW', 'OWNERS', 'DISEASE',
  'ITALY', 'PERFECT', 'CLASSIC', 'BASIS', 'COMMAND', 'CITIES', 'WILLIAM', 'EXPRESS', 'AWARD', 'DISTANCE', 'PETER', 'ENSURE',
  'INVOLVED', 'EXTRA', 'PARTNERS', 'BUDGET', 'RATED', 'GUIDES', 'SUCCESS', 'MAXIMUM', 'EXISTING', 'QUITE', 'SELECTED', 'AMAZON',
  'PATIENTS', 'WARNING', 'HORSE', 'FORWARD', 'FLOWERS', 'STARS', 'LISTS', 'OWNER', 'RETAIL', 'ANIMALS', 'USEFUL', 'DIRECTLY',
  'HOUSING', 'TAKES', 'BRING', 'CATALOG', 'SEARCHES', 'TRYING', 'MOTHER', 'TRAFFIC', 'JOINED', 'INPUT', 'STRATEGY', 'AGENT',
  'VALID', 'MODERN', 'SENIOR', 'IRELAND', 'TEACHING', 'GRAND', 'TESTING', 'TRIAL', 'CHARGE', 'UNITS', 'INSTEAD', 'CANADIAN',
  'NORMAL', 'WROTE', 'SHIPS', 'ENTIRE', 'LEADING', 'METAL', 'POSITIVE', 'FITNESS', 'CHINESE', 'OPINION', 'FOOTBALL', 'ABSTRACT',
  'OUTPUT', 'FUNDS', 'GREATER', 'LIKELY', 'DEVELOP', 'ARTISTS', 'GUEST', 'SEEMS', 'TRUST', 'CONTAINS', 'SESSION', 'MULTI',
  'REPUBLIC', 'VACATION', 'CENTURY', 'ACADEMIC', 'GRAPHICS', 'INDIAN', 'EXPECTED', 'GRADE', 'DATING', 'PACIFIC', 'MOUNTAIN', 'FILTER',
  'MAILING', 'VEHICLE', 'LONGER', 'CONSIDER', 'NORTHERN', 'BEHIND', 'PANEL', 'FLOOR', 'GERMAN', 'BUYING', 'MATCH', 'PROPOSED',
  'DEFAULT', 'REQUIRE', 'OUTDOOR', 'MORNING', 'ALLOWS', 'PROTEIN', 'PLANT', 'REPORTED', 'POLITICS', 'PARTNER', 'AUTHORS', 'BOARDS',
  'FACULTY', 'PARTIES', 'MISSION', 'STRING', 'SENSE', 'MODIFIED', 'RELEASED', 'STAGE', 'INTERNAL', 'GOODS', 'UNLESS', 'RICHARD',
  'DETAILED', 'JAPANESE', 'APPROVED', 'TARGET', 'EXCEPT', 'ABILITY', 'MAYBE', 'MOVING', 'BRANDS', 'PLACES', 'PRETTY', 'SPAIN',
  'SOUTHERN', 'YOURSELF', 'WINTER', 'BATTERY', 'YOUTH', 'PRESSURE', 'BOSTON', 'KEYWORDS', 'MEDIUM', 'BREAK', 'PURPOSES', 'DANCE',
  'ITSELF', 'DEFINED', 'PAPERS', 'PLAYING', 'AWARDS', 'STUDIO', 'READER', 'VIRTUAL', 'DEVICE', 'ANSWERS', 'REMOTE', 'EXTERNAL',
  'APPLE', 'OFFERED', 'THEORY', 'ENJOY', 'REMOVE', 'SURFACE', 'MINIMUM', 'VISUAL', 'VARIETY', 'TEACHERS', 'MARTIN', 'MANUAL',
  'BLOCK', 'SUBJECTS', 'AGENTS', 'REPAIR', 'CIVIL', 'STEEL', 'SONGS', 'FIXED', 'WRONG', 'HANDS', 'FINALLY', 'UPDATES',
  'DESKTOP', 'CLASSES', 'PARIS', 'SECTOR', 'CAPACITY', 'REQUIRES', 'JERSEY', 'FULLY', 'FATHER', 'ELECTRIC', 'QUOTES', 'OFFICER',
  'DRIVER', 'RESPECT', 'UNKNOWN', 'WORTH', 'TEACHER', 'WORKERS', 'GEORGIA', 'PEACE', 'CAMPUS', 'SHOWING', 'CREATIVE', 'COAST',
  'BENEFIT', 'PROGRESS', 'FUNDING', 'DEVICES', 'GRANT', 'AGREE', 'FICTION', 'WATCHES', 'CAREERS', 'BEYOND', 'FAMILIES', 'MUSEUM',
  'BLOGS', 'ACCEPTED', 'FORMER', 'COMPLEX', 'AGENCIES', 'PARENT', 'SPANISH', 'MICHIGAN', 'COLUMBIA', 'SETTING', 'SCALE', 'STAND',
  'ECONOMY', 'HIGHEST', 'HELPFUL', 'MONTHLY', 'CRITICAL', 'FRAME', 'MUSICAL', 'ANGELES', 'EMPLOYEE', 'CHIEF', 'GIVES', 'BOTTOM',
  'PACKAGES', 'DETAIL', 'CHANGED', 'HEARD', 'BEGIN', 'COLORADO', 'ROYAL', 'CLEAN', 'SWITCH', 'RUSSIAN', 'LARGEST', 'AFRICAN',
  'TITLES', 'RELEVANT', 'JUSTICE', 'CONNECT', 'BIBLE', 'BASKET', 'APPLIED', 'WEEKLY', 'DEMAND', 'SUITE', 'VEGAS', 'SQUARE',
  'CHRIS', 'ADVANCE', 'AUCTION', 'ALLOWED', 'CORRECT', 'CHARLES', 'NATION', 'SELLING', 'PIECE', 'SHEET', 'SEVEN', 'OLDER',
  'ILLINOIS', 'ELEMENTS', 'SPECIES', 'CELLS', 'MODULE', 'RESORT', 'FACILITY', 'RANDOM', 'PRICING', 'MINISTER', 'MOTION', 'LOOKS',
  'FASHION', 'VISITORS', 'MONITOR', 'TRADING', 'FOREST', 'CALLS', 'WHOSE', 'COVERAGE', 'COUPLE', 'GIVING', 'CHANCE', 'VISION',
  'ENDING', 'CLIENTS', 'ACTIONS', 'LISTEN', 'DISCUSS', 'ACCEPT', 'NAKED', 'CLINICAL', 'SCIENCES', 'MARKETS', 'LOWEST', 'HIGHLY',
  'APPEAR', 'LIVES', 'CURRENCY', 'LEATHER', 'PATIENT', 'ACTUAL', 'STONE', 'COMMERCE', 'PERHAPS', 'PERSONS', 'TESTS', 'VILLAGE',
  'ACCOUNTS', 'AMATEUR', 'FACTORS', 'COFFEE', 'SETTINGS', 'BUYER', 'CULTURAL', 'STEVE', 'EASILY', 'POSTER', 'CLOSED', 'HOLIDAYS',
  'ZEALAND', 'BALANCE', 'GRADUATE', 'REPLIES', 'INITIAL', 'LABEL', 'THINKING', 'SCOTT', 'CANON', 'LEAGUE', 'WASTE', 'MINUTE',
  'PROVIDER', 'OPTIONAL', 'SECTIONS', 'CHAIR', 'FISHING', 'EFFORT', 'PHASE', 'FIELDS', 'FANTASY', 'LETTERS', 'MOTOR', 'CONTEXT',
  'INSTALL', 'SHIRT', 'APPAREL', 'CRIME', 'COUNT', 'BREAST', 'JOHNSON', 'QUICKLY', 'DOLLARS', 'WEBSITES', 'RELIGION', 'CLAIM',
  'DRIVING', 'SURGERY', 'PATCH', 'MEASURES', 'KANSAS', 'CHEMICAL', 'DOCTOR', 'REDUCE', 'BROUGHT', 'HIMSELF', 'ENABLE', 'EXERCISE',
  'SANTA', 'LEADER', 'DIAMOND', 'ISRAEL', 'SERVERS', 'ALONE', 'MEETINGS', 'SECONDS', 'JONES', 'ARIZONA', 'KEYWORD', 'FLIGHT',
  'CONGRESS', 'USERNAME', 'PRODUCED', 'ITALIAN', 'POCKET', 'SAINT', 'FREEDOM', 'ARGUMENT', 'CREATING', 'DRUGS', 'JOINT', 'PREMIUM',
  'FRESH', 'ATTORNEY', 'UPGRADE', 'FACTOR', 'GROWING', 'STREAM', 'HEARING', 'EASTERN', 'AUCTIONS', 'THERAPY', 'ENTRIES', 'DATES',
  'SIGNED', 'UPPER', 'SERIOUS', 'PRIME', 'SAMSUNG', 'LIMIT', 'BEGAN', 'LOUIS', 'STEPS', 'ERRORS', 'SHOPS', 'EFFORTS',
  'INFORMED', 'THOUGHTS', 'CREEK', 'WORKED', 'QUANTITY', 'URBAN', 'SORTED', 'MYSELF', 'TOURS', 'PLATFORM', 'LABOR', 'ADMIN',
  'NURSING', 'DEFENSE', 'MACHINES', 'HEAVY', 'COVERED', 'RECOVERY', 'MERCHANT', 'EXPERT', 'PROTECT', 'SOLID', 'BECAME', 'ORANGE',
  'VEHICLES', 'PREVENT', 'THEME', 'CAMPAIGN', 'MARINE', 'GUITAR', 'FINDING', 'EXAMPLES', 'SAYING', 'SPIRIT', 'CLAIMS', 'MOTOROLA',
  'AFFAIRS', 'TOUCH', 'INTENDED', 'TOWARDS', 'GOALS', 'ELECTION', 'SUGGEST', 'BRANCH', 'CHARGES', 'SERVE', 'REASONS', 'MAGIC',
  'MOUNT', 'SMART', 'TALKING', 'LATIN', 'AVOID', 'MANAGE', 'CORNER', 'OREGON', 'ELEMENT', 'BIRTH', 'VIRUS', 'ABUSE',
  'REQUESTS', 'SEPARATE', 'QUARTER', 'TABLES', 'DEFINE', 'RACING', 'FACTS', 'COLUMN', 'PLANTS', 'FAITH', 'CHAIN', 'IDENTIFY',
  'AVENUE', 'MISSING', 'DOMESTIC', 'SITEMAP', 'MOVED', 'HOUSTON', 'REACH', 'MENTAL', 'VIEWED', 'MOMENT', 'EXTENDED', 'SEQUENCE',
  'ATTACK', 'SORRY', 'CENTERS', 'OPENING', 'DAMAGE', 'RESERVE', 'RECIPES', 'GAMMA', 'PLASTIC', 'PRODUCE', 'PLACED', 'TRUTH',
  'COUNTER', 'FAILURE', 'FOLLOWS', 'WEEKEND', 'DOLLAR', 'ONTARIO', 'FILMS', 'BRIDGE', 'NATIVE', 'WILLIAMS', 'MOVEMENT', 'PRINTING',
  'BASEBALL', 'OWNED', 'APPROVAL', 'DRAFT', 'CHART', 'PLAYED', 'CONTACTS', 'JESUS', 'READERS', 'CLUBS', 'JACKSON', 'EQUAL',
  'MATCHING', 'OFFERING', 'SHIRTS', 'PROFIT', 'LEADERS', 'POSTERS', 'VARIABLE', 'EXPECT', 'PARKING', 'COMPARED', 'WORKSHOP', 'RUSSIA',
  'CODES', 'KINDS', 'SEATTLE', 'GOLDEN', 'TEAMS', 'LIGHTING', 'SENATE', 'FORCES', 'FUNNY', 'BROTHER', 'TURNED', 'PORTABLE',
  'TRIED', 'RETURNED', 'PATTERN', 'NAMED', 'THEATRE', 'LASER', 'EARLIER', 'SPONSOR', 'WARRANTY', 'INDIANA', 'HARRY', 'OBJECTS',
  'DELETE', 'EVENING', 'ASSEMBLY', 'NUCLEAR', 'TAXES', 'MOUSE', 'SIGNAL', 'CRIMINAL', 'ISSUED', 'BRAIN', 'SEXUAL', 'POWERFUL',
  'DREAM', 'OBTAINED', 'FALSE', 'FLOWER', 'PASSED', 'SUPPLIED', 'FALLS', 'OPINIONS', 'PROMOTE', 'STATED', 'STATS', 'HAWAII',
  'APPEARS', 'CARRY', 'DECIDED', 'COVERS', 'HELLO', 'DESIGNS', 'MAINTAIN', 'TOURISM', 'PRIORITY', 'ADULTS', 'CLIPS', 'SAVINGS',
  'GRAPHIC', 'PAYMENTS', 'BINDING', 'BRIEF', 'ENDED', 'WINNING', 'EIGHT', 'STRAIGHT', 'SCRIPT', 'SERVED', 'WANTS', 'PREPARED',
  'DINING', 'ALERT', 'ATLANTA', 'DAKOTA', 'QUEEN', 'CREDITS', 'CLEARLY', 'HANDLE', 'SWEET', 'CRITERIA', 'PUBMED', 'DIEGO',
  'TRUCK', 'BEHAVIOR', 'ENLARGE', 'REVENUE', 'MEASURE', 'CHANGING', 'VOTES', 'LOOKED', 'FESTIVAL', 'OCEAN', 'FLIGHTS', 'EXPERTS',
  'SIGNS', 'DEPTH', 'WHATEVER', 'LOGGED', 'LAPTOP', 'VINTAGE', 'TRAIN', 'EXACTLY', 'EXPLORE', 'MARYLAND', 'CONCEPT', 'NEARLY',
  'ELIGIBLE', 'CHECKOUT', 'REALITY', 'FORGOT', 'HANDLING', 'ORIGIN', 'GAMING', 'FEEDS', 'BILLION', 'SCOTLAND', 'FASTER', 'DALLAS',
  'BOUGHT', 'NATIONS', 'ROUTE', 'FOLLOWED', 'BROKEN', 'FRANK', 'ALASKA', 'BATTLE', 'ANIME', 'SPEAK', 'PROTOCOL', 'QUERY',
  'EQUITY', 'SPEECH', 'RURAL', 'SHARED', 'SOUNDS', 'JUDGE', 'BYTES', 'FORCED', 'FIGHT', 'HEIGHT', 'SPEAKER', 'FILED',
  'OBTAIN', 'OFFICES', 'DESIGNER', 'REMAIN', 'MANAGED', 'FAILED', 'MARRIAGE', 'KOREA', 'BANKS', 'SECRET', 'KELLY', 'LEADS',
  'NEGATIVE', 'AUSTIN', 'TORONTO', 'THEATER', 'SPRINGS', 'MISSOURI', 'ANDREW', 'PERFORM', 'HEALTHY', 'ASSETS', 'INJURY', 'JOSEPH',
  'MINISTRY', 'DRIVERS', 'LAWYER', 'FIGURES', 'MARRIED', 'PROPOSAL', 'SHARING', 'PORTAL', 'WAITING', 'BIRTHDAY', 'GRATIS', 'BANKING',
  'BRIAN', 'TOWARD', 'SLIGHTLY', 'ASSIST', 'CONDUCT', 'LINGERIE', 'CALLING', 'SERVING', 'PROFILES', 'MIAMI', 'COMICS', 'MATTERS',
  'HOUSES', 'POSTAL', 'CONTROLS', 'BREAKING', 'COMBINED', 'ULTIMATE', 'WALES', 'MINOR', 'FINISH', 'NOTED', 'REDUCED', 'PHYSICS',
  'SPENT', 'EXTREME', 'SAMPLES', 'DAVIS', 'DANIEL', 'REVIEWED', 'FORECAST', 'REMOVED', 'HELPS', 'SINGLES', 'CYCLE', 'AMOUNTS',
  'CONTAIN', 'ACCURACY', 'SLEEP', 'PHARMACY', 'BRAZIL', 'CREATION', 'STATIC', 'SCENE', 'HUNTER', 'CRYSTAL', 'FAMOUS', 'WRITER',
  'CHAIRMAN', 'VIOLENCE', 'OKLAHOMA', 'SPEAKERS', 'DRINK', 'ACADEMY', 'DYNAMIC', 'GENDER', 'CLEANING', 'CONCERNS', 'VENDOR', 'INTEL',
  'OFFICERS', 'REFERRED', 'SUPPORTS', 'REGIONS', 'JUNIOR', 'RINGS', 'MEANING', 'LADIES', 'HENRY', 'TICKET', 'GUESS', 'AGREED',
  'SOCCER', 'IMPORT', 'POSTING', 'PRESENCE', 'INSTANT', 'VIEWING', 'MAJORITY', 'CHRIST', 'ASPECTS', 'AUSTRIA', 'AHEAD', 'SCHEME',
  'UTILITY', 'PREVIEW', 'MANNER', 'MATRIX', 'DEVEL', 'DESPITE', 'STRENGTH', 'TURKEY', 'PROPER', 'DEGREES', 'DELTA', 'SEEKING',
  'INCHES', 'PHOENIX', 'SHARES', 'DAUGHTER', 'STANDING', 'COMFORT', 'COLORS', 'CISCO', 'ORDERING', 'ALPHA', 'APPEAL', 'CRUISE',
  'BONUS', 'BOOKMARK', 'SPECIALS', 'DISNEY', 'ADOBE', 'SMOKING', 'BECOMES', 'DRIVES', 'ALABAMA', 'IMPROVED', 'TREES', 'ACHIEVE',
  'DRESS', 'DEALER', 'NEARBY', 'CARRIED', 'HAPPEN', 'EXPOSURE', 'GAMBLING', 'REFER', 'MILLER', 'OUTDOORS', 'CLOTHES', 'CAUSED',
  'LUXURY', 'BABES', 'FRAMES', 'INDEED', 'CIRCUIT', 'LAYER', 'PRINTED', 'REMOVAL', 'EASIER', 'PRINTERS', 'ADDING', 'KENTUCKY',
  'MOSTLY', 'TAYLOR', 'PRINTS', 'SPEND', 'FACTORY', 'INTERIOR', 'REVISED', 'OPTICAL', 'RELATIVE', 'AMAZING', 'CLOCK', 'IDENTITY',
  'SUITES', 'FEELING', 'HIDDEN', 'VICTORIA', 'SERIAL', 'RELIEF', 'REVISION', 'RATIO', 'PLANET', 'COPIES', 'RECIPE', 'PERMIT',
  'SEEING', 'PROOF', 'TENNIS', 'BEDROOM', 'EMPTY', 'INSTANCE', 'LICENSED', 'ORLANDO', 'BUREAU', 'MAINE', 'IDEAL', 'SPECS',
  'RECORDED', 'PIECES', 'FINISHED', 'PARKS', 'DINNER', 'LAWYERS', 'SYDNEY', 'STRESS', 'CREAM', 'TRENDS', 'DISCOVER', 'PATTERNS',
  'BOXES', 'HILLS', 'FOURTH', 'ADVISOR', 'AWARE', 'WILSON', 'SHAPE', 'IRISH', 'STATIONS', 'REMAINS', 'GREATEST', 'FIRMS',
  'OPERATOR', 'GENERIC', 'USAGE', 'CHARTS', 'MIXED', 'CENSUS', 'EXIST', 'WHEEL', 'TRANSIT', 'COMPACT', 'POETRY', 'LIGHTS',
  'TRACKING', 'ANGEL', 'KEEPING', 'ATTEMPT', 'MATCHES', 'WIDTH', 'NOISE', 'ENGINES', 'FORGET', 'ARRAY', 'ACCURATE', 'STEPHEN',
  'CLIMATE', 'ALCOHOL', 'GREEK', 'MANAGING', 'SISTER', 'WALKING', 'EXPLAIN', 'SMALLER', 'NEWEST', 'HAPPENED', 'EXTENT', 'SHARP',
  'LESBIANS', 'EXPORT', 'MANAGERS', 'AIRCRAFT', 'MODULES', 'SWEDEN', 'CONFLICT', 'VERSIONS', 'EMPLOYER', 'OCCUR', 'KNOWS', 'DESCRIBE',
  'CONCERN', 'BACKUP', 'CITIZENS', 'HERITAGE', 'HOLDING', 'TROUBLE', 'SPREAD', 'COACH', 'KEVIN', 'EXPAND', 'AUDIENCE', 'ASSIGNED',
  'JORDAN', 'AFFECT', 'VIRGIN', 'RAISED', 'DIRECTED', 'DEALERS', 'SPORTING', 'HELPING', 'AFFECTED', 'TOTALLY', 'PLATE', 'EXPENSES',
  'INDICATE', 'BLONDE', 'ANDERSON', 'ORGANIC', 'ALBUMS', 'CHEATS', 'GUESTS', 'HOSTED', 'DISEASES', 'NEVADA', 'THAILAND', 'AGENDA',
  'ANYWAY', 'TRACKS', 'ADVISORY', 'LOGIC', 'TEMPLATE', 'PRINCE', 'CIRCLE', 'GRANTS', 'ANYWHERE', 'ATLANTIC', 'EDWARD', 'INVESTOR',
  'LEAVING', 'WILDLIFE', 'COOKING', 'SPEAKING', 'SPONSORS', 'RESPOND', 'SIZES', 'PLAIN', 'ENTERED', 'LAUNCH', 'CHECKING', 'COSTA',
  'BELGIUM', 'GUIDANCE', 'TRAIL', 'SYMBOL', 'CRAFTS', 'HIGHWAY', 'BUDDY', 'OBSERVED', 'SETUP', 'BOOKING', 'GLOSSARY', 'FISCAL',
  'STYLES', 'DENVER', 'FILLED', 'CHANNELS', 'ERICSSON', 'APPENDIX', 'NOTIFY', 'BLUES', 'PORTION', 'SCOPE', 'SUPPLIER', 'CABLES',
  'COTTON', 'BIOLOGY', 'DENTAL', 'KILLED', 'BORDER', 'ANCIENT', 'DEBATE', 'STARTS', 'CAUSES', 'ARKANSAS', 'LEISURE', 'LEARNED',
  'NOTEBOOK', 'EXPLORER', 'HISTORIC', 'ATTACHED', 'OPENED', 'HUSBAND', 'DISABLED', 'CRAZY', 'UPCOMING', 'BRITAIN', 'CONCERT', 'SCORES',
  'COMEDY', 'ADOPTED', 'WEBLOG', 'LINEAR', 'BEARS', 'CARRIER', 'EDITED', 'CONSTANT', 'MOUTH', 'JEWISH', 'METER', 'LINKED',
  'PORTLAND', 'CONCEPTS', 'REFLECT', 'DELIVER', 'WONDER', 'LESSONS', 'FRUIT', 'BEGINS', 'REFORM', 'ALERTS', 'TREATED', 'MYSQL',
  'RELATING', 'ASSUME', 'ALLIANCE', 'CONFIRM', 'NEITHER', 'LEWIS', 'HOWARD', 'OFFLINE', 'LEAVES', 'ENGINEER', 'REPLACE', 'CHECKS',
  'REACHED', 'BECOMING', 'SAFARI', 'SUGAR', 'STICK', 'ALLEN', 'RELATION', 'ENABLED', 'GENRE', 'SLIDE', 'MONTANA', 'TESTED',
  'ENHANCE', 'EXACT', 'BOUND', 'ADAPTER', 'FORMAL', 'HOCKEY', 'STORM', 'MICRO', 'COLLEGES', 'LAPTOPS', 'SHOWED', 'EDITORS',
  'THREADS', 'SUPREME', 'BROTHERS', 'PRESENTS', 'DOLLS', 'ESTIMATE', 'CANCEL', 'LIMITS', 'WEAPONS', 'PAINT', 'DELAY', 'PILOT',
  'OUTLET', 'CZECH', 'NOVEL', 'ULTRA', 'WINNER', 'IDAHO', 'EPISODE', 'POTTER', 'PLAYS', 'BULLETIN', 'MODIFY', 'OXFORD',
  'TRULY', 'EPINIONS', 'PAINTING', 'UNIVERSE', 'PATENT', 'EATING', 'PLANNED', 'WATCHING', 'LODGE', 'MIRROR', 'STERLING', 'SESSIONS',
  'KERNEL', 'STOCKS', 'BUYERS', 'JOURNALS', 'JENNIFER', 'ANTONIO', 'CHARGED', 'BROAD', 'TAIWAN', 'CHOSEN', 'GREECE', 'SWISS',
  'SARAH', 'CLARK', 'TERMINAL', 'NIGHTS', 'BEHALF', 'LIQUID', 'NEBRASKA', 'SALARY', 'FOODS', 'GOURMET', 'GUARD', 'PROPERLY',
  'ORLEANS', 'SAVING', 'EMPIRE', 'RESUME', 'TWENTY', 'NEWLY', 'RAISE', 'PREPARE', 'AVATAR', 'ILLEGAL', 'HUNDREDS', 'LINCOLN',
  'HELPED', 'PREMIER', 'TOMORROW', 'DECIDE', 'CONSENT', 'DRAMA', 'VISITING', 'DOWNTOWN', 'KEYBOARD', 'CONTEST', 'BANDS', 'SUITABLE',
  'MILLIONS', 'LUNCH', 'AUDIT', 'CHAMBER', 'GUINEA', 'FINDINGS', 'MUSCLE', 'CLICKING', 'POLLS', 'TYPICAL', 'TOWER', 'YOURS',
  'CHICKEN', 'ATTEND', 'SHOWER', 'SENDING', 'JASON', 'TONIGHT', 'HOLDEM', 'SHELL', 'PROVINCE', 'CATHOLIC', 'GOVERNOR', 'SEEMED',
  'SWIMMING', 'SPYWARE', 'FORMULA', 'SOLAR', 'CATCH', 'PAKISTAN', 'RELIABLE', 'DOUBT', 'FINDER', 'UNABLE', 'PERIODS', 'TASKS',
  'ATTACKS', 'CONST', 'DOORS', 'SYMPTOMS', 'RESORTS', 'BIGGEST', 'MEMORIAL', 'VISITOR', 'FORTH', 'INSERT', 'GATEWAY', 'ALUMNI',
  'DRAWING', 'ORDERED', 'FIGHTING', 'HAPPENS', 'ROMANCE', 'BRUCE', 'SPLIT', 'THEMES', 'POWERS', 'HEAVEN', 'PREGNANT', 'TWICE',
  'FOCUSED', 'EGYPT', 'BARGAIN', 'CELLULAR', 'NORWAY', 'VERMONT', 'ASKING', 'BLOCKS', 'NORMALLY', 'HUNTING', 'DIABETES', 'SHIFT',
  'BODIES', 'CUTTING', 'SIMON', 'WRITERS', 'MARKS', 'FLEXIBLE', 'LOVED', 'MAPPING', 'NUMEROUS', 'BIRDS', 'INDEXED', 'SUPERIOR',
  'SAVED', 'PAYING', 'CARTOON', 'SHOTS', 'MOORE', 'GRANTED', 'CHOICES', 'CARBON', 'SPENDING', 'MAGNETIC', 'REGISTRY', 'CRISIS',
  'OUTLOOK', 'MASSIVE', 'DENMARK', 'EMPLOYED', 'BRIGHT', 'TREAT', 'HEADER', 'POVERTY', 'FORMED', 'PIANO', 'SHEETS', 'PATRICK',
  'PUERTO', 'DISPLAYS', 'PLASMA', 'ALLOWING', 'EARNINGS', 'MYSTERY', 'JOURNEY', 'DELAWARE', 'BIDDING', 'RISKS', 'BANNER', 'CHARTER',
  'BARBARA', 'COUNTIES', 'PORTS', 'DREAMS', 'BLOGGER', 'STANDS', 'TEACH', 'OCCURRED', 'RAPID', 'HAIRY', 'REVERSE', 'DEPOSIT',
  'SEMINAR', 'LATINA', 'WHEELS', 'SPECIFY', 'DUTCH', 'FORMATS', 'DEPENDS', 'BOOTS', 'HOLDS', 'ROUTER', 'CONCRETE', 'EDITING',
  'POLAND', 'FOLDER', 'WOMENS', 'UPLOAD', 'PULSE', 'VOTING', 'COURTS', 'NOTICES', 'DETROIT', 'METRO', 'TOSHIBA', 'STRIP',
  'PEARL', 'ACCIDENT', 'RESIDENT', 'POSSIBLY', 'AIRLINE', 'REGARD', 'EXISTS', 'SMOOTH', 'STRIKE', 'FLASHING', 'NARROW', 'THREAT',
  'SURVEYS', 'SITTING', 'PUTTING', 'VIETNAM', 'TRAILER', 'CASTLE', 'GARDENS', 'MISSED', 'MALAYSIA', 'ANTIQUE', 'LABELS', 'WILLING',
  'ACTING', 'HEADS', 'STORED', 'LOGOS', 'ANTIQUES', 'DENSITY', 'HUNDRED', 'STRANGE', 'MENTION', 'PARALLEL', 'HONDA', 'AMENDED',
  'OPERATE', 'BILLS', 'BATHROOM', 'STABLE', 'OPERA', 'DOCTORS', 'LESSON', 'CINEMA', 'ASSET', 'DRINKING', 'REACTION', 'BLANK',
  'ENHANCED', 'ENTITLED', 'SEVERE', 'GENERATE', 'DELUXE', 'HUMOR', 'MONITORS', 'LIVED', 'DURATION', 'PURSUANT', 'FABRIC', 'VISITS',
  'TIGHT', 'DOMAINS', 'CONTRAST', 'FLYING', 'BERLIN', 'SIEMENS', 'ADOPTION', 'MEANT', 'CAPTURE', 'POUNDS', 'BUFFALO', 'PLANE',
  'DESIRE', 'CAMPING', 'MEETS', 'WELFARE', 'CAUGHT', 'MARKED', 'DRIVEN', 'MEASURED', 'MEDLINE', 'BOTTLE', 'MARSHALL', 'MASSAGE',
  'RUBBER', 'CLOSING', 'TAMPA', 'THOUSAND', 'LEGEND', 'GRACE', 'SUSAN', 'ADAMS', 'PYTHON', 'MONSTER', 'VILLA', 'COLUMNS',
  'HAMILTON', 'COOKIES', 'INNER', 'TUTORIAL', 'ENTITY', 'CRUISES', 'HOLDER', 'PORTUGAL', 'LAWRENCE', 'ROMAN', 'DUTIES', 'VALUABLE',
  'ETHICS', 'FOREVER', 'DRAGON', 'CAPTAIN', 'IMAGINE', 'BRINGS', 'HEATING', 'SCRIPTS', 'STEREO', 'TASTE', 'DEALING', 'COMMIT',
  'AIRLINES', 'LIBERAL', 'LIVECAM', 'TRIPS', 'SIDES', 'TURNS', 'CACHE', 'JACKET', 'ORACLE', 'MATTHEW', 'LEASE', 'AVIATION',
  'HOBBIES', 'PROUD', 'EXCESS', 'DISASTER', 'CONSOLE', 'COMMANDS', 'GIANT', 'ACHIEVED', 'INJURIES', 'SHIPPED', 'SEATS', 'ALARM',
  'VOLTAGE', 'ANTHONY', 'NINTENDO', 'USUAL', 'LOADING', 'STAMPS', 'APPEARED', 'FRANKLIN', 'ANGLE', 'VINYL', 'MINING', 'ONGOING',
  'WORST', 'IMAGING', 'BETTING', 'LIBERTY', 'WYOMING', 'CONVERT', 'ANALYST', 'GARAGE', 'EXCITING', 'THONGS', 'RINGTONE', 'FINLAND',
  'MORGAN', 'DERIVED', 'PLEASURE', 'HONOR', 'ORIENTED', 'EAGLE', 'DESKTOPS', 'PANTS', 'COLUMBUS', 'NURSE', 'PRAYER', 'QUIET',
  'POSTAGE', 'PRODUCER', 'CHEESE', 'COMIC', 'CROWN', 'MAKER', 'CRACK', 'PICKS', 'SEMESTER', 'FETISH', 'APPLIES', 'CASINOS',
  'SMOKE', 'APACHE', 'FILTERS', 'CRAFT', 'APART', 'FELLOW', 'BLIND', 'LOUNGE', 'COINS', 'GROSS', 'STRONGLY', 'HILTON',
  'PROTEINS', 'HORROR', 'FAMILIAR', 'CAPABLE', 'DOUGLAS', 'DEBIAN', 'EPSON', 'ELECTED', 'CARRYING', 'VICTORY', 'MADISON', 'EDITIONS',
  'MAINLY', 'ETHNIC', 'ACTOR', 'FINDS', 'FIFTH', 'CITIZEN', 'VERTICAL', 'PRIZE', 'OCCURS', 'ABSOLUTE', 'CONSISTS', 'ANYTIME',
  'SOLDIERS', 'GUARDIAN', 'LECTURE', 'LAYOUT', 'CLASSICS', 'HORSES', 'DIRTY', 'WAYNE', 'DONATE', 'TAUGHT', 'WORKER', 'ALIVE',
  'TEMPLE', 'PROVE', 'WINGS', 'BREAKS', 'GENETIC', 'WATERS', 'PROMISE', 'PREFER', 'RIDGE', 'CABINET', 'MODEM', 'HARRIS',
  'BRINGING', 'EVALUATE', 'TIFFANY', 'TROPICAL', 'COLLECT', 'TOYOTA', 'STREETS', 'VECTOR', 'SHAVED', 'TURNING', 'BUFFER', 'PURPLE',
  'LARRY', 'MUTUAL', 'PIPELINE', 'SYNTAX', 'PRISON', 'SKILL', 'CHAIRS', 'EVERYDAY', 'MOVES', 'INQUIRY', 'ETHERNET', 'CHECKED',
  'EXHIBIT', 'THROW', 'TREND', 'SIERRA', 'VISIBLE', 'DESERT', 'OLDEST', 'RHODE', 'MERCURY', 'STEVEN', 'HANDBOOK', 'NAVIGATE',
  'WORSE', 'SUMMIT', 'VICTIMS', 'SPACES', 'BURNING', 'ESCAPE', 'COUPONS', 'SOMEWHAT', 'RECEIVER', 'CIALIS', 'BOATS', 'GLANCE',
  'SCOTTISH', 'ARCADE', 'RICHMOND', 'RUSSELL', 'TELLS', 'OBVIOUS', 'FIBER', 'GRAPH', 'COVERING', 'PLATINUM', 'JUDGMENT', 'BEDROOMS',
  'TALKS', 'FILING', 'FOSTER', 'MODELING', 'PASSING', 'AWARDED', 'TRIALS', 'TISSUE', 'CLINTON', 'MASTERS', 'BONDS', 'ALBERTA',
  'COMMONS', 'FRAUD', 'SPECTRUM', 'ARRIVAL', 'POTTERY', 'EMPHASIS', 'ROGER', 'ASPECT', 'AWESOME', 'MEXICAN', 'COUNTS', 'PRICED',
  'CRASH', 'DESIRED', 'INTER', 'CLOSER', 'ASSUMES', 'HEIGHTS', 'SHADOW', 'RIDING', 'FIREFOX', 'EXPENSE', 'GROVE', 'VENTURE',
  'CLINIC', 'KOREAN', 'HEALING', 'PRINCESS', 'ENTERING', 'PACKET', 'SPRAY', 'STUDIOS', 'BUTTONS', 'FUNDED', 'THOMPSON', 'WINNERS',
  'EXTEND', 'ROADS', 'DUBLIN', 'ROLLING', 'MEMORIES', 'NELSON', 'ARRIVED', 'CREATES', 'FACES', 'TOURIST', 'MAYOR', 'MURDER',
  'ADEQUATE', 'SENATOR', 'YIELD', 'GRADES', 'CARTOONS', 'DIGEST', 'LODGING', 'HENCE', 'ENTIRELY', 'REPLACED', 'RADAR', 'RESCUE',
  'LOSSES', 'COMBAT', 'REDUCING', 'STOPPED', 'LAKES', 'CLOSELY', 'DIARY', 'KINGS', 'SHOOTING', 'FLAGS', 'BAKER', 'LAUNCHED',
  'SHOCK', 'WALLS', 'ABROAD', 'EBONY', 'DRAWN', 'ARTHUR', 'VISITED', 'WALKER', 'SUGGESTS', 'BEAST', 'OPERATED', 'TARGETS',
  'OVERSEAS', 'DODGE', 'COUNSEL', 'PIZZA', 'INVITED', 'YARDS', 'GORDON', 'FARMERS', 'QUERIES', 'UKRAINE', 'ABSENCE', 'NEAREST',
  'CLUSTER', 'VENDORS', 'WHEREAS', 'SERVES', 'WOODS', 'SURPRISE', 'PARTIAL', 'SHOPPERS', 'COUPLES', 'RANKING', 'JOKES', 'SIMPSON',
  'TWIKI', 'SUBLIME', 'PALACE', 'VERIFY', 'GLOBE', 'TRUSTED', 'COPPER', 'DICKE', 'KERRY', 'RECEIPT', 'SUPPOSED', 'ORDINARY',
  'NOBODY', 'GHOST', 'APPLYING', 'PRIDE', 'KNOWING', 'REPORTER', 'KEITH', 'CHAMPION', 'CLOUDY', 'LINDA', 'CHILE', 'PLENTY',
  'SENTENCE', 'THROAT', 'IGNORE', 'MARIA', 'UNIFORM', 'WEALTH', 'VACUUM', 'DANCING', 'BRASS', 'WRITES', 'PLAZA', 'OUTCOMES',
  'SURVIVAL', 'QUEST', 'PUBLISH', 'TRANS', 'JONATHAN', 'WHENEVER', 'LIFETIME', 'PIONEER', 'BOOTY', 'ACROBAT', 'PLATES', 'ACRES',
  'VENUE', 'ATHLETIC', 'THERMAL', 'ESSAYS', 'VITAL', 'TELLING', 'FAIRLY', 'COASTAL', 'CONFIG', 'CHARITY', 'EXCEL', 'MODES',
  'CAMPBELL', 'STUPID', 'HARBOR', 'HUNGARY', 'TRAVELER', 'SEGMENT', 'REALIZE', 'ENEMY', 'PUZZLE', 'RISING', 'ALUMINUM', 'WELLS',
  'WISHLIST', 'OPENS', 'INSIGHT', 'SECRETS', 'LUCKY', 'LATTER', 'THICK', 'TRAILERS', 'REPEAT', 'SYNDROME', 'PHILIPS', 'PENALTY',
  'GLASSES', 'ENABLES', 'IRAQI', 'BUILDER', 'VISTA', 'JESSICA', 'CHIPS', 'TERRY', 'FLOOD', 'ARENA', 'PUPILS', 'STEWART',
  'OUTCOME', 'EXPANDED', 'CASUAL', 'GROWN', 'POLISH', 'LOVELY', 'EXTRAS', 'CENTRES', 'JERRY', 'CLAUSE', 'SMILE', 'LANDS',
  'TROOPS', 'INDOOR', 'BULGARIA', 'ARMED', 'BROKER', 'CHARGER', 'BELIEVED', 'COOLING', 'TRUCKS', 'DIVORCE', 'LAURA', 'SHOPPER',
  'TOKYO', 'PARTLY', 'NIKON', 'CANDY', 'PILLS', 'TIGER', 'DONALD', 'FOLKS', 'SENSOR', 'EXPOSED', 'TELECOM', 'ANGELS',
  'DEPUTY', 'SEALED', 'LOADED', 'SCENES', 'BOOST', 'SPANKING', 'FOUNDED', 'CHRONIC', 'ICONS', 'MORAL', 'CATERING', 'FINGER',
  'KEEPS', 'POUND', 'LOCATE', 'TRAINED', 'ROSES', 'BREAD', 'TOBACCO', 'WOODEN', 'MOTORS', 'TOUGH', 'ROBERTS', 'INCIDENT',
  'GONNA', 'DYNAMICS', 'DECREASE', 'CHEST', 'PENSION', 'BILLY', 'REVENUES', 'EMERGING', 'WORSHIP', 'CRAIG', 'HERSELF', 'CHURCHES',
  'DAMAGES', 'RESERVES', 'SOLVE', 'SHORTS', 'MINORITY', 'DIVERSE', 'JOHNNY', 'RECORDER', 'FACING', 'NANCY', 'TONES', 'PASSION',
  'SIGHT', 'DEFENCE', 'PATCHES', 'REFUND', 'TOWNS', 'TREMBL', 'DIVIDED', 'EMAILS', 'CYPRUS', 'INSIDER', 'SEMINARS', 'MAKERS',
  'HEARTS', 'WORRY', 'CARTER', 'LEGACY', 'PLEASED', 'DANGER', 'VITAMIN', 'WIDELY', 'PHRASE', 'GENUINE', 'RAISING', 'PARADISE',
  'HYBRID', 'READS', 'ROLES', 'GLORY', 'BIGGER', 'BILLING', 'DIESEL', 'VERSUS', 'COMBINE', 'EXCEED', 'SAUDI', 'FAULT',
  'BABIES', 'KAREN', 'COMPILED', 'ROMANTIC', 'REVEALED', 'ALBERT', 'EXAMINE', 'JIMMY', 'GRAHAM', 'BRISTOL', 'MARGARET', 'COMPAQ',
  'SLOWLY', 'RUGBY', 'PORTIONS', 'INFANT', 'SECTORS', 'SAMUEL', 'FLUID', 'GROUNDS', 'REGARDS', 'UNLIKE', 'EQUATION', 'BASKETS',
  'WRIGHT', 'BARRY', 'PROVEN', 'CACHED', 'WARREN', 'STUDIED', 'REVIEWER', 'INVOLVES', 'PROFITS', 'DEVIL', 'GRASS', 'COMPLY',
  'MARIE', 'FLORIST', 'CHERRY', 'DEUTSCH', 'KENYA', 'WEBCAM', 'FUNERAL', 'NUTTEN', 'EARRINGS', 'ENJOYED', 'CHAPTERS', 'CHARLIE',
  'QUEBEC', 'DENNIS', 'FRANCIS', 'SIZED', 'MANGA', 'NOTICED', 'SOCKET', 'SILENT', 'LITERARY', 'SIGNALS', 'THEFT', 'SWING',
  'SYMBOLS', 'HUMANS', 'ANALOG', 'FACIAL', 'CHOOSING', 'TALENT', 'DATED', 'SEEKER', 'WISDOM', 'SHOOT', 'BOUNDARY', 'PACKARD',
  'OFFSET', 'PAYDAY', 'PHILIP', 'ELITE', 'HOLDERS', 'BELIEVES', 'SWEDISH', 'POEMS', 'DEADLINE', 'ROBOT', 'WITNESS', 'COLLINS',
  'EQUIPPED', 'STAGES', 'WINDS', 'POWDER', 'BROADWAY', 'ACQUIRED', 'ASSESS', 'STONES', 'ENTRANCE', 'GNOME', 'ROOTS', 'LOSING',
  'ATTEMPTS', 'GADGETS', 'NOBLE', 'GLASGOW', 'IMPACTS', 'GOSPEL', 'SHORE', 'LOVES', 'INDUCED', 'KNIGHT', 'LOOSE', 'LINKING',
  'APPEALS', 'EARNED', 'ILLNESS', 'ISLAMIC', 'PENDING', 'PARKER', 'LEBANON', 'KENNEDY', 'TEENAGE', 'TRIPLE', 'COOPER', 'VINCENT',
  'SECURED', 'UNUSUAL', 'ANSWERED', 'SLOTS', 'DISORDER', 'ROUTINE', 'TOOLBAR', 'ROCKS', 'TITANS', 'WEARING', 'SOUGHT', 'GENES',
  'MOUNTED', 'HABITAT', 'FIREWALL', 'MEDIAN', 'SCANNER', 'HEREIN', 'ANIMATED', 'JUDICIAL', 'INTEGER', 'BACHELOR', 'ATTITUDE', 'ENGAGED',
  'FALLING', 'BASICS', 'MONTREAL', 'CARPET', 'STRUCT', 'LENSES', 'BINARY', 'GENETICS', 'ATTENDED', 'DROPPED', 'WALTER', 'BESIDES',
  'HOSTS', 'MOMENTS', 'ATLAS', 'STRINGS', 'FEELS', 'TORTURE', 'DELETED', 'MITCHELL', 'RALPH', 'WARNER', 'EMBEDDED', 'INKJET',
  'WIZARD', 'CORPS', 'ACTORS', 'LIVER', 'LIABLE', 'BROCHURE', 'MORRIS', 'PETITION', 'EMINEM', 'RECALL', 'ANTENNA', 'PICKED',
  'ASSUMED', 'BELIEF', 'KILLING', 'BIKINI', 'MEMPHIS', 'SHOULDER', 'DECOR', 'LOOKUP', 'TEXTS', 'HARVARD', 'BROKERS', 'DIAMETER',
  'OTTAWA', 'PODCAST', 'SEASONS', 'REFINE', 'BIDDER', 'SINGER', 'EVANS', 'HERALD', 'LITERACY', 'FAILS', 'AGING', 'PLUGIN',
  'DIVING', 'INVITE', 'ALICE', 'LATINAS', 'SUPPOSE', 'INVOLVE', 'MODERATE', 'TERROR', 'YOUNGER', 'THIRTY', 'OPPOSITE', 'RAPIDLY',
  'DEALTIME', 'INTRO', 'MERCEDES', 'CLERK', 'MILLS', 'OUTLINE', 'TRAMADOL', 'HOLLAND', 'RECEIVES', 'JEANS', 'FONTS', 'REFERS',
  'FAVOR', 'VETERANS', 'SIGMA', 'XHTML', 'OCCASION', 'VICTIM', 'DEMANDS', 'SLEEPING', 'CAREFUL', 'ARRIVE', 'SUNSET', 'TRACKED',
  'MOREOVER', 'MINIMAL', 'LOTTERY', 'FRAMED', 'ASIDE', 'LICENCE', 'MICHELLE', 'ESSAY', 'DIALOGUE', 'CAMPS', 'DECLARED', 'AARON',
  'HANDHELD', 'TRACE', 'DISPOSAL', 'FLORISTS', 'PACKS', 'SWITCHES', 'ROMANIA', 'CONSULT', 'GREATLY', 'BLOGGING', 'CYCLING', 'MIDNIGHT',
  'COMMONLY', 'INFORM', 'TURKISH', 'PENTIUM', 'QUANTUM', 'MURRAY', 'INTENT', 'LARGELY', 'PLEASANT', 'ANNOUNCE', 'SPOKE', 'ARROW',
  'SAMPLING', 'ROUGH', 'WEIRD', 'INSPIRED', 'HOLES', 'WEDDINGS', 'BLADE', 'SUDDENLY', 'OXYGEN', 'COOKIE', 'MEALS', 'CANYON',
  'METERS', 'MERELY', 'PASSES', 'POINTER', 'STRETCH', 'DURHAM', 'PERMITS', 'MUSLIM', 'SLEEVE', 'NETSCAPE', 'CLEANER', 'CRICKET',
  'FEEDING', 'STROKE', 'TOWNSHIP', 'RANKINGS', 'ROBIN', 'ROBINSON', 'STRAP', 'SHARON', 'CROWD', 'OLYMPIC', 'REMAINED', 'ENTITIES',
  'CUSTOMS', 'RAINBOW', 'ROULETTE', 'DECLINE', 'GLOVES', 'ISRAELI', 'MEDICARE', 'SKIING', 'CLOUD', 'VALVE', 'HEWLETT', 'EXPLAINS',
  'PROCEED', 'FLICKR', 'FEELINGS', 'KNIFE', 'JAMAICA', 'SHELF', 'TIMING', 'LIKED', 'ADOPT', 'DENIED', 'FOTOS', 'BRITNEY',
  'FREEWARE', 'DONATION', 'OUTER', 'DEATHS', 'RIVERS', 'TALES', 'KATRINA', 'ISLAM', 'NODES', 'THUMBS', 'SEEDS', 'CITED',
  'TARGETED', 'SKYPE', 'REALIZED', 'TWELVE', 'FOUNDER', 'DECADE', 'GAMECUBE', 'DISPUTE', 'TIRED', 'TITTEN', 'ADVERSE', 'EXCERPT',
  'STEAM', 'DRINKS', 'VOICES', 'ACUTE', 'CLIMBING', 'STOOD', 'PERFUME', 'CAROL', 'HONEST', 'ALBANY', 'RESTORE', 'STACK',
  'SOMEBODY', 'CURVE', 'CREATOR', 'AMBER', 'MUSEUMS', 'CODING', 'TRACKER', 'PASSAGE', 'TRUNK', 'HIKING', 'PIERRE', 'JELSOFT',
  'HEADSET', 'OAKLAND', 'COLOMBIA', 'WAVES', 'CAMEL', 'LAMPS', 'SUICIDE', 'ARCHIVED', 'ARABIA', 'JUICE', 'CHASE', 'LOGICAL',
  'SAUCE', 'EXTRACT', 'PANAMA', 'PAYABLE', 'COURTESY', 'ATHENS', 'JUDGES', 'RETIRED', 'REMARKS', 'DETECTED', 'DECADES', 'WALKED',
  'ARISING', 'NISSAN', 'BRACELET', 'JUVENILE', 'AFRAID', 'ACOUSTIC', 'RAILWAY', 'CASSETTE', 'POINTED', 'CAUSING', 'MISTAKE', 'NORTON',
  'LOCKED', 'FUSION', 'MINERAL', 'STEERING', 'BEADS', 'FORTUNE', 'CANVAS', 'PARISH', 'CLAIMED', 'SCREENS', 'CEMETERY', 'PLANNER',
  'CROATIA', 'FLOWS', 'STADIUM', 'FEWER', 'COUPON', 'NURSES', 'PROXY', 'LANKA', 'EDWARDS', 'CONTESTS', 'COSTUME', 'TAGGED',
  'BERKELEY', 'VOTED', 'KILLER', 'BIKES', 'GATES', 'ADJUSTED', 'BISHOP', 'PULLED', 'SHAPED', 'SEASONAL', 'FARMER', 'COUNTERS',
  'SLAVE', 'CULTURES', 'NORFOLK', 'COACHING', 'EXAMINED', 'ENCODING', 'HEROES', 'PAINTED', 'LYCOS', 'ZDNET', 'ARTWORK', 'COSMETIC',
  'RESULTED', 'PORTRAIT', 'ETHICAL', 'CARRIERS', 'MOBILITY', 'FLORAL', 'BUILDERS', 'STRUGGLE', 'SCHEMES', 'NEUTRAL', 'FISHER', 'SPEARS',
  'BEDDING', 'JOINING', 'HEADING', 'EQUALLY', 'BEARING', 'COMBO', 'SENIORS', 'WORLDS', 'GUILTY', 'HAVEN', 'TABLET', 'CHARM',
  'VIOLENT', 'BASIN', 'RANCH', 'CROSSING', 'COTTAGE', 'DRUNK', 'CRIMES', 'RESOLVED', 'MOZILLA', 'TONER', 'LATEX', 'BRANCHES',
  'ANYMORE', 'DELHI', 'HOLDINGS', 'ALIEN', 'LOCATOR', 'BROKE', 'NEPAL', 'ZIMBABWE', 'BROWSING', 'RESOLVE', 'MELISSA', 'MOSCOW',
  'THESIS', 'NYLON', 'DISCS', 'ROCKY', 'BARGAINS', 'FREQUENT', 'NIGERIA', 'CEILING', 'PIXELS', 'ENSURING', 'HISPANIC', 'ANYBODY',
  'DIAMONDS', 'FLEET', 'UNTITLED', 'BUNCH', 'TOTALS', 'MARRIOTT', 'SINGING', 'AFFORD', 'STARRING', 'REFERRAL', 'OPTIMAL', 'DISTINCT',
  'TURNER', 'SUCKING', 'CENTS', 'REUTERS', 'SPOKEN', 'OMEGA', 'STAYED', 'CIVIC', 'MANUALS', 'WATCHED', 'SAVER', 'THEREOF',
  'GRILL', 'REDEEM', 'ROGERS', 'GRAIN', 'REGIME', 'WANNA', 'WISHES', 'DEPEND', 'DIFFER', 'RANGING', 'MONICA', 'REPAIRS',
  'BREATH', 'CANDLE', 'HANGING', 'COLORED', 'VERIFIED', 'FORMERLY', 'SITUATED', 'SEEKS', 'HERBAL', 'LOVING', 'STRICTLY', 'ROUTING',
  'STANLEY', 'RETAILER', 'VITAMINS', 'ELEGANT', 'GAINS', 'RENEWAL', 'OPPOSED', 'DEEMED', 'SCORING', 'BROOKLYN', 'SISTERS', 'CRITICS',
  'SPOTS', 'HACKER', 'MADRID', 'MARGIN', 'SOLELY', 'SALON', 'NORMAN', 'TURBO', 'HEADED', 'VOTERS', 'MADONNA', 'MURPHY',
  'THINKS', 'THATS', 'SOLDIER', 'PHILLIPS', 'AIMED', 'JUSTIN', 'INTERVAL', 'MIRRORS', 'TRICKS', 'RESET', 'BRUSH', 'EXPANSYS',
  'PANELS', 'REPEATED', 'ASSAULT', 'SPARE', 'KODAK', 'TONGUE', 'BOWLING', 'DANISH', 'MONKEY', 'FILENAME', 'SKIRT', 'FLORENCE',
  'INVEST', 'HONEY', 'ANALYZES', 'DRAWINGS', 'SCENARIO', 'LOVERS', 'ATOMIC', 'APPROX', 'ARABIC', 'GAUGE', 'JUNCTION', 'FACED',
  'RACHEL', 'SOLVING', 'WEEKENDS', 'PRODUCES', 'CHAINS', 'KINGSTON', 'SIXTH', 'ENGAGE', 'DEVIANT', 'QUOTED', 'ADAPTERS', 'FARMS',
  'IMPORTS', 'CHEAT', 'BRONZE', 'SANDY', 'SUSPECT', 'MACRO', 'SENDER', 'CRUCIAL', 'ADJACENT', 'TUITION', 'SPOUSE', 'EXOTIC',
  'VIEWER', 'SIGNUP', 'THREATS', 'PUZZLES', 'REACHING', 'DAMAGED', 'RECEPTOR', 'LAUGH', 'SURGICAL', 'DESTROY', 'CITATION', 'PITCH',
  'AUTOS', 'PREMISES', 'PERRY', 'PROVED', 'IMPERIAL', 'DOZEN', 'BENJAMIN', 'TEETH', 'CLOTH', 'STUDYING', 'STAMP', 'LOTUS',
  'SALMON', 'OLYMPUS', 'CARGO', 'SALEM', 'STARTER', 'UPGRADES', 'LIKES', 'BUTTER', 'PEPPER', 'WEAPON', 'LUGGAGE', 'BURDEN',
  'TAPES', 'ZONES', 'RACES', 'STYLISH', 'MAPLE', 'GROCERY', 'OFFSHORE', 'DEPOT', 'KENNETH', 'BLEND', 'HARRISON', 'JULIE',
  'EMISSION', 'FINEST', 'REALTY', 'JANET', 'APPARENT', 'PHPBB', 'AUTUMN', 'PROBE', 'TOILET', 'RANKED', 'JACKETS', 'ROUTES',
  'PACKED', 'EXCITED', 'OUTREACH', 'HELEN', 'MOUNTING', 'RECOVER', 'LOPEZ', 'BALANCED', 'TIMELY', 'TALKED', 'DEBUG', 'DELAYED',
  'CHUCK', 'EXPLICIT', 'VILLAS', 'EBOOK', 'EXCLUDE', 'PEEING', 'BROOKS', 'NEWTON', 'ANXIETY', 'BINGO', 'WHILST', 'SPATIAL',
  'CERAMIC', 'PROMPT', 'PRECIOUS', 'MINDS', 'ANNUALLY', 'SCANNERS', 'XANAX', 'FINGERS', 'SUNNY', 'EBOOKS', 'DELIVERS', 'NECKLACE',
  'LEEDS', 'CEDAR', 'ARRANGED', 'THEATERS', 'ADVOCACY', 'RALEIGH', 'THREADED', 'QUALIFY', 'BLAIR', 'HOPES', 'MASON', 'DIAGRAM',
  'BURNS', 'PUMPS', 'FOOTWEAR', 'BEIJING', 'PEOPLES', 'VICTOR', 'MARIO', 'ATTACH', 'LICENSES', 'UTILS', 'REMOVING', 'ADVISED',
  'SPIDER', 'RANGES', 'PAIRS', 'TRAILS', 'HUDSON', 'ISOLATED', 'CALGARY', 'INTERIM', 'ASSISTED', 'DIVINE', 'APPROVE', 'CHOSE',
  'COMPOUND', 'ABORTION', 'DIALOG', 'VENUES', 'BLAST', 'WELLNESS', 'CALCIUM', 'NEWPORT', 'INDIANS', 'SHIELD', 'HARVEST', 'MEMBRANE',
  'PRAGUE', 'PREVIEWS', 'LOCALLY', 'PICKUP', 'MOTHERS', 'NASCAR', 'ICELAND', 'CANDLES', 'SAILING', 'SACRED', 'MOROCCO', 'CHROME',
  'TOMMY', 'REFUSED', 'BRAKE', 'EXTERIOR', 'GREETING', 'ECOLOGY', 'OLIVER', 'CONGO', 'BOTSWANA', 'DELAYS', 'OLIVE', 'CYBER',
  'VERIZON', 'SCORED', 'CLONE', 'VELOCITY', 'LAMBDA', 'RELAY', 'COMPOSED', 'TEARS', 'OASIS', 'BASELINE', 'ANGRY', 'SILICON',
  'COMPETE', 'LOVER', 'BELONG', 'HONOLULU', 'BEATLES', 'ROLLS', 'THOMSON', 'BARNES', 'MALTA', 'DADDY', 'FERRY', 'RABBIT',
  'SEATING', 'EXPORTS', 'OMAHA', 'ELECTRON', 'LOADS', 'HEATHER', 'PASSPORT', 'MOTEL', 'UNIONS', 'TREASURY', 'WARRANT', 'SOLARIS',
  'FROZEN', 'OCCUPIED', 'ROYALTY', 'SCALES', 'RALLY', 'OBSERVER', 'SUNSHINE', 'STRAIN', 'CEREMONY', 'SOMEHOW', 'ARRESTED', 'YAMAHA',
  'HEBREW', 'GAINED', 'DYING', 'LAUNDRY', 'STUCK', 'SOLOMON', 'PLACING', 'STOPS', 'HOMEWORK', 'ADJUST', 'ASSESSED', 'ENABLING',
  'FILLING', 'IMPOSED', 'SILENCE', 'FOCUSES', 'SOVIET', 'TREATY', 'VOCAL', 'TRAINER', 'ORGAN', 'STRONGER', 'VOLUMES', 'ADVANCES',
  'LEMON', 'TOXIC', 'DARKNESS', 'BIZRATE', 'VIENNA', 'IMPLIED', 'STANFORD', 'PACKING', 'STATUTE', 'REJECTED', 'SATISFY', 'SHELTER',
  'CHAPEL', 'GAMESPOT', 'LAYERS', 'GUIDED', 'BAHAMAS', 'POWELL', 'MIXTURE', 'BENCH', 'RIDER', 'RADIUS', 'LOGGING', 'HAMPTON',
  'BORDERS', 'BUTTS', 'BOBBY', 'SHEEP', 'RAILROAD', 'LECTURES', 'WINES', 'NURSERY', 'HARDER', 'CHEAPEST', 'TRAVESTI', 'STUART',
  'SALVADOR', 'SALAD', 'MONROE', 'TENDER', 'PASTE', 'CLOUDS', 'TANZANIA', 'PRESERVE', 'UNSIGNED', 'STAYING', 'EASTER', 'THEORIES',
  'PRAISE', 'JEREMY', 'VENICE', 'ESTONIA', 'VETERAN', 'STREAMS', 'LANDING', 'SIGNING', 'EXECUTED', 'KATIE', 'SHOWCASE', 'INTEGRAL',
  'RELAX', 'NAMIBIA', 'SYNOPSIS', 'HARDLY', 'PRAIRIE', 'REUNION', 'COMPOSER', 'SWORD', 'ABSENT', 'SELLS', 'ECUADOR', 'HOPING',
  'ACCESSED', 'SPIRITS', 'CORAL', 'PIXEL', 'FLOAT', 'COLIN', 'IMPORTED', 'PATHS', 'BUBBLE', 'ACQUIRE', 'CONTRARY', 'TRIBUNE',
  'VESSEL', 'ACIDS', 'FOCUSING', 'VIRUSES', 'CHEAPER', 'ADMITTED', 'DAIRY', 'ADMIT', 'FANCY', 'EQUALITY', 'SAMOA', 'STICKERS',
  'LEASING', 'LAUREN', 'BELIEFS', 'SQUAD', 'ANALYZE', 'ASHLEY', 'SCROLL', 'RELATE', 'WAGES', 'SUFFER', 'FORESTS', 'INVALID',
  'CONCERTS', 'MARTIAL', 'MALES', 'RETAIN', 'EXECUTE', 'TUNNEL', 'GENRES', 'CAMBODIA', 'PATENTS', 'CHAOS', 'WHEAT', 'BEAVER',
  'UPDATING', 'READINGS', 'KIJIJI', 'CONFUSED', 'COMPILER', 'EAGLES', 'BASES', 'ACCUSED', 'UNITY', 'BRIDE', 'DEFINES', 'AIRPORTS',
  'BEGUN', 'BRUNETTE', 'PACKETS', 'ANCHOR', 'SOCKS', 'PARADE', 'TRIGGER', 'GATHERED', 'ESSEX', 'SLOVENIA', 'NOTIFIED', 'BEACHES',
  'FOLDERS', 'DRAMATIC', 'SURFACES', 'TERRIBLE', 'ROUTERS', 'PENDANT', 'DRESSES', 'BAPTIST', 'HIRING', 'CLOCKS', 'FEMALES', 'WALLACE',
  'REFLECTS', 'TAXATION', 'FEVER', 'CUISINE', 'SURELY', 'MYSPACE', 'THEOREM', 'STYLUS', 'DRUMS', 'ARNOLD', 'CHICKS', 'CATTLE',
  'RADICAL', 'ROVER', 'TREASURE', 'RELOAD', 'FLAME', 'LEVITRA', 'TANKS', 'ASSUMING', 'MONETARY', 'ELDERLY', 'FLOATING', 'BOLIVIA',
  'SPELL', 'HOTTEST', 'STEVENS', 'KUWAIT', 'EMILY', 'ALLEGED', 'COMPILE', 'WEBSTER', 'STRUCK', 'PLYMOUTH', 'WARNINGS', 'BRIDAL',
  'ANNEX', 'TRIBAL', 'CURIOUS', 'FREIGHT', 'REBATE', 'MEETUP', 'ECLIPSE', 'SUDAN', 'SHUTTLE', 'STUNNING', 'CYCLES', 'AFFECTS',
  'DETECT', 'ACTIVELY', 'AMPLAND', 'FASTEST', 'BUTLER', 'INJURED', 'PAYROLL', 'COOKBOOK', 'COURIER', 'UPLOADED', 'HINTS', 'COLLAPSE',
  'AMERICAS', 'UNLIKELY', 'TECHNO', 'BEVERAGE', 'TRIBUTE', 'WIRED', 'ELVIS', 'IMMUNE', 'LATVIA', 'FORESTRY', 'BARRIERS', 'RARELY',
  'INFECTED', 'MARTHA', 'GENESIS', 'BARRIER', 'ARGUE', 'TRAINS', 'METALS', 'BICYCLE', 'LETTING', 'ARISE', 'CELTIC', 'THEREBY',
  'JAMIE', 'PARTICLE', 'MINERALS', 'ADVISE', 'HUMIDITY', 'BOTTLES', 'BOXING', 'BANGKOK', 'HUGHES', 'JEFFREY', 'CHESS', 'OPERATES',
  'BRISBANE', 'SURVIVE', 'OSCAR', 'MENUS', 'REVEAL', 'CANAL', 'AMINO', 'HERBS', 'CLINICS', 'MANITOBA', 'MISSIONS', 'WATSON',
  'LYING', 'COSTUMES', 'STRICT', 'SADDAM', 'DRILL', 'OFFENSE', 'BRYAN', 'PROTEST', 'HOBBY', 'TRIES', 'NICKNAME', 'INLINE',
  'WASHING', 'STAFFING', 'TRICK', 'ENQUIRY', 'CLOSURE', 'TIMBER', 'INTENSE', 'PLAYLIST', 'SHOWERS', 'RULING', 'STEADY', 'STATUTES',
  'MYERS', 'DROPS', 'WIDER', 'PLUGINS', 'ENROLLED', 'SENSORS', 'SCREW', 'PUBLICLY', 'HOURLY', 'BLAME', 'GENEVA', 'FREEBSD',
  'RESELLER', 'HANDED', 'SUFFERED', 'INTAKE', 'INFORMAL', 'TUCSON', 'HEAVILY', 'SWINGERS', 'FIFTY', 'HEADERS', 'MISTAKES', 'UNCLE',
  'DEFINING', 'COUNTING', 'ASSURE', 'DEVOTED', 'JACOB', 'SODIUM', 'RANDY', 'HORMONE', 'TIMOTHY', 'BRICK', 'NAVAL', 'MEDIEVAL',
  'BRIDGES', 'CAPTURED', 'THEHUN', 'DECENT', 'CASTING', 'DAYTON', 'SHORTLY', 'CAMERON', 'CARLOS', 'DONNA', 'ANDREAS', 'WARRIOR',
  'DIPLOMA', 'CABIN', 'INNOCENT', 'SCANNING', 'VALIUM', 'COPYING', 'CORDLESS', 'PATRICIA', 'EDDIE', 'UGANDA', 'FIRED', 'TRIVIA',
  'ADIDAS', 'PERTH', 'GRAMMAR', 'SYRIA', 'DISAGREE', 'KLEIN', 'HARVEY', 'TIRES', 'HAZARD', 'RETRO', 'GREGORY', 'EPISODES',
  'BOOLEAN', 'CIRCULAR', 'ANGER', 'MAINLAND', 'SUITS', 'CHANCES', 'INTERACT', 'BIZARRE', 'GLENN', 'AUCKLAND', 'OLYMPICS', 'FRUITS',
  'RIBBON', 'STARTUP', 'SUZUKI', 'TRINIDAD', 'KISSING', 'HANDY', 'EXEMPT', 'CROPS', 'REDUCES', 'GEOMETRY', 'SLOVAKIA', 'GUILD',
  'GORGEOUS', 'CAPITOL', 'DISHES', 'BARBADOS', 'CHRYSLER', 'NERVOUS', 'REFUSE', 'EXTENDS', 'MCDONALD', 'REPLICA', 'PLUMBING', 'BRUSSELS',
  'TRIBE', 'TRADES', 'SUPERB', 'TRINITY', 'HANDLED', 'LEGENDS', 'FLOORS', 'EXHAUST', 'SHANGHAI', 'SPEAKS', 'BURTON', 'DAVIDSON',
  'COPIED', 'SCOTIA', 'FARMING', 'GIBSON', 'ROLLER', 'BATCH', 'ORGANIZE', 'ALTER', 'NICOLE', 'LATINO', 'GHANA', 'EDGES',
  'MIXING', 'HANDLES', 'SKILLED', 'FITTED', 'HARMONY', 'ASTHMA', 'TWINS', 'TRIANGLE', 'AMEND', 'ORIENTAL', 'REWARD', 'WINDSOR',
  'ZAMBIA', 'HYDROGEN', 'WEBSHOTS', 'SPRINT', 'CHICK', 'ADVOCATE', 'INPUTS', 'GENOME', 'ESCORTS', 'THONG', 'MEDAL', 'COACHES',
  'VESSELS', 'WALKS', 'KNIVES', 'ARRANGE', 'ARTISTIC', 'HONORS', 'BOOTH', 'INDIE', 'UNIFIED', 'BONES', 'BREED', 'DETECTOR',
  'IGNORED', 'POLAR', 'FALLEN', 'PRECISE', 'SUSSEX', 'MSGID', 'INVOICE', 'GATHER', 'BACKED', 'ALFRED', 'COLONIAL', 'CAREY',
  'MOTELS', 'FORMING', 'EMBASSY', 'DANNY', 'REBECCA', 'SLIGHT', 'PROCEEDS', 'INDIRECT', 'AMONGST', 'MSGSTR', 'ARREST', 'ADIPEX',
  'HORIZON', 'DEEPLY', 'TOOLBOX', 'MARINA', 'PRIZES', 'BOSNIA', 'BROWSERS', 'PATIO', 'SURFING', 'LLOYD', 'OPTICS', 'PURSUE',
  'OVERCOME', 'ATTRACT', 'BRIGHTON', 'BEANS', 'ELLIS', 'DISABLE', 'SNAKE', 'SUCCEED', 'LEONARD', 'LENDING', 'REMINDER', 'SEARCHED',
  'PLAINS', 'RAYMOND', 'INSIGHTS', 'SULLIVAN', 'MIDWEST', 'KARAOKE', 'LONELY', 'HEREBY', 'OBSERVE', 'JULIA', 'BERRY', 'COLLAR',
  'RACIAL', 'BERMUDA', 'AMANDA', 'MOBILES', 'KELKOO', 'EXHIBITS', 'TERRACE', 'BACTERIA', 'REPLIED', 'SEAFOOD', 'NOVELS', 'OUGHT',
  'SAFELY', 'FINITE', 'KIDNEY', 'FIXES', 'SENDS', 'DURABLE', 'MAZDA', 'ALLIED', 'THROWS', 'MOISTURE', 'ROSTER', 'SYMANTEC',
  'SPENCER', 'WICHITA', 'NASDAQ', 'URUGUAY', 'TIMER', 'TABLETS', 'TUNING', 'GOTTEN', 'TYLER', 'FUTURES', 'VERSE', 'HIGHS',
  'WANTING', 'CUSTODY', 'SCRATCH', 'LAUNCHES', 'ELLEN', 'ROCKET', 'BULLET', 'TOWERS', 'RACKS', 'NASTY', 'LATITUDE', 'TUMOR',
  'DEPOSITS', 'BEVERLY', 'MISTRESS', 'TRUSTEES', 'WATTS', 'DUNCAN', 'REPRINTS', 'BERNARD', 'FORTY', 'TUBES', 'MIDLANDS', 'PRIEST',
  'FLOYD', 'RONALD', 'ANALYSTS', 'QUEUE', 'TRANCE', 'LOCALE', 'NICHOLAS', 'BUNDLE', 'HAMMER', 'INVASION', 'RUNNER', 'NOTION',
  'SKINS', 'MAILED', 'FUJITSU', 'SPELLING', 'ARCTIC', 'EXAMS', 'REWARDS', 'BENEATH', 'DEFEND', 'MEDICAID', 'INFRARED', 'SEVENTH',
  'WELSH', 'BELLY', 'QUARTERS', 'STOLEN', 'SOONEST', 'HAITI', 'NATURALS', 'LENDERS', 'FITTING', 'FIXTURES', 'BLOGGERS', 'AGREES',
  'SURPLUS', 'ELDER', 'SONIC', 'CHEERS', 'BELARUS', 'ZONING', 'GRAVITY', 'THUMB', 'GUITARS', 'ESSENCE', 'FLOORING', 'ETHIOPIA',
  'MIGHTY', 'ATHLETES', 'HUMANITY', 'HOLMES', 'SCHOLARS', 'GALAXY', 'CHESTER', 'SNAPSHOT', 'CARING', 'SEGMENTS', 'DOMINANT', 'TWIST',
  'ITUNES', 'STOMACH', 'BURIED', 'NEWBIE', 'MINIMIZE', 'DARWIN', 'RANKS', 'DEBUT', 'BRADLEY', 'ANATOMY', 'FRACTION', 'DEFECTS',
  'MILTON', 'MARKER', 'CLARITY', 'SANDRA', 'ADELAIDE', 'MONACO', 'SETTLED', 'FOLDING', 'EMIRATES', 'AIRFARE', 'VACCINE', 'BELIZE',
  'PROMISED', 'VOLVO', 'PENNY', 'ROBUST', 'BOOKINGS', 'MINOLTA', 'PORTER', 'JUNGLE', 'IVORY', 'ALPINE', 'ANDALE', 'FABULOUS',
  'REMIX', 'ALIAS', 'NEWER', 'SPICE', 'IMPLIES', 'COOLER', 'MARITIME', 'PERIODIC', 'OVERHEAD', 'ASCII', 'PROSPECT', 'SHIPMENT',
  'BREEDING', 'DONOR', 'TENSION', 'TRASH', 'SHAPES', 'MANOR', 'ENVELOPE', 'DIANE', 'HOMELAND', 'EXCLUDED', 'ANDREA', 'BREEDS',
  'RAPIDS', 'DISCO', 'BAILEY', 'ENDIF', 'EMOTIONS', 'INCOMING', 'LEXMARK', 'CLEANERS', 'ETERNAL', 'CASHIERS', 'ROTATION', 'EUGENE',
  'METRIC', 'MINUS', 'BENNETT', 'HOTMAIL', 'JOSHUA', 'ARMENIA', 'VARIED', 'GRANDE', 'CLOSEST', 'ACTRESS', 'ASSIGN', 'TIGERS',
  'AURORA', 'SLIDES', 'MILAN', 'PREMIERE', 'LENDER', 'VILLAGES', 'SHADE', 'CHORUS', 'RHYTHM', 'DIGIT', 'ARGUED', 'DIETARY',
  'SYMPHONY', 'CLARKE', 'SUDDEN', 'MARILYN', 'LIONS', 'FINDLAW', 'POOLS', 'LYRIC', 'CLAIRE', 'SPEEDS', 'MATCHED', 'CARROLL',
  'RATIONAL', 'FIGHTERS', 'CHAMBERS', 'WARMING', 'VOCALS', 'FOUNTAIN', 'CHUBBY', 'GRAVE', 'BURNER', 'FINNISH', 'GENTLE', 'DEEPER',
  'MUSLIMS', 'FOOTAGE', 'HOWTO', 'WORTHY', 'REVEALS', 'SAINTS', 'CARRIES', 'DEVON', 'HELENA', 'SAVES', 'REGARDED', 'MARION',
  'LOBBY', 'EGYPTIAN', 'TUNISIA', 'OUTLINED', 'HEADLINE', 'TREATING', 'PUNCH', 'GOTTA', 'COWBOY', 'BAHRAIN', 'ENORMOUS', 'KARMA',
  'CONSIST', 'BETTY', 'QUEENS', 'LUCAS', 'TRIBES', 'DEFEAT', 'CLICKS', 'HONDURAS', 'NAUGHTY', 'HAZARDS', 'INSURED', 'HARPER',
  'MARDI', 'TENANT', 'CABINETS', 'TATTOO', 'SHAKE', 'ALGEBRA', 'SHADOWS', 'HOLLY', 'SILLY', 'MERCY', 'HARTFORD', 'FREELY',
  'MARCUS', 'SUNRISE', 'WRAPPING', 'WEBLOGS', 'TIMELINE', 'BELONGS', 'READILY', 'FENCE', 'NUDIST', 'INFINITE', 'DIANA', 'ENSURES',
  'LINDSAY', 'LEGALLY', 'SHAME', 'CIVILIAN', 'FATAL', 'REMEDY', 'REALTORS', 'BRIEFLY', 'GENIUS', 'FIGHTER', 'FLESH', 'RETREAT',
  'ADAPTED', 'BARELY', 'WHEREVER', 'ESTATES', 'DEMOCRAT', 'BOROUGH', 'FAILING', 'RETAINED', 'PAMELA', 'ANDREWS', 'MARBLE', 'JESSE',
  'LOGITECH', 'SURREY', 'BRIEFING', 'BELKIN', 'HIGHLAND', 'MODULAR', 'BRANDON', 'GIANTS', 'BALLOON', 'WINSTON', 'SOLVED', 'HAWAIIAN',
  'GRATUIT', 'CONSOLES', 'QATAR', 'MAGNET', 'PORSCHE', 'CAYMAN', 'JAGUAR', 'SHEER', 'POSING', 'HOPKINS', 'URGENT', 'INFANTS',
  'GOTHIC', 'CYLINDER', 'WITCH', 'COHEN', 'PUPPY', 'KATHY', 'GRAPHS', 'SURROUND', 'REVENGE', 'EXPIRES', 'ENEMIES', 'FINANCES',
  'ACCEPTS', 'ENJOYING', 'PATROL', 'SMELL', 'ITALIANO', 'CARNIVAL', 'ROUGHLY', 'STICKER', 'PROMISES', 'DIVIDE', 'CORNELL', 'SATIN',
  'DESERVE', 'MAILTO', 'PROMO', 'WORRIED', 'TUNES', 'GARBAGE', 'COMBINES', 'BRADFORD', 'PHRASES', 'CHELSEA', 'BORING', 'REYNOLDS',
  'SPEECHES', 'REACHES', 'SCHEMA', 'CATALOGS', 'QUIZZES', 'PREFIX', 'LUCIA', 'SAVANNAH', 'BARREL', 'TYPING', 'NERVE', 'PLANETS',
  'DEFICIT', 'BOULDER', 'POINTING', 'RENEW', 'COUPLED', 'MYANMAR', 'METADATA', 'HAROLD', 'CIRCUITS', 'FLOPPY', 'TEXTURE', 'HANDBAGS',
  'SOMERSET', 'INCURRED', 'ANTIGUA', 'THUNDER', 'CAUTION', 'LOCKS', 'NAMELY', 'EUROS', 'PIRATES', 'AERIAL', 'REBEL', 'ORIGINS',
  'HIRED', 'MAKEUP', 'TEXTILE', 'NATHAN', 'TOBAGO', 'INDEXES', 'HINDU', 'LICKING', 'MARKERS', 'WEIGHTS', 'ALBANIA', 'LASTING',
  'WICKED', 'KILLS', 'ROOMMATE', 'WEBCAMS', 'PUSHED', 'SLOPE', 'REGGAE', 'FAILURES', 'SURNAME', 'THEOLOGY', 'NAILS', 'EVIDENT',
  'WHATS', 'RIDES', 'REHAB', 'SATURN', 'ALLERGY', 'TWISTED', 'MERIT', 'ENZYME', 'ZSHOPS', 'PLANES', 'EDMONTON', 'TACKLE',
  'DISKS', 'CONDO', 'POKEMON', 'AMBIEN', 'RETRIEVE', 'VERNON', 'WORLDCAT', 'TITANIUM', 'FAIRY', 'BUILDS', 'SHAFT', 'LESLIE',
  'CASIO', 'DEUTSCHE', 'POSTINGS', 'KITTY', 'DRAIN', 'MONTE', 'FIRES', 'ALGERIA', 'BLESSED', 'CARDIFF', 'CORNWALL', 'FAVORS',
  'POTATO', 'PANIC', 'STICKS', 'LEONE', 'EXCUSE', 'REFORMS', 'BASEMENT', 'ONION', 'STRAND', 'SANDWICH', 'LAWSUIT', 'CHEQUE',
  'BANNERS', 'REJECT', 'CIRCLES', 'ITALIC', 'BEATS', 'MERRY', 'SCUBA', 'PASSIVE', 'VALUED', 'COURAGE', 'VERDE', 'GAZETTE',
  'HITACHI', 'BATMAN', 'HEARINGS', 'COLEMAN', 'ANAHEIM', 'TEXTBOOK', 'DRIED', 'LUTHER', 'FRONTIER', 'SETTLE', 'STOPPING', 'REFUGEES',
  'KNIGHTS', 'PALMER', 'DERBY', 'PEACEFUL', 'ALTERED', 'PONTIAC', 'DOCTRINE', 'SCENIC', 'TRAINERS', 'SEWING', 'CONCLUDE', 'MUNICH',
  'CELEBS', 'PROPOSE', 'LIGHTER', 'ADVISORS', 'PAVILION', 'TACTICS', 'TRUSTS', 'TALENTED', 'ANNIE', 'PILLOW', 'DEREK', 'SHORTER',
  'HARLEY', 'RELYING', 'FINALS', 'PARAGUAY', 'STEAL', 'PARCEL', 'REFINED', 'FIFTEEN', 'FEARS', 'PREDICT', 'BOUTIQUE', 'ACRYLIC',
  'ROLLED', 'TUNER', 'PETERSON', 'SHANNON', 'TODDLER', 'FLAVOR', 'ALIKE', 'HOMELESS', 'HORRIBLE', 'HUNGRY', 'METALLIC', 'BLOCKED',
  'WARRIORS', 'CADILLAC', 'MALAWI', 'SAGEM', 'CURTIS', 'PARENTAL', 'STRIKES', 'LESSER', 'MARATHON', 'PRESSING', 'GASOLINE', 'DRESSED',
  'SCOUT', 'BELFAST', 'DEALT', 'NIAGARA', 'WARCRAFT', 'CHARMS', 'CATALYST', 'TRADER', 'BUCKS', 'DENIAL', 'THROWN', 'PREPAID',
  'RAISES', 'ELECTRO', 'BADGE', 'WRIST', 'ANALYZED', 'HEATH', 'BALLOT', 'LEXUS', 'VARYING', 'REMEDIES', 'VALIDITY', 'TRUSTEE',
  'WEIGHTED', 'ANGOLA', 'PERFORMS', 'PLASTICS', 'REALM', 'JENNY', 'HELMET', 'SALARIES', 'POSTCARD', 'ELEPHANT', 'YEMEN', 'TSUNAMI',
  'SCHOLAR', 'NICKEL', 'BUSES', 'EXPEDIA', 'GEOLOGY', 'COATING', 'WALLET', 'CLEARED', 'SMILIES', 'BOATING', 'DRAINAGE', 'SHAKIRA',
  'CORNERS', 'BROADER', 'ROUGE', 'YEAST', 'CLEARING', 'COATED', 'INTEND', 'LOUISE', 'KENNY', 'ROUTINES', 'HITTING', 'YUKON',
  'BEINGS', 'AQUATIC', 'RELIANCE', 'HABITS', 'STRIKING', 'PODCASTS', 'SINGH', 'GILBERT', 'FERRARI', 'BROOK', 'OUTPUTS', 'ENSEMBLE',
  'INSULIN', 'ASSURED', 'BIBLICAL', 'ACCENT', 'MYSIMON', 'ELEVEN', 'WIVES', 'AMBIENT', 'UTILIZE', 'MILEAGE', 'PROSTATE', 'ADAPTOR',
  'AUBURN', 'UNLOCK', 'HYUNDAI', 'PLEDGE', 'VAMPIRE', 'ANGELA', 'RELATES', 'NITROGEN', 'XEROX', 'MERGER', 'SOFTBALL', 'FIREWIRE',
  'NEXTEL', 'FRAMING', 'MUSICIAN', 'BLOCKING', 'RWANDA', 'SORTS', 'VSNET', 'LIMITING', 'DISPATCH', 'PAPUA', 'RESTORED', 'ARMOR',
  'RIDERS', 'CHARGERS', 'REMARK', 'DOZENS', 'VARIES', 'RENDERED', 'PICKING', 'GUARDS', 'OPENINGS', 'COUNCILS', 'KRUGER', 'POCKETS',
  'GRANNY', 'VIRAL', 'INQUIRE', 'PIPES', 'LADEN', 'ARUBA', 'COTTAGES', 'REALTOR', 'MERGE', 'EDGAR', 'DEVELOPS', 'CHASSIS',
  'DUBAI', 'PUSHING', 'FLEECE', 'PIERCE', 'ALLAN', 'DRESSING', 'SPERM', 'FILME', 'CRAPS', 'FROST', 'SALLY', 'YACHT',
  'TRACY', 'PREFERS', 'DRILLING', 'BREACH', 'WHALE', 'TOMATOES', 'BEDFORD', 'MUSTANG', 'CLUSTERS', 'ANTIBODY', 'MOMENTUM', 'WIRING',
  'PASTOR', 'CALVIN', 'SHARK', 'PHASES', 'GRATEFUL', 'EMERALD', 'LAUGHING', 'GROWS', 'CLIFF', 'TRACT', 'BALLET', 'ABRAHAM',
  'BUMPER', 'WEBPAGE', 'GARLIC', 'HOSTELS', 'SHINE', 'SENEGAL', 'BANNED', 'WENDY', 'BRIEFS', 'DIFFS', 'MUMBAI', 'OZONE',
  'RADIOS', 'TARIFF', 'NVIDIA', 'OPPONENT', 'PASTA', 'MUSCLES', 'SERUM', 'WRAPPED', 'SWIFT', 'RUNTIME', 'INBOX', 'FOCAL',
  'DISTANT', 'DECIMAL', 'PROPECIA', 'SAMBA', 'HOSTEL', 'EMPLOY', 'MONGOLIA', 'PENGUIN', 'MAGICAL', 'MIRACLE', 'MANUALLY', 'REPRINT',
  'CENTERED', 'YEARLY', 'WOUND', 'BELLE', 'WRITINGS', 'HAMBURG', 'CINDY', 'FATHERS', 'CHARGING', 'MARVEL', 'LINED', 'PETITE',
  'TERRAIN', 'STRIPS', 'GOSSIP', 'RANGERS', 'ROTARY', 'DISCRETE', 'BEGINNER', 'BOXED', 'CUBIC', 'SAPPHIRE', 'KINASE', 'SKIRTS',
  'CRAWFORD', 'LABELED', 'MARKING', 'SERBIA', 'SHERIFF', 'GRIFFIN', 'DECLINED', 'GUYANA', 'SPIES', 'NEIGHBOR', 'ELECT', 'HIGHWAYS',
  'THINKPAD', 'INTIMATE', 'PRESTON', 'DEADLY', 'BUNNY', 'CHEVY', 'ROUNDS', 'LONGEST', 'TIONS', 'DENTISTS', 'FLYER', 'DOSAGE',
  'VARIANCE', 'CAMEROON', 'BAKING', 'ADAPTIVE', 'COMPUTED', 'NEEDLE', 'BATHS', 'BRAKES', 'NIRVANA', 'INVISION', 'STICKY', 'DESTINY',
  'GENEROUS', 'MADNESS', 'EMACS', 'CLIMB', 'BLOWING', 'HEATED', 'JACKIE', 'SPARC', 'CARDIAC', 'DOVER', 'ADRIAN', 'VATICAN',
  'BRUTAL', 'LEARNERS', 'TOKEN', 'SEEKERS', 'YIELDS', 'SUITED', 'NUMERIC', 'SKATING', 'KINDA', 'ABERDEEN', 'EMPEROR', 'DYLAN',
  'BELTS', 'BLACKS', 'EDUCATED', 'REBATES', 'BURKE', 'PROUDLY', 'INSERTED', 'PULLING', 'BASENAME', 'OBESITY', 'CURVES', 'SUBURBAN',
  'TOURING', 'CLARA', 'VERTEX', 'TOMATO', 'ANDORRA', 'EXPIRED', 'TRAVELS', 'FLUSH', 'WAIVER', 'HAYES', 'DELIGHT', 'SURVIVOR',
  'GARCIA', 'CINGULAR', 'MOSES', 'COUNTED', 'DECLARE', 'JOHNS', 'VALVES', 'IMPAIRED', 'DONORS', 'JEWEL', 'TEDDY', 'TEACHES',
  'VENTURES', 'BUFING', 'STRANGER', 'TRAGEDY', 'JULIAN', 'DRYER', 'PAINFUL', 'VELVET', 'TRIBUNAL', 'RULED', 'PENSIONS', 'PRAYERS',
  'FUNKY', 'NOWHERE', 'JOINS', 'WESLEY', 'LATELY', 'SCARY', 'MATTRESS', 'MPEGS', 'BRUNEI', 'LIKEWISE', 'BANANA', 'SLOVAK',
  'CAKES', 'MIXER', 'REMIND', 'SBJCT', 'CHARMING', 'TOOTH', 'ANNOYING', 'STAYS', 'DISCLOSE', 'AFFAIR', 'DROVE', 'WASHER',
  'UPSET', 'RESTRICT', 'SPRINGER', 'BESIDE', 'MINES', 'REBOUND', 'LOGAN', 'MENTOR', 'FOUGHT', 'BAGHDAD', 'METRES', 'PENCIL',
  'FREEZE', 'TITLED', 'SPHERE', 'RATIOS', 'CONCORD', 'ENDORSED', 'WALNUT', 'LANCE', 'LADDER', 'ITALIA', 'LIBERIA', 'SHERMAN',
  'MAXIMIZE', 'HANSEN', 'SENATORS', 'WORKOUT', 'BLEEDING', 'COLON', 'LANES', 'PURSE', 'OPTIMIZE', 'STATING', 'CAROLINE', 'ALIGN',
  'BLESS', 'ENGAGING', 'CREST', 'TRIUMPH', 'WELDING', 'DEFERRED', 'ALLOY', 'CONDOS', 'PLOTS', 'POLISHED', 'GENTLY', 'TULSA',
  'LOCKING', 'CASEY', 'DRAWS', 'FRIDGE', 'BLANKET', 'BLOOM', 'SIMPSONS', 'ELLIOTT', 'FRASER', 'JUSTIFY', 'BLADES', 'LOOPS',
  'SURGE', 'TRAUMA', 'TAHOE', 'ADVERT', 'POSSESS', 'FLASHERS', 'SUBARU', 'VANILLA', 'PICNIC', 'SOULS', 'ARRIVALS', 'SPANK',
  'HOLLOW', 'VAULT', 'SECURELY', 'FIORICET', 'GROOVE', 'PURSUIT', 'WIRES', 'MAILS', 'BACKING', 'SLEEPS', 'BLAKE', 'TRAVIS',
  'ENDLESS', 'FIGURED', 'ORBIT', 'NIGER', 'BACON', 'HEATER', 'COLONY', 'CANNON', 'CIRCUS', 'PROMOTED', 'FORBES', 'MOLDOVA',
  'PAXIL', 'SPINE', 'TROUT', 'ENCLOSED', 'COOKED', 'THRILLER', 'TRANSMIT', 'APNIC', 'FATTY', 'GERALD', 'PRESSED', 'SCANNED',
  'HUNGER', 'MARIAH', 'JOYCE', 'SURGEON', 'CEMENT', 'PLANNERS', 'DISPUTES', 'TEXTILES', 'MISSILE', 'INTRANET', 'CLOSES', 'DEBORAH',
  'MARCO', 'ASSISTS', 'GABRIEL', 'AUDITOR', 'AQUARIUM', 'VIOLIN', 'PROPHET', 'BRACKET', 'ISAAC', 'OXIDE', 'NAPLES', 'PROMPTLY',
  'MODEMS', 'HARMFUL', 'PROZAC', 'SEXUALLY', 'DIVIDEND', 'NEWARK', 'GLUCOSE', 'PHANTOM', 'PLAYBACK', 'TURTLE', 'WARNED', 'NEURAL',
  'FOSSIL', 'HOMETOWN', 'BADLY', 'APOLLO', 'PERSIAN', 'HANDMADE', 'GREENE', 'ROBOTS', 'GRENADA', 'SCOOP', 'EARNING', 'MAILMAN',
  'SANYO', 'NESTED', 'SOMALIA', 'MOVERS', 'VERBAL', 'BLINK', 'CARLO', 'WORKFLOW', 'NOVELTY', 'BRYANT', 'TILES', 'VOYUER',
  'SWITCHED', 'TAMIL', 'GARMIN', 'FUZZY', 'GRAMS', 'RICHARDS', 'BUDGETS', 'TOOLKIT', 'RENDER', 'CARMEN', 'HARDWOOD', 'EROTICA',
  'TEMPORAL', 'FORGE', 'DENSE', 'BRAVE', 'AWFUL', 'AIRPLANE', 'ISTANBUL', 'IMPOSE', 'VIEWERS', 'ASBESTOS', 'MEYER', 'ENTERS',
  'SAVAGE', 'WILLOW', 'RESUMES', 'THROWING', 'EXISTED', 'WAGON', 'BARBIE', 'KNOCK', 'POTATOES', 'THOROUGH', 'PEERS', 'ROLAND',
  'OPTIMUM', 'QUILT', 'CREATURE', 'MOUNTS', 'SYRACUSE', 'REFRESH', 'WEBCAST', 'MICHEL', 'SUBTLE', 'NOTRE', 'MALDIVES', 'STRIPES',
  'FIRMWARE', 'SHEPHERD', 'CANBERRA', 'CRADLE', 'MAMBO', 'FLOUR', 'SYMPATHY', 'CHOIR', 'AVOIDING', 'BLOND', 'EXPECTS', 'JUMPING',
  'FABRICS', 'POLYMER', 'HYGIENE', 'POULTRY', 'VIRTUE', 'BURST', 'SURGEONS', 'BOUQUET', 'PROMOTES', 'MANDATE', 'WILEY', 'CORPUS',
  'JOHNSTON', 'FIBRE', 'SHADES', 'INDICES', 'ADWARE', 'ZOLOFT', 'PRISONER', 'DAISY', 'HALIFAX', 'ULTRAM', 'CURSOR', 'EARLIEST',
  'DONATED', 'STUFFED', 'INSECTS', 'CRUDE', 'MORRISON', 'MAIDEN', 'EXAMINES', 'VIKING', 'MYRTLE', 'BORED', 'CLEANUP', 'BOTHER',
  'BUDAPEST', 'KNITTING', 'ATTACKED', 'BHUTAN', 'MATING', 'COMPUTE', 'REDHEAD', 'ARRIVES', 'TRACTOR', 'ALLAH', 'UNWRAP', 'FARES',
  'RESIST', 'HOPED', 'SAFER', 'WAGNER', 'TOUCHED', 'COLOGNE', 'WISHING', 'RANGER', 'SMALLEST', 'NEWMAN', 'MARSH', 'RICKY',
  'SCARED', 'THETA', 'MONSTERS', 'ASYLUM', 'LIGHTBOX', 'ROBBIE', 'STAKE', 'COCKTAIL', 'OUTLETS', 'ARBOR', 'POISON', 'PEN',
  'PENS', 'PIN', 'PINS', 'PAN', 'PANS', 'SNIP', 'SPIN', 'NIPS', 'SIPS', 'HEN', 'HENS', 'HEAP',
  'HYPE', 'SHED', 'PAIN', 'PAINS', 'SPINES', 'SHINES', 'SNAP', 'SNAPS', 'SPINS', 'SNIPS', 'HAP', 'HAS',
  'HIS', 'SIN', 'SINS', 'SAP', 'SAPS', 'HIP', 'HIPS', 'APE', 'APES', 'NAP', 'NAPS', 'SIP',
  'PAS', 'SPA', 'SPAS', 'SHIN', 'SHINS', 'TUB', 'BUT', 'NOW', 'WON', 'OWN',
};
