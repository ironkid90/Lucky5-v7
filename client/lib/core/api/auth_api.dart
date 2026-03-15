import "../../models/api_response.dart";
import "../../models/auth_tokens.dart";
import "../../models/member_profile.dart";
import "../../models/wallet_ledger_entry.dart";
import "../network/api_client.dart";

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<(AuthTokens tokens, MemberProfile profile)> login({
    required String username,
    required String password,
  }) async {
    final json = await _client.post(
      "/api/Auth/login",
      body: {"username": username, "password": password},
    );
    final envelope = ApiResponse.fromJson(json, (raw) => raw as Map<String, dynamic>);
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }

    final payload = envelope.data!;
    return (
      tokens: AuthTokens.fromJson(payload["tokens"] as Map<String, dynamic>),
      profile: MemberProfile.fromJson(payload["profile"] as Map<String, dynamic>)
    );
  }

  Future<void> signup({
    required String username,
    required String password,
    required String phoneNumber,
  }) async {
    final json = await _client.post(
      "/api/Auth/signup",
      body: {
        "username": username,
        "password": password,
        "phoneNumber": phoneNumber,
      },
    );
    final envelope = ApiResponse.fromJson(json, (raw) => raw);
    if (!envelope.success) {
      throw StateError(envelope.message);
    }
  }

  Future<void> verifyOtp({
    required String username,
    required String otpCode,
  }) async {
    final json = await _client.post(
      "/api/Auth/verify-otp",
      body: {"username": username, "otpCode": otpCode},
    );
    final envelope = ApiResponse.fromJson(json, (raw) => raw);
    if (!envelope.success) {
      throw StateError(envelope.message);
    }
  }

  Future<List<Map<String, dynamic>>> memberHistory(String accessToken) async {
    final json = await _client.get(
      "/api/Auth/MemberHistory",
      accessToken: accessToken,
    );
    final envelope = ApiResponse.fromJson(json, (raw) => raw);
    if (!envelope.success) {
      throw StateError(envelope.message);
    }

    final list = (envelope.data as List<dynamic>? ?? const [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    return list;
  }

  Future<WalletLedgerEntry> transferBalance({
    required String accessToken,
    required double amount,
    required String reference,
    required String direction,
  }) async {
    final json = await _client.post(
      "/api/Auth/TransferBalance",
      accessToken: accessToken,
      body: {"amount": amount, "reference": reference, "direction": direction},
    );
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => WalletLedgerEntry.fromJson(raw as Map<String, dynamic>),
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<WalletLedgerEntry> moveWinToBalance({
    required String accessToken,
    required double amount,
    required String reference,
  }) async {
    final json = await _client.post(
      "/api/Auth/MoveWinToBalance",
      accessToken: accessToken,
      // direction is always "credit" for win-to-balance transfers.
      body: {"amount": amount, "reference": reference, "direction": "credit"},
    );
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => WalletLedgerEntry.fromJson(raw as Map<String, dynamic>),
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<WalletLedgerEntry> updateCredit({
    required String accessToken,
    required double amount,
    required String reference,
    required String direction,
  }) async {
    final json = await _client.post(
      "/api/Auth/UpdateCredit",
      accessToken: accessToken,
      body: {"amount": amount, "reference": reference, "direction": direction},
    );
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => WalletLedgerEntry.fromJson(raw as Map<String, dynamic>),
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<void> logout(String accessToken) async {
    final json = await _client.post(
      "/api/Auth/logout",
      accessToken: accessToken,
    );
    final envelope = ApiResponse.fromJson(json, (raw) => raw);
    if (!envelope.success) {
      throw StateError(envelope.message);
    }
  }
}
