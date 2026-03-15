import "package:flutter/material.dart";

import "../../core/api/game_api.dart";
import "../../models/machine_listing.dart";
import "../../routes/app_routes.dart";
import "../account_settings/account_settings_screen.dart";
import "../cashier/cashier_screen.dart";
import "../game/poker_game_screen.dart";
import "../history/history_screen.dart";
import "../offers/offers_screen.dart";
import "../wallet/wallet_screen.dart";

class MachineSelectionArgs {
  MachineSelectionArgs({required this.accessToken});

  final String accessToken;
}

class MachineSelectionScreen extends StatefulWidget {
  const MachineSelectionScreen({
    super.key,
    required this.gameApi,
    required this.accessToken,
  });

  final GameApi gameApi;
  final String accessToken;

  @override
  State<MachineSelectionScreen> createState() => _MachineSelectionScreenState();
}

class _MachineSelectionScreenState extends State<MachineSelectionScreen> {
  bool _loading = true;
  String _message = "";
  List<MachineListing> _machines = const [];

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  Future<void> _loadMachines() async {
    setState(() {
      _loading = true;
      _message = "";
    });
    try {
      final machines = await widget.gameApi.listMachines(widget.accessToken);
      setState(() => _machines = machines);
    } catch (e) {
      setState(() => _message = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _navigate(String route, Object args) {
    Navigator.of(context).pushNamed(route, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF17181C),
        foregroundColor: const Color(0xFFF2D05C),
        title: Text(
          "SELECT MACHINE",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFFF2D05C),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
        ),
      ),
      drawer: _AppDrawer(
        accessToken: widget.accessToken,
        onNavigate: _navigate,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMachines,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_message.isNotEmpty)
                    Text(
                      _message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ..._machines.map(
                    (machine) => Card(
                      color: const Color(0xFF17181C),
                      child: ListTile(
                        title: Text(
                          machine.name,
                          style: const TextStyle(
                            color: Color(0xFFF0F0F0),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          "Bet ${machine.minBet.toStringAsFixed(0)} – ${machine.maxBet.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: machine.isOpen
                                ? const Color(0xFF0F5A31)
                                : const Color(0xFF5A2A1A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            machine.isOpen ? "OPEN" : "CLOSED",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        onTap: machine.isOpen
                            ? () {
                                Navigator.of(context).pushNamed(
                                  AppRoutes.game,
                                  arguments: PokerGameArgs(
                                    accessToken: widget.accessToken,
                                    machineId: machine.id,
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({
    required this.accessToken,
    required this.onNavigate,
  });

  final String accessToken;
  final void Function(String route, Object args) onNavigate;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF17181C),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF0B6E4F)),
            child: Text(
              "LUCKY 5",
              style: TextStyle(
                color: Color(0xFFF2D05C),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          _DrawerItem(
            icon: Icons.account_balance_wallet_outlined,
            label: "Wallet",
            onTap: () {
              Navigator.pop(context);
              onNavigate(
                AppRoutes.wallet,
                WalletScreenArgs(accessToken: accessToken),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.point_of_sale_outlined,
            label: "Cashier",
            onTap: () {
              Navigator.pop(context);
              onNavigate(
                AppRoutes.cashier,
                CashierScreenArgs(accessToken: accessToken),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.history,
            label: "History",
            onTap: () {
              Navigator.pop(context);
              onNavigate(
                AppRoutes.history,
                HistoryScreenArgs(accessToken: accessToken),
              );
            },
          ),
          _DrawerItem(
            icon: Icons.local_offer_outlined,
            label: "Offers",
            onTap: () {
              Navigator.pop(context);
              onNavigate(
                AppRoutes.offers,
                OffersScreenArgs(accessToken: accessToken),
              );
            },
          ),
          const Divider(color: Color(0xFF2E2E2E)),
          _DrawerItem(
            icon: Icons.settings_outlined,
            label: "Account Settings",
            onTap: () {
              Navigator.pop(context);
              onNavigate(
                AppRoutes.accountSettings,
                AccountSettingsScreenArgs(accessToken: accessToken),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFF2D05C)),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFF0F0F0),
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
