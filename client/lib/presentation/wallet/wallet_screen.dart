import "package:flutter/material.dart";

import "../../core/api/auth_api.dart";

class WalletScreenArgs {
  WalletScreenArgs({required this.accessToken});

  final String accessToken;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.authApi,
    required this.accessToken,
  });

  final AuthApi authApi;
  final String accessToken;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  String _message = "";
  List<Map<String, dynamic>> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _message = "";
    });
    try {
      final history = await widget.authApi.memberHistory(widget.accessToken);
      setState(() => _history = history);
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // TODO(wallet): expose a cashout / win-to-balance flow using authApi.moveWinToBalance
  // once the wallet UI panel is fleshed out.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181C),
        foregroundColor: const Color(0xFFF2D05C),
        title: Text(
          "WALLET",
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFF2D05C),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message,
                        style: TextStyle(
                            color: theme.colorScheme.error),
                      ),
                    ),
                  if (_history.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Text(
                          "No transactions yet.",
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    )
                  else
                    ..._history.map(
                      (entry) => _LedgerTile(entry: entry),
                    ),
                ],
              ),
            ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final amount = (entry["amount"] as num?)?.toDouble() ?? 0;
    final type = entry["type"]?.toString() ?? "";
    final reference = entry["reference"]?.toString() ?? "";
    final balanceAfter = (entry["balanceAfter"] as num?)?.toDouble() ?? 0;
    final isCredit = amount >= 0;

    return Card(
      color: const Color(0xFF17181C),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          type,
          style: const TextStyle(
            color: Color(0xFFF0F0F0),
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          reference,
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${isCredit ? "+" : ""}${amount.toStringAsFixed(0)}",
              style: TextStyle(
                color:
                    isCredit ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              "Bal: ${balanceAfter.toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
