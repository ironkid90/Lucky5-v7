import "package:flutter/material.dart";

import "../../core/api/auth_api.dart";

class CashierScreenArgs {
  CashierScreenArgs({required this.accessToken});

  final String accessToken;
}

class CashierScreen extends StatefulWidget {
  const CashierScreen({
    super.key,
    required this.authApi,
    required this.accessToken,
  });

  final AuthApi authApi;
  final String accessToken;

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _amountController = TextEditingController();
  bool _loading = false;
  String _message = "";

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _deposit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _message = "Enter a valid amount.");
      return;
    }
    setState(() {
      _loading = true;
      _message = "";
    });
    try {
      await widget.authApi.deposit(
        accessToken: widget.accessToken,
        amount: amount,
        reference: "cashier-deposit",
      );
      setState(() => _message = "Deposit successful.");
      _amountController.clear();
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withdraw() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _message = "Enter a valid amount.");
      return;
    }
    setState(() {
      _loading = true;
      _message = "";
    });
    try {
      await widget.authApi.withdraw(
        accessToken: widget.accessToken,
        amount: amount,
        reference: "cashier-withdrawal",
      );
      setState(() => _message = "Withdrawal successful.");
      _amountController.clear();
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181C),
        foregroundColor: const Color(0xFFF2D05C),
        title: Text(
          "CASHIER",
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFF2D05C),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Amount",
                labelStyle: const TextStyle(color: Color(0xFFF4D58A)),
                filled: true,
                fillColor: const Color(0xFF17181C),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message,
                  style: TextStyle(color: theme.colorScheme.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _deposit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B6B37),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("DEPOSIT"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _withdraw,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B2A22),
                    ),
                    child: const Text("WITHDRAW"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
