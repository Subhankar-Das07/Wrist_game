import 'package:shared_preferences/shared_preferences.dart';

class ScoreManager {
  static const String _fallBallScoresKey = 'fallBallScores';
  static const String _hitStarsScoresKey = 'hitStarsScores';

  static Future<void> saveScore(String gameMode, int score) async {
    if (score == 0) return; // Don't save zero scores
    final prefs = await SharedPreferences.getInstance();
    String key = gameMode == 'Fall Ball' ? _fallBallScoresKey : _hitStarsScoresKey;
    
    List<String> scores = prefs.getStringList(key) ?? [];
    scores.add(score.toString());
    
    // Sort scores descending and keep top 10
    List<int> intScores = scores.map((s) => int.parse(s)).toList();
    intScores.sort((a, b) => b.compareTo(a));
    if (intScores.length > 10) {
      intScores = intScores.sublist(0, 10);
    }
    
    scores = intScores.map((s) => s.toString()).toList();
    await prefs.setStringList(key, scores);
  }

  static Future<List<int>> getScores(String gameMode) async {
    final prefs = await SharedPreferences.getInstance();
    String key = gameMode == 'Fall Ball' ? _fallBallScoresKey : _hitStarsScoresKey;
    
    List<String> scores = prefs.getStringList(key) ?? [];
    return scores.map((s) => int.parse(s)).toList();
  }
}
