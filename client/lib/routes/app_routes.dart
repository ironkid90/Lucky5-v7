import "package:flutter/material.dart";

import "../core/api/auth_api.dart";
import "../core/api/game_api.dart";
import "../core/api/general_api.dart";
import "../presentation/account_settings/account_settings_screen.dart";
import "../presentation/cashier/cashier_screen.dart";
import "../presentation/game/poker_game_screen.dart";
import "../presentation/history/history_screen.dart";
import "../presentation/login/login_screen.dart";
import "../presentation/machine/machine_selection_screen.dart";
import "../presentation/offers/offers_screen.dart";
import "../presentation/support/support_screen.dart";
import "../presentation/wallet/wallet_screen.dart";

class AppRoutes {
  static const login = "/";
  static const machines = "/machines";
  static const game = "/game";
  static const wallet = "/wallet";
  static const cashier = "/cashier";
  static const history = "/history";
  static const support = "/support";
  static const accountSettings = "/account-settings";
  static const offers = "/offers";

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings, {
    required AuthApi authApi,
    required GameApi gameApi,
    required GeneralApi generalApi,
  }) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute<void>(
          builder: (_) => LoginScreen(authApi: authApi),
        );
      case machines:
        final args = settings.arguments as MachineSelectionArgs;
        return MaterialPageRoute<void>(
          builder: (_) => MachineSelectionScreen(
            gameApi: gameApi,
            accessToken: args.accessToken,
          ),
        );
      case game:
        final args = settings.arguments as PokerGameArgs;
        return MaterialPageRoute<void>(
          builder: (_) => PokerGameScreen(
            gameApi: gameApi,
            accessToken: args.accessToken,
            machineId: args.machineId,
          ),
        );
      case wallet:
        final args = settings.arguments as WalletScreenArgs;
        return MaterialPageRoute<void>(
          builder: (_) => WalletScreen(
            authApi: authApi,
            accessToken: args.accessToken,
          ),
        );
      case cashier:
        final args = settings.arguments as CashierScreenArgs;
        return MaterialPageRoute<void>(
          builder: (_) => CashierScreen(
            authApi: authApi,
            accessToken: args.accessToken,
          ),
        );
      case history:
        final args = settings.arguments as HistoryScreenArgs;
        return MaterialPageRoute<void>(
          builder: (_) => HistoryScreen(
            authApi: authApi,
            accessToken: args.accessToken,
          ),
        );
      case support:
        final args = settings.arguments as SupportScreenArgs;
        return MaterialPageRoute<void>(
          builder: (_) => SupportScreen(
            generalApi: generalApi,
            accessToken: args.accessToken,
          ),
        );
      case accountSettings:
        final args = settings.arguments as AccountSettingsScreenArgs;
        return MaterialPageRoute<void>(
          builder: (_) => AccountSettingsScreen(
            accessToken: args.accessToken,
          ),
        );
      case offers:
        final args = settings.arguments as OffersScreenArgs;
        return MaterialPageRoute<void>(
          builder: (_) => OffersScreen(
            accessToken: args.accessToken,
          ),
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Center(child: Text("Unknown route: ${settings.name}")),
          ),
        );
    }
  }
}
