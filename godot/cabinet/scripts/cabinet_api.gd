extends Node
class_name CabinetApi

signal request_completed(kind: String, ok: bool, body: Variant, status_code: int, error_message: String)

var api_base_url := "http://127.0.0.1:8080"
var access_token := ""
var _http: HTTPRequest
var _pending_kind: String = ""

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

func set_access_token(token: String) -> void:
    access_token = token.strip_edges()

func login(username: String, password: String) -> bool:
    return _request("login", HTTPClient.METHOD_POST, "/api/Auth/login", {
        "username": username.strip_edges(),
        "password": password
    })

func signup(username: String, password: String, phone_number: String) -> bool:
    return _request("signup", HTTPClient.METHOD_POST, "/api/Auth/signup", {
        "username": username.strip_edges(),
        "password": password,
        "phoneNumber": phone_number.strip_edges()
    })

func verify_otp(username: String, otp_code: String) -> bool:
    return _request("verify_otp", HTTPClient.METHOD_POST, "/api/Auth/verify-otp", {
        "username": username.strip_edges(),
        "otpCode": otp_code.strip_edges()
    })

func logout() -> bool:
    return _request("logout", HTTPClient.METHOD_POST, "/api/Auth/logout", {})

func get_snapshot(machine_id: int) -> bool:
    return _request("snapshot", HTTPClient.METHOD_GET, "/api/Game/machine/%d/cabinet-snapshot" % machine_id, {})

func post_login(username: String, password: String) -> bool:
    return _request("login", HTTPClient.METHOD_POST, "/api/Auth/login", {
        "username": username,
        "password": password
    })

func post_replay(machine_id: int, last_state_version: int, last_sequence_number: int) -> bool:
    return _request("replay", HTTPClient.METHOD_POST, "/api/Game/machine/%d/cabinet-replay" % machine_id, {
        "last_state_version": last_state_version,
        "last_sequence_number": last_sequence_number
    })

func post_command(command: Dictionary) -> bool:
    return _request("command", HTTPClient.METHOD_POST, "/api/Game/cabinet/command", command)

func post_refresh_token(refresh_token_val: String) -> bool:
    return _request("refresh_token", HTTPClient.METHOD_POST, "/api/Auth/refresh-token", {
        "refreshToken": refresh_token_val.strip_edges()
    })

func get_admin_users() -> bool:
    return _request_get("admin_users", "/api/Admin/users")

func get_admin_dashboard() -> bool:
    return _request_get("admin_dashboard", "/api/Admin/dashboard")

func search_admin_users(query: String) -> bool:
    return _request_get("admin_users_search", "/api/Admin/users/search?q=%s" % query.uri_encode())

func get_admin_user_detail(user_id: String) -> bool:
    return _request_get("admin_user_detail", "/api/Admin/users/%s/detail" % user_id.uri_encode())

func admin_credit_user(user_id: String, amount: int, reason: String) -> bool:
    return _request("admin_user_credit", HTTPClient.METHOD_POST, "/api/Admin/users/credit", {
        "targetUserId": user_id.strip_edges(),
        "amount": amount,
        "reason": reason.strip_edges()
    })

func admin_recharge_bonus(user_id: String, recharge_amount: int) -> bool:
    return _request("admin_user_recharge_bonus", HTTPClient.METHOD_POST, "/api/Admin/users/recharge-bonus", {
        "userId": user_id.strip_edges(),
        "rechargeAmount": recharge_amount
    })

func get_admin_machines() -> bool:
    return _request_get("admin_machines", "/api/Admin/machines")

func get_admin_machine_detail(machine_id: int) -> bool:
    return _request_get("admin_machine_detail", "/api/Admin/machines/%d/detail" % machine_id)

func reset_admin_machine(machine_id: int) -> bool:
    return _request("admin_machine_reset", HTTPClient.METHOD_POST, "/api/Admin/machines/%d/reset" % machine_id, {})

func set_admin_machine_door_state(machine_id: int, door_state: int) -> bool:
    return _request("admin_machine_door_state", HTTPClient.METHOD_POST, "/api/Admin/machines/%d/door-state" % machine_id, {
        "doorState": door_state
    })

func get_admin_audit(take: int = 25) -> bool:
    return _request_get("admin_audit", "/api/Admin/audit?take=%d" % max(1, take))

func get_cabinet_devices() -> bool:
    return _request_get("admin_cabinet_devices", "/api/Admin/cabinet-devices")

func provision_cabinet_device(machine_id: int, display_name: String, serial_number: String) -> bool:
    return _request("admin_cabinet_device_provision", HTTPClient.METHOD_POST, "/api/Admin/cabinet-devices", {
        "machineId": machine_id,
        "displayName": display_name.strip_edges(),
        "serialNumber": serial_number.strip_edges()
    })

func revoke_cabinet_device(device_id: String, reason: String) -> bool:
    return _request("admin_cabinet_device_revoke", HTTPClient.METHOD_POST, "/api/Admin/cabinet-devices/%s/revoke" % device_id.uri_encode(), {
        "reason": reason.strip_edges()
    })

func get_admin_agents() -> bool:
    return _request_get("admin_agents", "/api/Agent")

func create_admin_agent(name: String, code: String, phone_number: String) -> bool:
    return _request("admin_agent_create", HTTPClient.METHOD_POST, "/api/Agent", {
        "name": name.strip_edges(),
        "code": code.strip_edges().to_upper(),
        "phoneNumber": phone_number.strip_edges()
    })

func load_admin_agent_credit(agent_id: int, amount: int) -> bool:
    return _request("admin_agent_load_credit", HTTPClient.METHOD_POST, "/api/Agent/%d/load-credit" % agent_id, {
        "amount": amount
    })

func assign_admin_user_to_agent(agent_id: int, user_id: String) -> bool:
    return _request("admin_agent_assign_user", HTTPClient.METHOD_POST, "/api/Agent/%d/assign-user/%s" % [agent_id, user_id.uri_encode()], {})

func _request(kind: String, method: int, path: String, body: Dictionary) -> bool:
    var headers := PackedStringArray(["Accept: application/json"])
    if method != HTTPClient.METHOD_GET:
        headers.append("Content-Type: application/json")
    if not access_token.is_empty():
        headers.append("Authorization: Bearer %s" % access_token)

    var payload: String = "" if method == HTTPClient.METHOD_GET else JSON.stringify(body)
    return _do_request(kind, method, path, payload, headers)

func _request_get(kind: String, path: String) -> bool:
    var headers := PackedStringArray(["Accept: application/json"])
    if not access_token.is_empty():
        headers.append("Authorization: Bearer %s" % access_token)
    return _do_request(kind, HTTPClient.METHOD_GET, path, "", headers)

func _do_request(kind: String, method: int, path: String, payload: String, headers: PackedStringArray) -> bool:
    if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
        request_completed.emit(kind, false, {}, 0, "HTTP client is busy")
        return false

    _pending_kind = kind
    var error: int = _http.request(api_base_url + path, headers, method, payload)
    if error != OK:
        request_completed.emit(kind, false, {}, 0, "Could not start HTTP request: %s" % error)
        return false
    return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var kind: String = _pending_kind
    _pending_kind = ""

    if result != HTTPRequest.RESULT_SUCCESS:
        request_completed.emit(kind, false, {}, response_code, "HTTP transport failed: %s" % result)
        return

    var text: String = body.get_string_from_utf8()
    var parsed: Variant = JSON.parse_string(text)
    if parsed == null and not text.strip_edges().is_empty():
        request_completed.emit(kind, false, {}, response_code, "Backend returned non-JSON response")
        return

    var ok: bool = response_code >= 200 and response_code < 300
    request_completed.emit(kind, ok, parsed if parsed != null else {}, response_code, "HTTP %s" % response_code)
