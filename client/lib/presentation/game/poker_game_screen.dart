import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";

import "../../core/api/game_api.dart";
import "../../core/config/app_config.dart";
import "../../core/network/hub_client.dart";
import "../../models/deal_result.dart";
import "../../models/draw_result.dart";
import "../../models/poker_card.dart";

class PokerGameArgs {
  PokerGameArgs({
    required this.accessToken,
    required this.machineId,
  });

  final String accessToken;
  final int machineId;
}

class PokerGameScreen extends StatefulWidget {
  const PokerGameScreen({
    super.key,
    required this.gameApi,
    required this.accessToken,
    required this.machineId,
  });

  final GameApi gameApi;
  final String accessToken;
  final int machineId;

  @override
  State<PokerGameScreen> createState() => _PokerGameScreenState();
}

class _PokerGameScreenState extends State<PokerGameScreen>
    with WidgetsBindingObserver {
  final _betController = TextEditingController(text: "5000");
  final Set<int> _holds = <int>{};

  late final HubClient _hubClient;

  Timer? _heartbeatTimer;
  DealResult? _dealResult;
  DrawResult? _drawResult;
  _MachineSnapshot? _machineSnapshot;

  bool _loading = false;
  bool _hubReady = false;
  bool _hubHandlersBound = false;
  String _message = "Connecting to machine...";
  double _walletBalance = 0;

  // Kent counter for sequential straights
  int _kentCounter = 0;

  // Card preloading cache for performance
  final Map<String, Widget> _cardCache = {};
  bool _cardsPreloaded = false;

  // Track held cards with their data to fix reorganization bug
  final Map<int, PokerCard> _heldCardsData = {};

  bool get _hasOpenHand => _dealResult != null && _drawResult == null;
  String get _dealDrawLabel => _hasOpenHand ? "DRAW" : "DEAL";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hubClient = HubClient(AppConfig.fromEnvironment());
    unawaited(_preloadCards());
    unawaited(_bootstrapRealtime());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _betController.dispose();
    unawaited(_hubClient.invoke(
      "LeaveMachine",
      args: <Object>[widget.machineId],
    ).catchError((_) => null));
    unawaited(_hubClient.disconnect().catchError((_) => null));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreRealtimeSession());
    }
  }

  Future<void> _preloadCards() async {
    if (_cardsPreloaded) return;

    // Preload common card widgets to prevent lag
    final ranks = [
      'A',
      'K',
      'Q',
      'J',
      '10',
      '9',
      '8',
      '7',
      '6',
      '5',
      '4',
      '3',
      '2'
    ];
    final suits = ['H', 'D', 'C', 'S'];

    for (final rank in ranks) {
      for (final suit in suits) {
        final key = '$rank$suit';
        // Pre-build card widgets for faster rendering
        _cardCache[key] =
            _buildOptimizedCard(PokerCard(rank: rank, suit: suit), false);
      }
    }

    _cardsPreloaded = true;
  }

  Widget _buildOptimizedCard(PokerCard? card, bool held) {
    if (card == null) return _CabinetCard(card: null, held: held);

    final key = '${card.rank}${card.suit}';
    // Use cached widget if available and not held
    if (!held && _cardCache.containsKey(key)) {
      return _cardCache[key]!;
    }
    return _CabinetCard(card: card, held: held);
  }

  Future<void> _bootstrapRealtime() async {
    await _restoreRealtimeSession();
    _heartbeatTimer ??= Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(_pulseHeartbeat()),
    );
  }

  Future<void> _restoreRealtimeSession() async {
    try {
      await _hubClient.connect(widget.accessToken);
      _bindHubHandlers();
      await _hubClient.invoke(
        "JoinMachine",
        args: <Object>[widget.machineId],
      );
      await _hubClient.invoke(
        "ReconnectSync",
        args: <Object>[widget.machineId],
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hubReady = true;
        if (_message == "Connecting to machine...") {
          _message = "Pick your hold cards, then press DEAL.";
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _hubReady = false;
        _message =
            "Realtime link unavailable. Cabinet will continue with HTTP fallback.";
      });
    }
  }

  Future<void> _pulseHeartbeat() async {
    try {
      await _hubClient.connect(widget.accessToken);
      await _hubClient.invoke(
        "JoinMachine",
        args: <Object>[widget.machineId],
      );
      await _hubClient.invoke("Heartbeat");

      if (!mounted || _hubReady) {
        return;
      }

      setState(() => _hubReady = true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _hubReady = false);
    }
  }

  void _bindHubHandlers() {
    if (_hubHandlersBound) {
      return;
    }

    _hubHandlersBound = true;

    _hubClient.on("MachineStateUpdated", (args) {
      final payload = _decodePayload(args);
      if (!mounted || payload.isEmpty) {
        return;
      }

      setState(() {
        _machineSnapshot = _MachineSnapshot.fromJson(payload);
      });
    });

    _hubClient.on("CardsDealt", (args) {
      final payload = _decodePayload(args);
      if (!mounted || payload.isEmpty) {
        return;
      }

      final result = DealResult.fromJson(payload);
      setState(() {
        _dealResult = result;
        _drawResult = null;
        _holds.clear();
        _heldCardsData.clear();
        _walletBalance = result.walletBalanceAfterBet;
        _loading = false;
        _message = "Choose the cards to HOLD, then press DRAW.";
      });
    });

    _hubClient.on("CardRevealed", (args) {
      final payload = _decodePayload(args);
      if (!mounted || payload.isEmpty) {
        return;
      }

      final result = DrawResult.fromJson(payload);
      setState(() {
        _drawResult = result;
        _walletBalance = result.walletBalanceAfterRound;
        _loading = false;
        _message = result.winAmount > 0
            ? result.doubleUpAvailable
                ? "${result.handRank} pays ${result.winAmount.toStringAsFixed(0)} credits. Double-up is available on supported cabinets."
                : "${result.handRank} pays ${result.winAmount.toStringAsFixed(0)} credits. Cash out to continue."
            : "No win this hand.";
      });
    });

    _hubClient.on("WalletUpdated", (args) {
      final payload = _decodePayload(args);
      if (!mounted || payload.isEmpty) {
        return;
      }

      final nextBalance =
          (payload["walletBalanceAfterRound"] as num?)?.toDouble();
      if (nextBalance == null) {
        return;
      }

      setState(() => _walletBalance = nextBalance);
    });

    _hubClient.on("Error", (args) {
      final payload = _decodePayload(args);
      if (!mounted || payload.isEmpty) {
        return;
      }

      final code = payload["code"]?.toString() ?? "ERROR";
      final message = payload["message"]?.toString() ?? "Unknown hub error.";
      setState(() {
        _loading = false;
        _message = "$code: $message";
      });
    });
  }

  Future<void> _onDealDrawPressed() async {
    FocusScope.of(context).unfocus();
    if (_loading) {
      return;
    }

    if (_hasOpenHand) {
      await _draw();
    } else {
      await _deal();
    }
  }

  Future<void> _deal() async {
    final betAmount = double.tryParse(_betController.text.trim()) ?? 5000;

    setState(() {
      _loading = true;
      _message = "Dealing cards...";
      _dealResult = null;
      _drawResult = null;
      _holds.clear();
    });

    if (_hubReady) {
      try {
        await _hubClient.invoke(
          "Deal",
          args: <Object>[widget.machineId, betAmount],
        );
        return;
      } catch (_) {
        if (mounted) {
          setState(() {
            _hubReady = false;
            _message = "Realtime deal failed. Switching to HTTP fallback...";
          });
        }
      }
    }

    try {
      final result = await widget.gameApi.deal(
        accessToken: widget.accessToken,
        machineId: widget.machineId,
        betAmount: betAmount,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dealResult = result;
        _walletBalance = result.walletBalanceAfterBet;
        _loading = false;
        _message = "Choose the cards to HOLD, then press DRAW.";
      });
      unawaited(_restoreRealtimeSession());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _message = _friendlyError(error);
      });
    }
  }

  Future<void> _draw() async {
    final deal = _dealResult;
    if (deal == null) {
      return;
    }

    final holdIndexes = _holds.toList()..sort();

    setState(() {
      _loading = true;
      _message = "Drawing final cards...";
    });

    if (_hubReady) {
      try {
        await _hubClient.invoke(
          "Draw",
          args: <Object>[deal.roundId, holdIndexes],
        );
        return;
      } catch (_) {
        if (mounted) {
          setState(() {
            _hubReady = false;
            _message = "Realtime draw failed. Switching to HTTP fallback...";
          });
        }
      }
    }

    try {
      final result = await widget.gameApi.draw(
        accessToken: widget.accessToken,
        roundId: deal.roundId,
        holdIndexes: holdIndexes,
      );

      if (!mounted) {
        return;
      }

      // Check for straight to update Kent counter
      _updateKentCounter(result.handRank);

      setState(() {
        _drawResult = result;
        _walletBalance = result.walletBalanceAfterRound;
        _loading = false;
        _message = result.winAmount > 0
            ? result.doubleUpAvailable
                ? "${result.handRank} pays ${result.winAmount.toStringAsFixed(0)} credits. Double-up is available on supported cabinets."
                : "${result.handRank} pays ${result.winAmount.toStringAsFixed(0)} credits. Cash out to continue."
            : "No win this hand.";
      });
      unawaited(_restoreRealtimeSession());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _message = _friendlyError(error);
      });
    }
  }

  void _updateKentCounter(String handRank) {
    if (handRank.contains("STRAIGHT")) {
      setState(() {
        _kentCounter++;
        if (_kentCounter >= 3) {
          _message = "SERIE KENT JACKPOT! 3 consecutive straights!";
          _kentCounter = 0; // Reset after jackpot
        }
      });
    } else {
      setState(() {
        _kentCounter = 0; // Reset on non-straight hand
      });
    }
  }

  void _toggleHold(int index) {
    if (!_hasOpenHand || _loading) {
      return;
    }

    setState(() {
      if (_holds.contains(index)) {
        _holds.remove(index);
        _heldCardsData.remove(index);
      } else {
        _holds.add(index);
        // Store the actual card data when holding
        final currentCards = _dealResult?.cards ?? [];
        if (index < currentCards.length) {
          _heldCardsData[index] = currentCards[index];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = _visibleCards;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1419),
              Color(0xFF0A0A0D),
              Color(0xFF050507),
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _ScoreboardPanel(
                machineId: widget.machineId,
                walletBalance: _walletBalance,
                currentBetText: _betController.text.trim().isEmpty
                    ? "0"
                    : _betController.text.trim(),
                isLive: _hubReady,
                snapshot: _machineSnapshot,
                kentCounter: _kentCounter,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1D23),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF8B7355),
                            width: 2,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: Color(0x99000000),
                              blurRadius: 32,
                              offset: Offset(0, 16),
                            ),
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withOpacity(0.1),
                              blurRadius: 64,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              "LUCKY 5",
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFFD4AF37),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                fontSize: 28,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFD4AF37).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _drawResult?.handRank ??
                                  (_hasOpenHand ? "SELECT HOLDS" : "READY"),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: const Color(0xFFF0F0F0),
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(1, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: List.generate(cards.length, (index) {
                                  final card = cards[index];
                                  final held = _holds.contains(index);
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right:
                                            index == cards.length - 1 ? 0 : 6,
                                      ),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child:
                                                _buildOptimizedCard(card, held),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton(
                                              onPressed: !_hasOpenHand ||
                                                      _loading
                                                  ? null
                                                  : () => _toggleHold(index),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: held
                                                    ? const Color(0xFFD4AF37)
                                                    : const Color(0xFF3A3228),
                                                foregroundColor: held
                                                    ? const Color(0xFF1A1A1A)
                                                    : const Color(0xFFD4AF37),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                elevation: held ? 8 : 4,
                                                shadowColor: held 
                                                    ? const Color(0xFFD4AF37)
                                                    : Colors.black,
                                              ),
                                              child: Text(
                                                held ? "HELD" : "HOLD",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.2,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                      decoration: const BoxDecoration(
                        color: Color(0xFF7A5C3A),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 24,
                            offset: Offset(0, -8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _betController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "BET",
                                    labelStyle: const TextStyle(
                                      color: Color(0xFFF4D58A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF372317),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 58,
                                  child: FilledButton(
                                    onPressed:
                                        _loading ? null : _onDealDrawPressed,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFC62828),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 6,
                                      shadowColor: const Color(0xFFC62828),
                                      textStyle:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.5,
                                        fontSize: 16,
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(_dealDrawLabel),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniReadout(
                                  label: "ACTIVE",
                                  value:
                                      "${_machineSnapshot?.activeRounds ?? 0}",
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MiniReadout(
                                  label: "PHASE",
                                  value: _machineSnapshot?.phase ?? "-",
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MiniReadout(
                                  label: "RTP",
                                  value: _machineSnapshot == null
                                      ? "-"
                                      : _machineSnapshot!.observedRtpLabel,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A1F15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFFF5E6D3),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 2,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PokerCard?> get _visibleCards {
    final current = _drawResult?.cards ?? _dealResult?.cards ?? const <PokerCard>[];
    
    // If we have a draw result, reorganize cards so held cards appear first
    if (_drawResult != null && _holds.isNotEmpty) {
      final heldCards = <PokerCard?>[];
      final newCards = <PokerCard?>[];
      
      // Use stored held card data instead of checking by index
      for (int i = 0; i < 5; i++) {
        if (_heldCardsData.containsKey(i)) {
          heldCards.add(_heldCardsData[i]);
        }
      }
      
      // Add the new cards (non-held positions)
      int newCardIndex = 0;
      for (int i = 0; i < 5; i++) {
        if (!_heldCardsData.containsKey(i)) {
          if (newCardIndex < current.length) {
            newCards.add(current[newCardIndex]);
            newCardIndex++;
          }
        }
      }
      
      // Combine: held cards first, then new cards
      final reorganized = [...heldCards, ...newCards];
      return List<PokerCard?>.generate(
        5,
        (index) => index < reorganized.length ? reorganized[index] : null,
      );
    }
    
    return List<PokerCard?>.generate(
      5,
      (index) => index < current.length ? current[index] : null,
    );
  }

  Map<String, dynamic> _decodePayload(List<Object?>? args) {
    if (args == null || args.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final raw = args.first;
      if (raw is Map<String, dynamic>) {
        return raw;
      }

      if (raw is Map) {
        return raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }

      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }
    } catch (_) {
      return const <String, dynamic>{};
    }

    return const <String, dynamic>{};
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    return text.startsWith("Bad state:")
        ? text.replaceFirst("Bad state:", "").trim()
        : text;
  }
}

class _ScoreboardPanel extends StatelessWidget {
  const _ScoreboardPanel({
    required this.machineId,
    required this.walletBalance,
    required this.currentBetText,
    required this.isLive,
    required this.snapshot,
    required this.kentCounter,
  });

  final int machineId;
  final double walletBalance;
  final String currentBetText;
  final bool isLive;
  final _MachineSnapshot? snapshot;
  final int kentCounter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D23),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "MACHINE $machineId",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isLive
                      ? const Color(0xFF1A5C3A)
                      : const Color(0xFF5C2A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isLive ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  isLive ? "LIVE" : "HTTP",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReadoutTile(
                  label: "CREDITS",
                  value: walletBalance.toStringAsFixed(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReadoutTile(
                  label: "BET",
                  value: currentBetText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReadoutTile(
                  label: "KENT",
                  value: "$kentCounter/3",
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: _PaytableChip(label: "RF", value: "1000")),
              SizedBox(width: 6),
              Expanded(child: _PaytableChip(label: "SF", value: "75")),
              SizedBox(width: 6),
              Expanded(child: _PaytableChip(label: "4K", value: "15")),
              SizedBox(width: 6),
              Expanded(child: _PaytableChip(label: "FH", value: "12")),
              SizedBox(width: 6),
              Expanded(child: _PaytableChip(label: "FL", value: "10")),
            ],
          ),
        ],
      ),
    );
  }
}

class _CabinetCard extends StatelessWidget {
  const _CabinetCard({
    required this.card,
    required this.held,
  });

  final PokerCard? card;
  final bool held;

  @override
  Widget build(BuildContext context) {
    final suit = _cardSuitSymbol(card?.suit);
    final redSuit = card != null && (card!.suit == "H" || card!.suit == "D");

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Main shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          // Subtle glow for held cards
          if (held)
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: card == null ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: held ? const Color(0xFFD4AF37) : const Color(0xFFB8A868),
            width: held ? 4 : 2,
          ),
          // Inner shadow effect
          boxShadow: [
            if (card != null)
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: card == null
          ? const Center(
              child: Text(
                "?",
                style: TextStyle(
                  color: Color(0xFF7081A8),
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card!.rank,
                        style: TextStyle(
                          color: redSuit ? const Color(0xFFCC0000) : Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(1, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        suit,
                        style: TextStyle(
                          color: redSuit ? const Color(0xFFCC0000) : Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(1, 1),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    suit,
                    style: TextStyle(
                      color: redSuit ? const Color(0xFFE60000) : const Color(0xFF1A1A1A),
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.15),
                          offset: const Offset(2, 2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                if (held)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        "HELD",
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  static String _cardSuitSymbol(String? suit) {
    return switch (suit) {
      "H" => "♥",
      "D" => "♦",
      "C" => "♣",
      _ => "♠",
    };
  }
}

class _ReadoutTile extends StatelessWidget {
  const _ReadoutTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090A0D),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFAEA46D),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF8F1D1),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniReadout extends StatelessWidget {
  const _MiniReadout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1A12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC3A97C),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaytableChip extends StatelessWidget {
  const _PaytableChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF221D12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4120)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD761),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MachineSnapshot {
  const _MachineSnapshot({
    required this.machineId,
    required this.activeRounds,
    required this.observedRtp,
    required this.targetRtp,
    required this.phase,
  });

  final int machineId;
  final int activeRounds;
  final double observedRtp;
  final double targetRtp;
  final String phase;

  String get observedRtpLabel => "${(observedRtp * 100).toStringAsFixed(1)}%";
  String get targetRtpLabel => "${(targetRtp * 100).toStringAsFixed(1)}%";

  factory _MachineSnapshot.fromJson(Map<String, dynamic> json) {
    return _MachineSnapshot(
      machineId: (json["machineId"] as num?)?.toInt() ?? 0,
      activeRounds: (json["activeRounds"] as num?)?.toInt() ?? 0,
      observedRtp: (json["observedRtp"] as num?)?.toDouble() ?? 0,
      targetRtp: (json["targetRtp"] as num?)?.toDouble() ?? 0.9,
      phase: json["phase"]?.toString() ?? "Neutral",
    );
  }
}

void unawaited(Future<void> future) {
  // Intentionally unawaited
}
