import "../../models/api_response.dart";
import "../network/api_client.dart";

class GeneralApi {
  GeneralApi(this._client);

  final ApiClient _client;

  Future<Map<String, String>> appSettings() async {
    final json = await _client.get("/api/General/app-settings");
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => (raw as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<String> termsBody() async {
    final json = await _client.get("/api/General/terms");
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => (raw as Map<String, dynamic>)["bodyMarkdown"]?.toString() ?? "",
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<Map<String, String>> contactInfo() async {
    final json = await _client.get("/api/General/contact-info");
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => (raw as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<List<Map<String, dynamic>>> contactTypes() async {
    final json = await _client.get("/api/General/contact-types");
    final envelope = ApiResponse.fromJson(
      json,
      (raw) => ((raw as List<dynamic>?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
    if (!envelope.success || envelope.data == null) {
      throw StateError(envelope.message);
    }
    return envelope.data!;
  }

  Future<void> submitContactReport({
    required String accessToken,
    required int contactTypeId,
    required String subject,
    required String message,
  }) async {
    final json = await _client.post(
      "/api/General/contact-report",
      accessToken: accessToken,
      body: {
        "contactTypeId": contactTypeId,
        "subject": subject,
        "message": message,
      },
    );
    final envelope = ApiResponse.fromJson(json, (raw) => raw);
    if (!envelope.success) {
      throw StateError(envelope.message);
    }
  }
}
