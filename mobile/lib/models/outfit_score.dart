/// Kaydetmeden önce hesaplanan kombin uyum puanı.
class OutfitScore {
  final double score;
  final double colorScore;
  final double patternScore;
  final double occasionScore;
  final List<String> reasons;

  const OutfitScore({
    required this.score,
    required this.colorScore,
    required this.patternScore,
    this.occasionScore = 1.0,
    this.reasons = const [],
  });

  factory OutfitScore.fromJson(Map<String, dynamic> json) {
    return OutfitScore(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      colorScore: (json['color_score'] as num?)?.toDouble() ?? 0,
      patternScore: (json['pattern_score'] as num?)?.toDouble() ?? 0,
      occasionScore: (json['occasion_score'] as num?)?.toDouble() ?? 1.0,
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  int get percent => (score * 100).round();

  String get percentLabel => 'Uyum %$percent';

  String get levelLabel {
    if (score >= 0.85) return 'Mükemmel uyum';
    if (score >= 0.70) return 'İyi uyum';
    if (score >= 0.50) return 'Kabul edilebilir';
    return 'Uyumsuz';
  }

  String get breakdown {
    final parts = <String>[
      'Renk %${(colorScore * 100).round()}',
      'Desen %${(patternScore * 100).round()}',
    ];
    if (occasionScore < 0.999) {
      parts.add('Etkinlik %${(occasionScore * 100).round()}');
    }
    return parts.join(' · ');
  }
}
