import "package:flutter/material.dart";

class OffersScreenArgs {
  OffersScreenArgs({required this.accessToken});

  final String accessToken;
}

class OffersScreen extends StatelessWidget {
  const OffersScreen({
    super.key,
    required this.accessToken,
  });

  final String accessToken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181C),
        foregroundColor: const Color(0xFFF2D05C),
        title: Text(
          "OFFERS",
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFFF2D05C),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
      body: const ListView(
        padding: EdgeInsets.all(16),
        children: [
          _PromoCard(
            title: "Welcome Bonus",
            description:
                "Top up your machine credits and get started with Lucky5.",
            tag: "NEW",
          ),
          SizedBox(height: 8),
          _PromoCard(
            title: "Double-Up Streak",
            description:
                "Win big with consecutive double-ups on any machine.",
            tag: "HOT",
          ),
          SizedBox(height: 8),
          _PromoCard(
            title: "Lucky 5 Jackpot",
            description:
                "Draw the 5\u2660 to activate the no-lose Lucky5 mode.",
            tag: "JACKPOT",
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.title,
    required this.description,
    required this.tag,
  });

  final String title;
  final String description;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17181C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF655E34), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF2D05C),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0B6E4F),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
