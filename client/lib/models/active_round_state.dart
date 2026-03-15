import "poker_card.dart";

class DoubleUpState {
  DoubleUpState({
    required this.dealerCard,
    required this.currentAmount,
    required this.switchesRemaining,
    required this.isNoLoseActive,
    required this.luckyMultiplier,
  });

  final PokerCard dealerCard;
  final int currentAmount;
  final int switchesRemaining;
  final bool isNoLoseActive;
  final int luckyMultiplier;

  factory DoubleUpState.fromJson(Map<String, dynamic> json) {
    return DoubleUpState(
      dealerCard: PokerCard.fromJson(json["dealerCard"] as Map<String, dynamic>),
      currentAmount: (json["currentAmount"] as num).toInt(),
      switchesRemaining: (json["switchesRemaining"] as num).toInt(),
      isNoLoseActive: json["isNoLoseActive"] as bool? ?? false,
      luckyMultiplier: (json["luckyMultiplier"] as num? ?? 0).toInt(),
    );
  }
}

class ActiveRoundState {
  ActiveRoundState({
    required this.roundId,
    required this.machineId,
    required this.betAmount,
    required this.phase,
    required this.cards,
    required this.heldIndexes,
    required this.pendingWinAmount,
    this.doubleUpSession,
  });

  final String roundId;
  final int machineId;
  final double betAmount;

  /// "Dealt" | "Drawn" | "DoubleUp"
  final String phase;
  final List<PokerCard> cards;
  final List<int> heldIndexes;
  final double pendingWinAmount;
  final DoubleUpState? doubleUpSession;

  factory ActiveRoundState.fromJson(Map<String, dynamic> json) {
    final duRaw = json["doubleUpSession"] as Map<String, dynamic>?;
    return ActiveRoundState(
      roundId: json["roundId"] as String,
      machineId: (json["machineId"] as num).toInt(),
      betAmount: (json["betAmount"] as num).toDouble(),
      phase: json["phase"] as String? ?? "Dealt",
      cards: ((json["cards"] as List<dynamic>?) ?? const [])
          .map((e) => PokerCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      heldIndexes: ((json["heldIndexes"] as List<dynamic>?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      pendingWinAmount: (json["pendingWinAmount"] as num? ?? 0).toDouble(),
      doubleUpSession:
          duRaw != null ? DoubleUpState.fromJson(duRaw) : null,
    );
  }
}
