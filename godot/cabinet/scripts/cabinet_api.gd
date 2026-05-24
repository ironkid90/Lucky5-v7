extends Node
class_name CabinetApi

signal request_completed(kind: String, ok: bool, body: Variant, status_code: int, error_message: String)

var api_base_url := "http://127.0.0.1:8080"
var access_token := ""
var _http: HTTPRequest
var _pending_kind := ""

func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = 15.0
    add_child(_http)
    _http.request_completed.connect(_on_request_completed)

func configure(base_url: String, token: String) -> void:
    api_base_url = base_url.strip_edges()
    while api_base_url.ends_with("/"):
        api_base_url = api_base_url.substr(0, api_base_url.length() - 1)
    if api_base_url.is_empty():
        api_base_url = "http://127.0.0.1:8080"
    access_token = token.strip_edges()

func get_snapshot(machine_id: int) -> bool:
    return _request("snapshot", HTTPClient.METHOD_GET, "/api/Game/machine/%d/cabinet-snapshot" % machine_id, {})

func post_replay(machine_id: int, last_state_version: int, last_sequence_number: int) -> bool:
    return _request("replay", HTTPClient.METHOD_POST, "/api/Game/machine/%d/cabinet-replay" % machine_id, {
        "last_state_version": last_state_version,
        "last_sequence_number": last_sequence_number
    })

func post_command(command: Dictionary) -> bool:
    return _request("command", HTTPClient.METHOD_POST, "/api/Game/cabinet/command", command)

func _request(kind: String, method: int, path: String, body: Dictionary) -> bool:
    if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        request_completed.emit(kind, false, {}, 0, "HTTP client is busy")
        return false

    _pending_kind = kind
    var headers := ["Accept: application/json"]
    if method != HTTPClient.METHOD_GET:
        headers.append("Content-Type: application/json")
    if not access_token.is_empty():
        headers.append("Authorization: Bearer %s" % access_token)

    var payload := "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
    var error := _http.request(api_base_url + path, headers, method, payload)
    if error != OK:
        request_completed.emit(kind, false, {}, 0, "Could not start HTTP request: %s" % error)
        return false
    return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var kind := _pending_kind
    _pending_kind = ""

    if result != HTTPRequest.RESULT_SUCCESS:
        request_completed.emit(kind, false, {}, response_code, "HTTP transport failed: %s" % result)
        return

    var text := body.get_string_from_utf8()
    var parsed = JSON.parse_string(text)
    if parsed == null and not text.strip_edges().is_empty():
        request_completed.emit(kind, false, {}, response_code, "Backend returned non-JSON response")
        return

    var ok := response_code >= 200 and response_code < 300
    request_completed.emit(kind, ok, parsed if parsed != null else {}, response_code, "HTTP %s" % response_code)
