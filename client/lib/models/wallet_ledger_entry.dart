class WalletLedgerEntry {
  WalletLedgerEntry({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.reference,
    required this.createdUtc,
  });

  final String id;
  final double amount;
  final double balanceAfter;
  final String type;
  final String reference;
  final DateTime createdUtc;

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: json["id"] as String? ?? "",
      amount: (json["amount"] as num).toDouble(),
      balanceAfter: (json["balanceAfter"] as num).toDouble(),
      type: json["type"] as String? ?? "",
      reference: json["reference"] as String? ?? "",
      createdUtc: DateTime.tryParse(json["createdUtc"] as String? ?? "") ??
          DateTime.utc(1970),
    );
  }
}
