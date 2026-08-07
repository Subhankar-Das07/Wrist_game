import 'package:shared_preferences/shared_preferences.dart';

class ScoreManager {
  // Game scores keys
  static const String _fallBallScoresKey = 'fallBallScores';
  static const String _hitBugsScoresKey = 'hitBugsScores';
  static const String _legacyHitStarsScoresKey = 'hitStarsScores';

  // Lifetime bug kill keys
  static const String _keyLifetimeTotalBugs = 'lifetime_total_bugs';
  static const String _keyLifetimeFlies = 'lifetime_bugs_fly';
  static const String _keyLifetimeMosquitoes = 'lifetime_bugs_mosquito';
  static const String _keyLifetimeHornets = 'lifetime_bugs_hornet';
  static const String _keyLifetimeToxicBeetles = 'lifetime_bugs_toxicBeetle';

  static String _getScoresKey(String gameMode) {
    if (gameMode == 'Fall Ball') return _fallBallScoresKey;
    return _hitBugsScoresKey;
  }

  static Future<void> saveScore(String gameMode, int score) async {
    if (score == 0) return; // Don't save zero scores
    final prefs = await SharedPreferences.getInstance();
    String key = _getScoresKey(gameMode);

    List<String> scores = prefs.getStringList(key) ?? [];
    // If empty and checking Hit Bugs, check legacy hit stars
    if (scores.isEmpty && key == _hitBugsScoresKey) {
      scores = prefs.getStringList(_legacyHitStarsScoresKey) ?? [];
    }

    scores.add(score.toString());

    // Sort scores descending and keep top 10
    List<int> intScores = scores.map((s) => int.tryParse(s) ?? 0).toList();
    intScores.sort((a, b) => b.compareTo(a));
    if (intScores.length > 10) {
      intScores = intScores.sublist(0, 10);
    }

    scores = intScores.map((s) => s.toString()).toList();
    await prefs.setStringList(key, scores);
  }

  static Future<List<int>> getScores(String gameMode) async {
    final prefs = await SharedPreferences.getInstance();
    String key = _getScoresKey(gameMode);

    List<String> scores = prefs.getStringList(key) ?? [];
    if (scores.isEmpty && key == _hitBugsScoresKey) {
      scores = prefs.getStringList(_legacyHitStarsScoresKey) ?? [];
    }

    List<int> intScores = scores.map((s) => int.tryParse(s) ?? 0).toList();
    intScores.sort((a, b) => b.compareTo(a));
    return intScores;
  }

  /// Records an individual bug kill into persistent lifetime storage
  static Future<void> recordBugKill(String bugTypeName) async {
    final prefs = await SharedPreferences.getInstance();

    // Increment overall total
    int currentTotal = prefs.getInt(_keyLifetimeTotalBugs) ?? 0;
    await prefs.setInt(_keyLifetimeTotalBugs, currentTotal + 1);

    // Increment specific bug category
    String specificKey;
    switch (bugTypeName.toLowerCase()) {
      case 'mosquito':
        specificKey = _keyLifetimeMosquitoes;
        break;
      case 'hornet':
        specificKey = _keyLifetimeHornets;
        break;
      case 'toxicbeetle':
      case 'toxic_beetle':
        specificKey = _keyLifetimeToxicBeetles;
        break;
      case 'fly':
      case 'housefly':
      default:
        specificKey = _keyLifetimeFlies;
        break;
    }

    int currentCount = prefs.getInt(specificKey) ?? 0;
    await prefs.setInt(specificKey, currentCount + 1);
  }

  /// Retrieves all lifetime bug extermination records
  static Future<Map<String, int>> getLifetimeBugStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'total': prefs.getInt(_keyLifetimeTotalBugs) ?? 0,
      'fly': prefs.getInt(_keyLifetimeFlies) ?? 0,
      'mosquito': prefs.getInt(_keyLifetimeMosquitoes) ?? 0,
      'hornet': prefs.getInt(_keyLifetimeHornets) ?? 0,
      'toxicBeetle': prefs.getInt(_keyLifetimeToxicBeetles) ?? 0,
    };
  }

  /// Returns hunter rank information based on lifetime bug kills
  static Map<String, dynamic> getHunterRank(int totalKills) {
    if (totalKills >= 500) {
      return {
        'title': 'Legendary Exterminator',
        'badge': '👑',
        'nextTier': 'MAX RANK',
        'progress': 1.0,
      };
    } else if (totalKills >= 250) {
      return {
        'title': 'Master Hunter',
        'badge': '🥇',
        'nextTier': '500 for Legendary',
        'progress': (totalKills - 250) / 250.0,
      };
    } else if (totalKills >= 100) {
      return {
        'title': 'Swatter Veteran',
        'badge': '🥈',
        'nextTier': '250 for Master Hunter',
        'progress': (totalKills - 100) / 150.0,
      };
    } else if (totalKills >= 30) {
      return {
        'title': 'Bug Slayer',
        'badge': '🥉',
        'nextTier': '100 for Swatter Veteran',
        'progress': (totalKills - 30) / 70.0,
      };
    } else {
      return {
        'title': 'Novice Swatter',
        'badge': '🌱',
        'nextTier': '30 for Bug Slayer',
        'progress': (totalKills / 30.0).clamp(0.0, 1.0),
      };
    }
  }
}
