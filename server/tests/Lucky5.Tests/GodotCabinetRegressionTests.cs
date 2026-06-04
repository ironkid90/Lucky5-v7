namespace Lucky5.Tests;

public static class GodotCabinetRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        string project;
        string exportPresets;
        string mainScene;
        string rootScript;
        string storeScript;
        string apiScript;
        string cabinetContracts;
        string gameService;
        string cardSkinScript;
        string devScript;
        string webExportScript;
        string webLayout;
        string webManifest;
        string webIcon;
        string webGodotRoute;
        string webPackageJson;
        string gitIgnore;
        try
        {
            project = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "project.godot"));
            exportPresets = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "export_presets.cfg"));
            mainScene = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scenes", "CabinetRoot.tscn"));
            rootScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_root.gd"));
            storeScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_store.gd"));
            apiScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_api.gd"));
            cabinetContracts = await File.ReadAllTextAsync(ResolveRepoFilePath("server", "src", "Lucky5.Application", "Dtos", "CabinetContractsDto.cs"));
            gameService = await File.ReadAllTextAsync(ResolveRepoFilePath("server", "src", "Lucky5.Infrastructure", "Services", "GameService.cs"));
            cardSkinScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "skins", "lucky5", "CardSkin_Lucky5.gd"));
            devScript = await File.ReadAllTextAsync(ResolveRepoFilePath("dev.ps1"));
            webExportScript = await File.ReadAllTextAsync(ResolveRepoFilePath("scripts", "godot", "Export-GodotWebCabinet.ps1"));
            webLayout = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "app", "layout.tsx"));
            webManifest = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "app", "manifest.ts"));
            webIcon = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "public", "icon.svg"));
            webGodotRoute = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "app", "godot", "page.tsx"));
            webPackageJson = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "package.json"));
            gitIgnore = await File.ReadAllTextAsync(ResolveRepoFilePath(".gitignore"));
        }
        catch (Exception ex)
        {
            failures.Add($"Godot cabinet regression setup failed: {ex.Message}");
            return;
        }

        var roundUpdateScript = ExtractBetween(storeScript, "func apply_round_update", "func apply_double_up");

        Assert(
            failures,
            "Godot cabinet project must launch CabinetRoot.tscn as the playable main scene",
            project.Contains("run/main_scene=\"res://scenes/CabinetRoot.tscn\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet project must stay portrait, iconed, and GL Compatibility based so the same 2D client can ship to kiosk, web, and Android lanes",
            project.Contains("config/icon=\"res://icon-512.png\"", StringComparison.Ordinal)
                && project.Contains("config/features=PackedStringArray(\"4.6\", \"GL Compatibility\")", StringComparison.Ordinal)
                && project.Contains("window/size/viewport_width=720", StringComparison.Ordinal)
                && project.Contains("window/size/viewport_height=1280", StringComparison.Ordinal)
                && project.Contains("window/size/window_width_override=540", StringComparison.Ordinal)
                && project.Contains("window/size/window_height_override=960", StringComparison.Ordinal)
                && project.Contains("window/handheld/orientation=1", StringComparison.Ordinal)
                && project.Contains("window/stretch/mode=\"viewport\"", StringComparison.Ordinal)
                && project.Contains("window/stretch/aspect=\"keep\"", StringComparison.Ordinal)
                && project.Contains("renderer/rendering_method=\"gl_compatibility\"", StringComparison.Ordinal)
                && project.Contains("renderer/rendering_method.mobile=\"gl_compatibility\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet export presets must define Windows kiosk, Web PWA, and Android APK lanes for one shared cabinet client",
            exportPresets.Contains("name=\"Windows Desktop\"", StringComparison.Ordinal)
                && exportPresets.Contains("platform=\"Windows Desktop\"", StringComparison.Ordinal)
                && exportPresets.Contains("export_path=\"../../artifacts/godot-kiosk/dev/Lucky5Cabinet.exe\"", StringComparison.Ordinal)
                && exportPresets.Contains("name=\"Web\"", StringComparison.Ordinal)
                && exportPresets.Contains("platform=\"Web\"", StringComparison.Ordinal)
                && exportPresets.Contains("custom_features=\"web\"", StringComparison.Ordinal)
                && exportPresets.Contains("export_path=\"../../artifacts/godot-web/dev/index.html\"", StringComparison.Ordinal)
                && exportPresets.Contains("variant/thread_support=false", StringComparison.Ordinal)
                && exportPresets.Contains("vram_texture_compression/for_mobile=false", StringComparison.Ordinal)
                && exportPresets.Contains("progressive_web_app/enabled=true", StringComparison.Ordinal)
                && exportPresets.Contains("progressive_web_app/display=1", StringComparison.Ordinal)
                && exportPresets.Contains("progressive_web_app/orientation=2", StringComparison.Ordinal)
                && exportPresets.Contains("progressive_web_app/icon_144x144=\"res://icon-144.png\"", StringComparison.Ordinal)
                && exportPresets.Contains("progressive_web_app/icon_180x180=\"res://icon-180.png\"", StringComparison.Ordinal)
                && exportPresets.Contains("progressive_web_app/icon_512x512=\"res://icon-512.png\"", StringComparison.Ordinal)
                && exportPresets.Contains("name=\"Android\"", StringComparison.Ordinal)
                && exportPresets.Contains("platform=\"Android\"", StringComparison.Ordinal)
                && exportPresets.Contains("custom_features=\"android\"", StringComparison.Ordinal)
                && exportPresets.Contains("export_path=\"../../artifacts/godot-android/dev/Lucky5Cabinet.apk\"", StringComparison.Ordinal)
                && exportPresets.Contains("architectures/arm64-v8a=true", StringComparison.Ordinal)
                && exportPresets.Contains("package/unique_name=\"com.lucky5.cabinet\"", StringComparison.Ordinal)
                && exportPresets.Contains("package/name=\"Lucky5 Cabinet\"", StringComparison.Ordinal)
                && exportPresets.Contains("screen/immersive_mode=true", StringComparison.Ordinal)
                && exportPresets.Contains("permissions/internet=true", StringComparison.Ordinal)
                && exportPresets.Contains("permissions/access_network_state=true", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet export presets must exclude editor/plugin addons from every shared package lane",
            CountOccurrences(exportPresets, "exclude_filter=\"addons/*\"") == 3);

        Assert(
            failures,
            "CabinetRoot.tscn must attach cabinet_root.gd so the playable UI, API client, and controls are created on launch",
            mainScene.Contains("path=\"res://scripts/cabinet_root.gd\"", StringComparison.Ordinal)
                && mainScene.Contains("script = ExtResource", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must expose an in-app username/password auth panel instead of requiring LUCKY5_ACCESS_TOKEN injection",
            rootScript.Contains("username_edit", StringComparison.Ordinal)
                && rootScript.Contains("password_edit", StringComparison.Ordinal)
                && rootScript.Contains("_on_login_pressed", StringComparison.Ordinal)
                && rootScript.Contains("_on_signup_pressed", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must auto-login with supplied kiosk credentials on launch so env-configured cabinets do not remain fixture-only",
            rootScript.Contains("var kiosk_auth_configured := false", StringComparison.Ordinal)
                && rootScript.Contains("OS.get_environment(\"LUCKY5_KIOSK_USERNAME\")", StringComparison.Ordinal)
                && rootScript.Contains("OS.get_environment(\"LUCKY5_KIOSK_PASSWORD\")", StringComparison.Ordinal)
                && rootScript.Contains("kiosk_auth_configured = not env_username.is_empty() and not env_password.is_empty()", StringComparison.Ordinal)
                && rootScript.Contains("if kiosk_auth_configured and _has_auth_credentials():", StringComparison.Ordinal)
                && rootScript.Contains("_authenticate_and_sync(\"Kiosk credentials found. Connecting to backend...\")", StringComparison.Ordinal)
                && rootScript.Contains("store.apply_transport_error(\"Log in to play against the local Lucky5 API.\")", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet auth panel must prefill supplied kiosk credentials so visible launches can reconnect without manual typing",
            rootScript.Contains("username_edit.text = auth_username", StringComparison.Ordinal)
                && rootScript.Contains("password_edit.text = auth_password", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet API must support Auth login/signup/OTP verification endpoints for first-class playable bootstrap",
            apiScript.Contains("func login(", StringComparison.Ordinal)
                && apiScript.Contains("/api/Auth/login", StringComparison.Ordinal)
                && apiScript.Contains("func signup(", StringComparison.Ordinal)
                && apiScript.Contains("/api/Auth/signup", StringComparison.Ordinal)
                && apiScript.Contains("func verify_otp(", StringComparison.Ordinal)
                && apiScript.Contains("/api/Auth/verify-otp", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet admin panel must expose agent create/load/assign flows against the backend Agent API",
            apiScript.Contains("func get_admin_agents", StringComparison.Ordinal)
                && apiScript.Contains("func create_admin_agent", StringComparison.Ordinal)
                && apiScript.Contains("func load_admin_agent_credit", StringComparison.Ordinal)
                && apiScript.Contains("func assign_admin_user_to_agent", StringComparison.Ordinal)
                && apiScript.Contains("/api/Agent/%d/load-credit", StringComparison.Ordinal)
                && apiScript.Contains("/api/Agent/%d/assign-user/%s", StringComparison.Ordinal)
                && rootScript.Contains("[\"AGENTS\", _on_admin_agents]", StringComparison.Ordinal)
                && rootScript.Contains("var admin_agent_tools: VBoxContainer", StringComparison.Ordinal)
                && rootScript.Contains("var admin_agents_list: VBoxContainer", StringComparison.Ordinal)
                && rootScript.Contains("var admin_selected_agent_id := 0", StringComparison.Ordinal)
                && rootScript.Contains("api.create_admin_agent(name, code, phone)", StringComparison.Ordinal)
                && rootScript.Contains("api.load_admin_agent_credit(admin_selected_agent_id, amount)", StringComparison.Ordinal)
                && rootScript.Contains("api.assign_admin_user_to_agent(admin_selected_agent_id, user_id.strip_edges())", StringComparison.Ordinal)
                && rootScript.Contains("assign_button.pressed.connect(_on_admin_assign_user.bind", StringComparison.Ordinal));

        Assert(
            failures,
            "dev.ps1 must launch the Godot cabinet by default and keep the legacy web cabinet behind an explicit -Web fallback",
            devScript.Contains("[switch]$Web", StringComparison.Ordinal)
                && devScript.Contains("$launchGodot = -not $Headless -and -not $Web", StringComparison.Ordinal)
                && devScript.Contains("Start-Process -FilePath $GodotBin", StringComparison.Ordinal)
                && devScript.Contains("$env:LUCKY5_AUTH_USERNAME = \"tester\"", StringComparison.Ordinal)
                && devScript.Contains("$env:LUCKY5_AUTH_PASSWORD = \"password\"", StringComparison.Ordinal)
                && devScript.Contains("-Wait", StringComparison.Ordinal)
                && !devScript.Contains("& $GodotBin --path", StringComparison.Ordinal)
                && !devScript.Contains("[switch]$Godot", StringComparison.Ordinal)
                && !devScript.Contains("$Client", StringComparison.Ordinal));

        Assert(
            failures,
            "dev.ps1 must stay ASCII-only so Windows PowerShell can parse the 1-click Godot launcher reliably",
            devScript.All(ch => ch <= 127));

        Assert(
            failures,
            "Web cabinet fallback must expose an installable portrait app shell for the shared web/Android-compatible cabinet path",
            webLayout.Contains("manifest: \"/manifest.webmanifest\"", StringComparison.Ordinal)
                && webLayout.Contains("appleWebApp", StringComparison.Ordinal)
                && webLayout.Contains("\"apple-mobile-web-app-capable\": \"yes\"", StringComparison.Ordinal)
                && webLayout.Contains("statusBarStyle: \"black-translucent\"", StringComparison.Ordinal)
                && webLayout.Contains("formatDetection", StringComparison.Ordinal)
                && webLayout.Contains("themeColor: \"#060606\"", StringComparison.Ordinal)
                && webManifest.Contains("export default function manifest(): MetadataRoute.Manifest", StringComparison.Ordinal)
                && webManifest.Contains("display: \"standalone\"", StringComparison.Ordinal)
                && webManifest.Contains("display_override: [\"fullscreen\", \"standalone\"]", StringComparison.Ordinal)
                && webManifest.Contains("orientation: \"portrait\"", StringComparison.Ordinal)
                && webManifest.Contains("theme_color: \"#060606\"", StringComparison.Ordinal)
                && webManifest.Contains("purpose: \"maskable\"", StringComparison.Ordinal)
                && webIcon.Contains("LUCKY5", StringComparison.Ordinal)
                && webIcon.Contains("CABINET", StringComparison.Ordinal));

        Assert(
            failures,
            "Merged web shell must host the generated Godot cabinet at /godot without committing the heavy export bundle",
            webExportScript.Contains("--export-release", StringComparison.Ordinal)
                && webExportScript.Contains("$PresetName = 'Web'", StringComparison.Ordinal)
                && webExportScript.Contains("$OutputPath = 'src/web/public/godot-cabinet/index.html'", StringComparison.Ordinal)
                && webExportScript.Contains("lucky5.godot_web_export.v1", StringComparison.Ordinal)
                && webExportScript.Contains("entry_url = '/godot'", StringComparison.Ordinal)
                && webExportScript.Contains("asset_url = '/godot-cabinet/index.html'", StringComparison.Ordinal)
                && webGodotRoute.Contains("fs.existsSync(exportPath)", StringComparison.Ordinal)
                && webGodotRoute.Contains("dynamic = \"force-dynamic\"", StringComparison.Ordinal)
                && webGodotRoute.Contains("src=\"/godot-cabinet/index.html\"", StringComparison.Ordinal)
                && webGodotRoute.Contains("className=\"godot-web-frame\"", StringComparison.Ordinal)
                && webGodotRoute.Contains("Godot export missing", StringComparison.Ordinal)
                && webPackageJson.Contains("\"godot:export\"", StringComparison.Ordinal)
                && webPackageJson.Contains("Export-GodotWebCabinet.ps1", StringComparison.Ordinal)
                && gitIgnore.Contains("src/web/public/godot-cabinet/", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet store must normalize legacy v1 snapshots and legacy button IDs at the boundary",
            storeScript.Contains("func _normalize_snapshot", StringComparison.Ordinal)
                && storeScript.Contains("\"schema_version\": \"cabinet.v1\"", StringComparison.Ordinal)
                && storeScript.Contains("\"deal\": \"deal_draw\"", StringComparison.Ordinal)
                && storeScript.Contains("\"cancel\": \"cancel_hold\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must suppress duplicate gameplay commands with a pending command lock and timeout recovery",
            rootScript.Contains("pending_command_id", StringComparison.Ordinal)
                && rootScript.Contains("func _start_action_lock", StringComparison.Ordinal)
                && rootScript.Contains("func _on_command_timeout", StringComparison.Ordinal)
                && rootScript.Contains("store.apply_event", StringComparison.Ordinal)
                && rootScript.Contains("id not in [\"menu\", \"reconnect_sync\", \"logout\", \"admin_toggle\"]", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must reveal dealt cards and drawn replacements through sequential AI9Poker-style arcade card movement",
            rootScript.Contains("func _queue_card_reveal", StringComparison.Ordinal)
                && rootScript.Contains("const DEAL_DURATION := 0.15", StringComparison.Ordinal)
                && rootScript.Contains("const DEAL_STAGGER := 0.15", StringComparison.Ordinal)
                && rootScript.Contains("const DRAW_OUT_DURATION := 0.10", StringComparison.Ordinal)
                && rootScript.Contains("const DRAW_IN_DURATION := 0.15", StringComparison.Ordinal)
                && rootScript.Contains("const DRAW_STAGGER := 0.15", StringComparison.Ordinal)
                && rootScript.Contains("func _show_queued_card", StringComparison.Ordinal)
                && rootScript.Contains("func _queue_card_draw_replacement", StringComparison.Ordinal)
                && rootScript.Contains("func _should_draw_replace_card", StringComparison.Ordinal)
                && rootScript.Contains("func _show_draw_replacement", StringComparison.Ordinal)
                && rootScript.Contains("func _finish_card_draw_replacement", StringComparison.Ordinal)
                && rootScript.Contains("func _animate_card_draw_in", StringComparison.Ordinal)
                && rootScript.Contains("deal_queue.append", StringComparison.Ordinal)
                && rootScript.Contains("\"mode\": \"draw\"", StringComparison.Ordinal)
                && rootScript.Contains("deal_timer.start", StringComparison.Ordinal)
                && rootScript.Contains("_process_deal_queue", StringComparison.Ordinal)
                && rootScript.Contains("var previous_code: String = previous_codes[index] if index < previous_codes.size() else \"\"", StringComparison.Ordinal)
                && rootScript.Contains("_should_draw_replace_card(game_state, previous_code, code, held)", StringComparison.Ordinal)
                && rootScript.Contains("rect.scale = Vector2(0.08, 1.02)", StringComparison.Ordinal)
                && rootScript.Contains("rect.position = base_position", StringComparison.Ordinal)
                && rootScript.Contains("tween_property(rect, \"position\", base_position", StringComparison.Ordinal)
                && rootScript.Contains("tween_property(rect, \"scale\", Vector2(1.04, 1.0)", StringComparison.Ordinal)
                && rootScript.Contains("tween_property(rect, \"scale\", Vector2(1.0, 1.0)", StringComparison.Ordinal)
                && rootScript.Contains("tween_property(rect, \"position\", base_position, DRAW_OUT_DURATION)", StringComparison.Ordinal)
                && rootScript.Contains("tween_callback(Callable(self, \"_finish_card_draw_replacement\").bind", StringComparison.Ordinal)
                && rootScript.Contains("rect.scale = Vector2(0.08, 1.02)", StringComparison.Ordinal)
                && rootScript.Contains("tween_property(rect, \"position\", base_position, DRAW_IN_DURATION)", StringComparison.Ordinal)
                && rootScript.Contains("deal_timer.wait_time = DRAW_STAGGER if str(reveal.get(\"mode\", \"deal\")) == \"draw\" else DEAL_STAGGER", StringComparison.Ordinal)
                && !rootScript.Contains("func _process_deal_queue() -> void: pass", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must apply AI9Poker-style auto-hold suggestions visually while still allowing manual adjustment and cancel",
            rootScript.Contains("var auto_holds_cancelled := false", StringComparison.Ordinal)
                && storeScript.Contains("func advised_hold_indexes() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("AUTO-HOLD SUGGESTED - DRAW OR ADJUST", StringComparison.Ordinal)
                && rootScript.Contains("func _visual_hold_indexes() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("func _draw_hold_indexes() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("func _editable_hold_baseline() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("store.advised_hold_indexes()", StringComparison.Ordinal)
                && rootScript.Contains("\"hold_indexes\": _draw_hold_indexes()", StringComparison.Ordinal)
                && rootScript.Contains("auto_holds_cancelled = true; _send_command(\"clear_holds\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must tolerate both snake_case cabinet snapshots and camelCase web reconnect snapshots for visible play state",
            storeScript.Contains("func _first_value(source: Dictionary, keys: Array, fallback: Variant = null) -> Variant:", StringComparison.Ordinal)
                && storeScript.Contains("func _to_bool(value) -> bool:", StringComparison.Ordinal)
                && storeScript.Contains("_first_value(payload, [\"game_state\", \"gameState\"], null)", StringComparison.Ordinal)
                && storeScript.Contains("_first_value(payload, [\"double_up\", \"doubleUp\", \"doubleUpSession\"], null)", StringComparison.Ordinal)
                && roundUpdateScript.Contains("[\"credits\"]", StringComparison.Ordinal)
                && roundUpdateScript.Contains("[\"jackpot\", \"jackpots\"]", StringComparison.Ordinal)
                && roundUpdateScript.Contains("[\"recovery\"]", StringComparison.Ordinal)
                && roundUpdateScript.Contains("_normalize_button_ids(snapshot)", StringComparison.Ordinal)
                && storeScript.Contains("snapshot[str(key_pair[0])] = value", StringComparison.Ordinal)
                && storeScript.Contains("if payload.has(\"buttons\"):", StringComparison.Ordinal)
                && storeScript.Contains("return str(_first_value(snapshot, [\"game_state\", \"gameState\", \"phase\"], \"idle\"))", StringComparison.Ordinal)
                && storeScript.Contains("return _to_int(_first_value(credits, [\"machine_credits\", \"machineCredits\", \"balance\"], 0))", StringComparison.Ordinal)
                && storeScript.Contains("return _to_int(_first_value(credits, [\"pending_win_amount\", \"pendingWinAmount\"], _first_value(evaluation, [\"win_amount\", \"winAmount\"], 0)))", StringComparison.Ordinal)
                && storeScript.Contains("_first_value(hand, [\"held_indexes\", \"heldIndexes\", \"held\"], [])", StringComparison.Ordinal)
                && storeScript.Contains("_first_value(hand, [\"advised_holds\", \"advisedHolds\"], [])", StringComparison.Ordinal)
                && storeScript.Contains("_first_value(hand, [\"result_cards\", \"resultCards\", \"ResultCards\"], cards())", StringComparison.Ordinal)
                && storeScript.Contains("return str(_first_value(evaluation, [\"hand_rank\", \"handRank\", \"HandRank\"], \"None\"))", StringComparison.Ordinal)
                && storeScript.Contains("_first_value(jp, [\"full_house\", \"fullHouse\"], 0)", StringComparison.Ordinal)
                && rootScript.Contains("func _jackpot_data() -> Dictionary:", StringComparison.Ordinal)
                && rootScript.Contains("func _jackpot_active_4k_slot(jp: Dictionary) -> String:", StringComparison.Ordinal)
                && rootScript.Contains("func _evaluation_data() -> Dictionary:", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(jp, [\"full_house\", \"fullHouse\", \"FullHouse\"], 0)", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(jp, [\"full_house_rank\", \"fullHouseRank\", \"FullHouseRank\"], 0)", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(eval, [\"hand_rank\", \"handRank\", \"HandRank\"], store.hand_rank())", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(eval, [\"jackpot_won\", \"jackpotWon\", \"JackpotWon\"], 0)", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(presentation, [\"bonus\", \"Bonus\"], {})", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(bonus, [\"free_game_count\", \"freeGameCount\", \"FreeGameCount\"], 0)", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(bonus, [\"card_code\", \"cardCode\", \"CardCode\"], \"\")", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must stage card backs before arcade reveals and track pending/displayed card codes to avoid blank or duplicate deal states",
            cardSkinScript.Contains("static func back_texture", StringComparison.Ordinal)
                && cardSkinScript.Contains("HOLD_BACK if held else BACK", StringComparison.Ordinal)
                && rootScript.Contains("\"displayed_code\": \"\"", StringComparison.Ordinal)
                && rootScript.Contains("\"pending_code\": \"\"", StringComparison.Ordinal)
                && rootScript.Contains("func _stage_card_back", StringComparison.Ordinal)
                && rootScript.Contains("slot[\"rect\"].texture = _card_back_texture(held)", StringComparison.Ordinal)
                && rootScript.Contains("slot[\"pending_code\"] = code", StringComparison.Ordinal)
                && rootScript.Contains("slot[\"displayed_code\"] = code", StringComparison.Ordinal)
                && rootScript.Contains("slot[\"pending_code\"] = \"\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet double-up must use one visible five-slot deck row with page carry and live shuffle/result after the dealer",
            rootScript.Contains("const AI9_CARD_ASPECT := 313.0 / 528.0", StringComparison.Ordinal)
                && rootScript.Contains("const DU_BOARD_CARD_SIZE := Vector2(92, 155)", StringComparison.Ordinal)
                && rootScript.Contains("const DU_TRAIL_CARD_SIZE := Vector2(122, 206)", StringComparison.Ordinal)
                && rootScript.Contains("const DU_SHUFFLE_INTERVAL := 0.075", StringComparison.Ordinal)
                && rootScript.Contains("const DU_REVEAL_SETTLE_SECONDS := 0.90", StringComparison.Ordinal)
                && rootScript.Contains("const DOUBLE_UP_AUTO_ENTRY_DELAY_SECONDS := 0.90", StringComparison.Ordinal)
                && rootScript.Contains("var card_area_panel: Panel", StringComparison.Ordinal)
                && rootScript.Contains("var card_center: CenterContainer", StringComparison.Ordinal)
                && rootScript.Contains("const CARD_AREA_MIN_HEIGHT := 248", StringComparison.Ordinal)
                && rootScript.Contains("const CARD_SIZE := Vector2(122, 206)", StringComparison.Ordinal)
                && rootScript.Contains("tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED", StringComparison.Ordinal)
                && rootScript.Contains("card_area_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL", StringComparison.Ordinal)
                && rootScript.Contains("card_center.name = \"CardAreaCenter\"", StringComparison.Ordinal)
                && rootScript.Contains("card_center.set_anchors_preset(Control.PRESET_FULL_RECT)", StringComparison.Ordinal)
                && rootScript.Contains("card_center.add_child(card_container)", StringComparison.Ordinal)
                && rootScript.Contains("_build_du_deck_row(card_center)", StringComparison.Ordinal)
                && rootScript.Contains("func _build_du_deck_row(parent: Node) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_card_area_layout(du_active: bool) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("card_area_panel.visible = true", StringComparison.Ordinal)
                && rootScript.Contains("card_area_panel.custom_minimum_size = Vector2(0, CARD_AREA_MIN_HEIGHT)", StringComparison.Ordinal)
                && rootScript.Contains("card_container.visible = not du_active and not show_idle_title", StringComparison.Ordinal)
                && rootScript.Contains("du_trail_container.visible = du_active", StringComparison.Ordinal)
                && !rootScript.Contains("card_area_panel.visible = not du_active", StringComparison.Ordinal)
                && !rootScript.Contains("card_area_panel.custom_minimum_size = Vector2(0, 0 if du_active else CARD_AREA_MIN_HEIGHT)", StringComparison.Ordinal)
                && rootScript.Contains("var _prev_switches_remaining := -1", StringComparison.Ordinal)
                && rootScript.Contains("var command_switched_dealer := (pending_command_type == \"double_up_switch\" or pending_command_type == \"swap_double_up_card\") and challenger_code.is_empty() and dealer_changed", StringComparison.Ordinal)
                && rootScript.Contains("var switch_count_decreased := _prev_switches_remaining >= 0 and switches < _prev_switches_remaining", StringComparison.Ordinal)
                && rootScript.Contains("var switch_replaced_dealer := challenger_code.is_empty() and dealer_changed and (switch_count_decreased or command_switched_dealer)", StringComparison.Ordinal)
                && rootScript.Contains("var inferred_win_reveal := challenger_code.is_empty() and dealer_changed and not switch_replaced_dealer", StringComparison.Ordinal)
                && rootScript.Contains("var board_dealer_code := _prev_dealer_code if ((inferred_win_reveal or switch_replaced_dealer) and not _prev_dealer_code.is_empty()) else dealer_code", StringComparison.Ordinal)
                && rootScript.Contains("var board_challenger_code := dealer_code if inferred_win_reveal else challenger_code", StringComparison.Ordinal)
                && rootScript.Contains("var board_status := \"Win\" if inferred_win_reveal else status", StringComparison.Ordinal)
                && rootScript.Contains("_prepare_du_board(du_data, board_dealer_code, board_challenger_code, board_status, switch_replaced_dealer)", StringComparison.Ordinal)
                && rootScript.Contains("if switch_replaced_dealer:", StringComparison.Ordinal)
                && rootScript.Contains("var du_shuffle_replace_dealer_only := false", StringComparison.Ordinal)
                && rootScript.Contains("var du_last_switch_dealer_code := \"\"", StringComparison.Ordinal)
                && rootScript.Contains("du_last_switch_dealer_code = dealer_code", StringComparison.Ordinal)
                && rootScript.Contains("_start_du_dealer_replace_shuffle(dealer_code)", StringComparison.Ordinal)
                && rootScript.Contains("var showing_switched_dealer := not du_last_switch_dealer_code.is_empty() and du_last_switch_dealer_code == dealer_code", StringComparison.Ordinal)
                && rootScript.Contains("if inferred_win_reveal:", StringComparison.Ordinal)
                && rootScript.Contains("_start_du_card_shuffle(board_dealer_code, board_challenger_code)", StringComparison.Ordinal)
                && rootScript.Contains("_queue_du_dealer_promotion(board_challenger_code, board_dealer_code)", StringComparison.Ordinal)
                && rootScript.Contains("var du_shuffle_timer: Timer", StringComparison.Ordinal)
                && rootScript.Contains("var du_promote_timer: Timer", StringComparison.Ordinal)
                && rootScript.Contains("var du_pending_promote_trail_code := \"\"", StringComparison.Ordinal)
                && rootScript.Contains("var du_local_trail_entries: Array = []", StringComparison.Ordinal)
                && rootScript.Contains("var auto_double_up_timer: Timer", StringComparison.Ordinal)
                && rootScript.Contains("var auto_double_up_round_ids: Array = []", StringComparison.Ordinal)
                && rootScript.Contains("var auto_double_up_pending_round_id := \"\"", StringComparison.Ordinal)
                && rootScript.Contains("du_shuffle_timer.timeout.connect(_process_du_shuffle)", StringComparison.Ordinal)
                && rootScript.Contains("du_promote_timer.timeout.connect(_on_du_promote_timeout)", StringComparison.Ordinal)
                && rootScript.Contains("auto_double_up_timer.timeout.connect(_on_auto_double_up_timer_timeout)", StringComparison.Ordinal)
                && rootScript.Contains("auto_double_up_timer.wait_time = DOUBLE_UP_AUTO_ENTRY_DELAY_SECONDS", StringComparison.Ordinal)
                && rootScript.Contains("du_trail_container.name = \"DoubleUpDeckRow\"", StringComparison.Ordinal)
                && rootScript.Contains("du_trail_container.visible = false", StringComparison.Ordinal)
                && rootScript.Contains("du_trail_container.add_theme_constant_override(\"separation\", CARD_GAP)", StringComparison.Ordinal)
                && rootScript.Contains("slot.name = \"DoubleUpDeckSlot%d\" % index", StringComparison.Ordinal)
                && rootScript.Contains("slot_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED", StringComparison.Ordinal)
                && rootScript.Contains("if index == 0:", StringComparison.Ordinal)
                && rootScript.Contains("du_dealer_rect = slot_rect", StringComparison.Ordinal)
                && rootScript.Contains("elif index == 1:", StringComparison.Ordinal)
                && rootScript.Contains("du_challenger_rect = slot_rect", StringComparison.Ordinal)
                && rootScript.Contains("func _du_visible_deck_codes", StringComparison.Ordinal)
                && rootScript.Contains("func _du_visible_hit_codes(du_data: Dictionary, dealer_code: String, challenger_code: String, max_count: int) -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("func _du_visible_page_entries(du_data: Dictionary, dealer_code: String, challenger_code: String, slot_count: int) -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("var page_entries := []", StringComparison.Ordinal)
                && rootScript.Contains("page_entries = _du_visible_page_entries(du_data, dealer_code, challenger_code, slot_count)", StringComparison.Ordinal)
                && rootScript.Contains("var dealer_index := _du_page_entry_index(page_entries, dealer_code)", StringComparison.Ordinal)
                && rootScript.Contains("var challenger_index := -1", StringComparison.Ordinal)
                && rootScript.Contains("var reveal_index: int = challenger_index if challenger_index >= 0 else min(dealer_index + 1, slot_count - 1)", StringComparison.Ordinal)
                && rootScript.Contains("if slot_index == dealer_index:", StringComparison.Ordinal)
                && rootScript.Contains("label = \"DEALER\"", StringComparison.Ordinal)
                && rootScript.Contains("elif slot_index == challenger_index:", StringComparison.Ordinal)
                && rootScript.Contains("label = _du_result_label(status)", StringComparison.Ordinal)
                && rootScript.Contains("_set_du_dealer_slot(dealer_index)", StringComparison.Ordinal)
                && rootScript.Contains("_set_du_challenger_slot(reveal_index)", StringComparison.Ordinal)
                && rootScript.Contains("_set_du_board_back(slot_index, \"BIG / SMALL ?\", 1.0)", StringComparison.Ordinal)
                && rootScript.Contains("var page_start := _du_page_start_for_dealer_index(dealer_position, slot_count)", StringComparison.Ordinal)
                && rootScript.Contains("func _du_timeline_entries(du_data: Dictionary) -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("func _du_page_start_for_dealer_index(dealer_position: int, slot_count: int) -> int:", StringComparison.Ordinal)
                && rootScript.Contains("var stride: int = max(1, slot_count - 1)", StringComparison.Ordinal)
                && rootScript.Contains("if dealer_position < slot_count:", StringComparison.Ordinal)
                && rootScript.Contains("return int(floor(float(dealer_position - 1) / float(stride))) * stride", StringComparison.Ordinal)
                && rootScript.Contains("_append_du_timeline_entry(result, code, _du_entry_label(entry))", StringComparison.Ordinal)
                && rootScript.Contains("var has_local_trail := not du_local_trail_entries.is_empty()", StringComparison.Ordinal)
                && rootScript.Contains("var trail_source := du_local_trail_entries if has_local_trail else _du_array(du_data, [\"card_trail\", \"cardTrail\", \"CardTrail\"])", StringComparison.Ordinal)
                && rootScript.Contains("func _du_current_round_index(du_data: Dictionary) -> int:", StringComparison.Ordinal)
                && rootScript.Contains("func _append_du_timeline_entry(entries: Array, code: String, label_text: String) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _append_du_local_trail_entry(code: String, label_text: String = \"PLAYED\") -> void:", StringComparison.Ordinal)
                && !rootScript.Contains("while du_local_trail_entries.size() > DOUBLE_UP_BOARD_SLOT_COUNT * 2:", StringComparison.Ordinal)
                && !rootScript.Contains("func _du_visible_trail_entries", StringComparison.Ordinal)
                && !rootScript.Contains("var max_trail_per_page", StringComparison.Ordinal)
                && !rootScript.Contains("if code == dealer_code or code == challenger_code:", StringComparison.Ordinal)
                && !rootScript.Contains("var shuffle_index := -1", StringComparison.Ordinal)
                && !rootScript.Contains("shuffle_index = min(trail_codes.size(), du_cards.size() - 1)", StringComparison.Ordinal)
                && !rootScript.Contains("du_focus_stage.name = \"DoubleUpSingleCardStage\"", StringComparison.Ordinal)
                && !rootScript.Contains("challenger_slot.name = \"DoubleUpChallengerStage\"", StringComparison.Ordinal)
                && !rootScript.Contains("dealer_slot.name = \"DoubleUpDealerReference\"", StringComparison.Ordinal)
                && !rootScript.Contains("du_challenger_rect.custom_minimum_size = DU_MAIN_CARD_SIZE", StringComparison.Ordinal)
                && !rootScript.Contains("du_focus_row.add_child(dealer_slot)", StringComparison.Ordinal)
                && !rootScript.Contains("var vs_label := _make_label(\"VS\"", StringComparison.Ordinal)
                && rootScript.Contains("func _start_du_card_shuffle", StringComparison.Ordinal)
                && rootScript.Contains("func _start_du_dealer_replace_shuffle(new_dealer_code: String) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("if du_dealer_rect == null or du_challenger_rect == null:", StringComparison.Ordinal)
                && rootScript.Contains("func _process_du_shuffle", StringComparison.Ordinal)
                && rootScript.Contains("func _finish_du_card_shuffle", StringComparison.Ordinal)
                && rootScript.Contains("var target_rect: TextureRect = du_challenger_rect", StringComparison.Ordinal)
                && rootScript.Contains("_set_du_card_texture(target_rect, code)", StringComparison.Ordinal)
                && !rootScript.Contains("if du_shuffle_replace_dealer_only:\n\t\ttarget_rect = du_dealer_rect", StringComparison.Ordinal)
                && !rootScript.Replace("\r\n", "\n").Contains("du_dealer_rect.modulate = Color(1, 1, 1, 1)\n\tdu_dealer_rect.scale = Vector2(0.92, 0.92)\n\t_process_du_shuffle()", StringComparison.Ordinal)
                && rootScript.Contains("du_challenger_rect.scale = Vector2(0.92, 0.92)", StringComparison.Ordinal)
                && rootScript.Contains("du_challenger_rect.texture = _card_back_texture(false)", StringComparison.Ordinal)
                && rootScript.Contains("if du_shuffle_replace_dealer_only:", StringComparison.Ordinal)
                && rootScript.Contains("du_shuffle_timer.start", StringComparison.Ordinal)
                && rootScript.Contains("func _maybe_auto_start_double_up(game_state: String, du_active: bool) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("auto_double_up_pending_round_id = round_id", StringComparison.Ordinal)
                && rootScript.Contains("auto_double_up_timer.start()", StringComparison.Ordinal)
                && rootScript.Contains("func _cancel_auto_double_up_timer() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _on_auto_double_up_timer_timeout() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("auto_double_up_round_ids.append(round_id)", StringComparison.Ordinal)
                && rootScript.Contains("_send_command(\"double_up_start\", {\"round_id\": round_id})", StringComparison.Ordinal)
                && !rootScript.Contains("call_deferred(\"_auto_start_double_up\"", StringComparison.Ordinal)
                && rootScript.Contains("func _clear_du_pending_promotion() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _queue_du_dealer_promotion(next_dealer_code: String, trail_code: String = \"\", trail_label: String = \"PLAYED\") -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _on_du_promote_timeout() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_append_du_local_trail_entry(trail_code, trail_label)", StringComparison.Ordinal)
                && rootScript.Contains("_prepare_du_board(du_data, next_dealer_code, \"\", _du_status(du_data), false)", StringComparison.Ordinal)
                && rootScript.Contains("_start_du_card_shuffle(next_dealer_code, \"\")", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_du_trail(du_data: Dictionary, dealer_code: String, challenger_code: String, status: String, dealer_replace_only: bool = false) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_du_trail(du_data, dealer_code, challenger_code, status, dealer_replace_only)", StringComparison.Ordinal)
                && rootScript.Contains("var dealer_code := _du_card_code(du_data, [\"dealer_card\", \"dealerCard\", \"DealerCard\", \"double_up_card\", \"doubleUpCard\", \"DoubleUpCard\"])", StringComparison.Ordinal)
                && rootScript.Contains("var challenger_code := _du_card_code(du_data, [\"challenger_card\", \"challengerCard\", \"ChallengerCard\", \"picked_card\", \"pickedCard\", \"PickedCard\"])", StringComparison.Ordinal)
                && rootScript.Contains("[\"current_round_index\", \"currentRoundIndex\", \"CurrentRoundIndex\", \"double_up_count\", \"doubleUpCount\", \"DoubleUpCount\"]", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must expose the AI9Poker-style physical control deck and route double-up switch through BET",
            rootScript.Contains("var hold_buttons: Array = []", StringComparison.Ordinal)
                && rootScript.Contains("root.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED", StringComparison.Ordinal)
                && rootScript.Contains("vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL", StringComparison.Ordinal)
                && rootScript.Contains("content.size_flags_vertical = Control.SIZE_EXPAND_FILL", StringComparison.Ordinal)
                && rootScript.Contains("bottom_spacer.name = \"CabinetBottomDeckSpacer\"", StringComparison.Ordinal)
                && rootScript.Contains("bottom_spacer.custom_minimum_size = Vector2(0, 4)", StringComparison.Ordinal)
                && !rootScript.Contains("bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL", StringComparison.Ordinal)
                && rootScript.Contains("const CONTROL_DECK_MIN_HEIGHT := 324", StringComparison.Ordinal)
                && rootScript.Contains("const CONTROL_HOLD_BUTTON_HEIGHT := 70", StringComparison.Ordinal)
                && rootScript.Contains("const CONTROL_ACTION_BUTTON_HEIGHT := 80", StringComparison.Ordinal)
                && rootScript.Contains("const CONTROL_BOTTOM_BUTTON_HEIGHT := 72", StringComparison.Ordinal)
                && rootScript.Contains("deck.custom_minimum_size = Vector2(0, CONTROL_DECK_MIN_HEIGHT)", StringComparison.Ordinal)
                && rootScript.Contains("var menu_overlay: PanelContainer", StringComparison.Ordinal)
                && rootScript.Contains("var menu_panel: VBoxContainer", StringComparison.Ordinal)
                && rootScript.Contains("var menu_balance_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("func _build_control_deck", StringComparison.Ordinal)
                && rootScript.Contains("func _build_menu_panel", StringComparison.Ordinal)
                && rootScript.Contains("menu_balance_label = _make_label(\"\", 11, COLOR_GREEN, HORIZONTAL_ALIGNMENT_CENTER)", StringComparison.Ordinal)
                && rootScript.Contains("func _credit_line_for_amount(machine_credit_amount: int) -> String:", StringComparison.Ordinal)
                && rootScript.Contains("return \"CREDIT %s\" % _format_amount(machine_credit_amount)", StringComparison.Ordinal)
                && rootScript.Contains("func _menu_balance_line() -> String:", StringComparison.Ordinal)
                && rootScript.Contains("return \"CREDIT %s\\nWALLET %s\\nBONUS %s\\nSTAKE %s\\nIN %s\"", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_menu_balance() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_build_menu_panel(self)", StringComparison.Ordinal)
                && rootScript.Contains("menu_overlay.name = \"CabinetMenuOverlay\"", StringComparison.Ordinal)
                && rootScript.Contains("menu_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)", StringComparison.Ordinal)
                && rootScript.Contains("menu_overlay.visible = menu_open and active_screen == \"game\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"big\", \"BIG\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"small\", \"SMALL\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"cancel_hold\", \"CANCEL\\nHOLD\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"deal_draw\", \"DEAL\\nDRAW\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"bet\", \"BET\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"take_half\", \"TAKE\\nHALF\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"menu\", \"MENU\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"take_score\", \"TAKE\\nSCORE\"", StringComparison.Ordinal)
                && rootScript.Contains("_on_hold_button_pressed.bind(index)", StringComparison.Ordinal)
                && rootScript.Contains("func _can_switch_double_up_dealer() -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("var du := _double_up_data()", StringComparison.Ordinal)
                && rootScript.Contains("if not _is_double_up_active(du) or _du_switches_remaining(du) <= 0:", StringComparison.Ordinal)
                && rootScript.Contains("return store.can_press(\"double_up_switch\") or _is_double_up_state_name(store.game_state())", StringComparison.Ordinal)
                && rootScript.Contains("func _is_double_up_state_name(value: String) -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("return normalized == \"double_up\" or normalized == \"doubleup\"", StringComparison.Ordinal)
                && rootScript.Contains("func _double_up_data() -> Dictionary:", StringComparison.Ordinal)
                && rootScript.Contains("source = store.snapshot.get(\"doubleUpSession\", null)", StringComparison.Ordinal)
                && rootScript.Contains("func _is_double_up_active(du_data: Dictionary) -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("_du_card_code(du_data, [\"dealer_card\", \"dealerCard\", \"DealerCard\", \"double_up_card\", \"doubleUpCard\", \"DoubleUpCard\"])", StringComparison.Ordinal)
                && rootScript.Contains("func _du_switches_remaining(du_data: Dictionary) -> int:", StringComparison.Ordinal)
                && rootScript.Contains("_du_first_value(du_data, [\"switches_remaining\", \"switchesRemaining\", \"SwitchesRemaining\", \"swap_active_remaining\", \"swapActiveRemaining\", \"SwapActiveRemaining\"], 0)", StringComparison.Ordinal)
                && rootScript.Contains("if id == \"bet\" and (_can_switch_double_up_dealer() or _can_start_double_up_from_win()): return true", StringComparison.Ordinal)
                && rootScript.Contains("if _can_switch_double_up_dealer():", StringComparison.Ordinal)
                && rootScript.Contains("return store.can_press(\"double_up_switch\") or _is_double_up_state_name(store.game_state())", StringComparison.Ordinal)
                && rootScript.Contains("elif _can_start_double_up_from_win():", StringComparison.Ordinal)
                && rootScript.Contains("func _can_start_double_up_from_win() -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("return _evaluation_double_up_available(_evaluation_data())", StringComparison.Ordinal)
                && rootScript.Contains("func _send_double_up_start() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_send_command(\"double_up_start\", {\"round_id\": round_id})", StringComparison.Ordinal)
                && rootScript.Contains("_send_command(\"double_up_switch\", {\"round_id\": switch_round_id})", StringComparison.Ordinal)
                && rootScript.Contains("func _can_switch_full_house_rank() -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("if index == 0 and _can_switch_full_house_rank():", StringComparison.Ordinal)
                && rootScript.Contains("_send_command(\"jackpot_rank_change\", {\"rank\": _next_full_house_rank()})", StringComparison.Ordinal)
                && storeScript.Contains("\"swap_double_up_card\": \"double_up_switch\"", StringComparison.Ordinal)
                && storeScript.Contains("\"double_up_switch\"", StringComparison.Ordinal)
                && storeScript.Contains("hand.get(\"round_id\", hand.get(\"roundId\", null))", StringComparison.Ordinal)
                && storeScript.Contains("snapshot.get(\"double_up\", snapshot.get(\"doubleUp\", snapshot.get(\"doubleUpSession\", {})))", StringComparison.Ordinal)
                && gameService.Contains("\"big\", \"small\", \"double_up_switch\", \"take_half\"", StringComparison.Ordinal)
                && gameService.Contains("buttons.Add(\"double_up_switch\")", StringComparison.Ordinal)
                && gameService.Replace("\r\n", "\n").Contains("buttons.Add(\"double_up_switch\");\n                    buttons.Add(\"bet\");", StringComparison.Ordinal)
                && gameService.Contains("private static bool CanSwitchDoubleUpDealer(string gameState, ActiveRoundStateDto? activeRound)", StringComparison.Ordinal)
                && gameService.Contains("gameState == \"double_up\" && (activeRound?.DoubleUpSession?.SwitchesRemaining ?? 0) > 0", StringComparison.Ordinal)
                && gameService.Contains("buttons.Add(\"hold_0\")", StringComparison.Ordinal)
                && gameService.Contains("ChangeCabinetJackpotRankAsync(userId, command.MachineId", StringComparison.Ordinal)
                && !rootScript.Contains("_build_menu_panel(content)", StringComparison.Ordinal)
                && !rootScript.Contains("[\"swap_double_up_card\", \"SWAP\\nCARD\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet control deck must render as a warm wood-grain arcade surface with beveled physical button depth",
            rootScript.Contains("const COLOR_CONTROL_DECK_TOP", StringComparison.Ordinal)
                && rootScript.Contains("const COLOR_CONTROL_DECK_MID", StringComparison.Ordinal)
                && rootScript.Contains("const COLOR_CONTROL_DECK_BOTTOM", StringComparison.Ordinal)
                && rootScript.Contains("const COLOR_WOOD_GRAIN_LIGHT", StringComparison.Ordinal)
                && rootScript.Contains("const COLOR_WOOD_GRAIN_DARK", StringComparison.Ordinal)
                && rootScript.Contains("const BUTTON_BEVEL_SHADOW_SIZE := 5", StringComparison.Ordinal)
                && rootScript.Contains("const BUTTON_PRESSED_SHADOW_SIZE := 1", StringComparison.Ordinal)
                && rootScript.Contains("func _decorate_control_deck(deck: Control) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_add_control_deck_band(deck, \"ControlDeckBandTop\"", StringComparison.Ordinal)
                && rootScript.Contains("_add_control_deck_band(deck, \"ControlDeckBandMid\"", StringComparison.Ordinal)
                && rootScript.Contains("_add_control_deck_band(deck, \"ControlDeckBandBottom\"", StringComparison.Ordinal)
                && rootScript.Contains("grain.name = \"ControlDeckGrain\"", StringComparison.Ordinal)
                && rootScript.Contains("style.shadow_size = BUTTON_BEVEL_SHADOW_SIZE", StringComparison.Ordinal)
                && rootScript.Contains("style.shadow_offset = Vector2(0, 3)", StringComparison.Ordinal)
                && rootScript.Contains("pressed.shadow_size = BUTTON_PRESSED_SHADOW_SIZE", StringComparison.Ordinal)
                && rootScript.Contains("disabled.shadow_size = 0", StringComparison.Ordinal));

        var ai9ButtonAssetNames = new[]
        {
            "bet.png", "bet_on.png",
            "big.png", "big_on.png",
            "cancel_hold.png", "cancel_hold_on.png",
            "deal_draw.png", "deal_draw_on.png",
            "hold_off.png", "hold_on.png",
            "small.png", "small_on.png",
            "take_half.png", "take_half_on.png",
            "take_score.png", "take_score_on.png",
        };

        Assert(
            failures,
            "Godot cabinet physical controls must use the same AI9Poker-style photographed button assets as the web/API client",
            rootScript.Contains("const BUTTON_ASSET_BASE_PATH := \"res://skins/lucky5/buttons/\"", StringComparison.Ordinal)
                && rootScript.Contains("func _apply_button_asset_styles(button: Button, asset_key: String) -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("var style := StyleBoxTexture.new()", StringComparison.Ordinal)
                && rootScript.Contains("ResourceLoader.load(path) as Texture2D", StringComparison.Ordinal)
                && rootScript.Contains("var button_asset_textures: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("button_asset_textures[asset_name] = texture", StringComparison.Ordinal)
                && rootScript.Contains("button.set_meta(\"uses_ai9_button_asset\", true)", StringComparison.Ordinal)
                && rootScript.Contains("_make_button(\"HOLD\", CONTROL_HOLD_BUTTON_HEIGHT, COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK, \"hold\")", StringComparison.Ordinal)
                && rootScript.Contains("var asset_key := str(def[0])", StringComparison.Ordinal)
                && rootScript.Contains("hold_button.text = \"HELD\" if held else (\"\" if _button_uses_asset(hold_button) else (\"FH\" if fh_switch else \"HOLD\"))", StringComparison.Ordinal)
                && ai9ButtonAssetNames.All(name => RepoFileExists("godot", "cabinet", "skins", "lucky5", "buttons", name)));

        Assert(
            failures,
            "Godot cabinet physical controls must preserve the reference button colors: amber BIG/SMALL, red TAKE HALF, and orange TAKE SCORE",
            rootScript.Contains("[\"big\", \"BIG\", COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK]", StringComparison.Ordinal)
                && rootScript.Contains("[\"small\", \"SMALL\", COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK]", StringComparison.Ordinal)
                && rootScript.Contains("[\"take_half\", \"TAKE\\nHALF\", COLOR_BUTTON_RED, COLOR_WHITE", StringComparison.Ordinal)
                && rootScript.Contains("[\"take_score\", \"TAKE\\nSCORE\", COLOR_BUTTON_ORANGE, COLOR_BG, COLOR_GOLD_DARK]", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet machine info must show the AI9Poker KENT /3 counter and always-visible 4 OF A KIND WINS BONUS banner",
            rootScript.Contains("var bonus_message_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("machine_kent_label = _make_label(\"KENT /3 : 0\"", StringComparison.Ordinal)
                && rootScript.Contains("bonus_message_label = _make_label(\"4 OF A KIND   WINS BONUS\"", StringComparison.Ordinal)
                && rootScript.Contains("bonus_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL", StringComparison.Ordinal)
                && rootScript.Contains("machine_kent_label.text = \"KENT /3 : %s\"", StringComparison.Ordinal)
                && rootScript.Contains("bonus_message_label.visible = true", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must mirror AI9Poker bonus/free-game card presentation from the backend snapshot",
            cabinetContracts.Contains("public sealed record CabinetBonusPresentationDto", StringComparison.Ordinal)
                && cabinetContracts.Contains("CabinetBonusPresentationDto? Bonus = null", StringComparison.Ordinal)
                && cabinetContracts.Contains("[property: JsonPropertyName(\"free_game_count\")]", StringComparison.Ordinal)
                && gameService.Contains("BuildCabinetBonusPresentation(gameState, activeRound, doubleUpSession, pendingWin)", StringComparison.Ordinal)
                && gameService.Contains("Kind: \"bonus_card\"", StringComparison.Ordinal)
                && gameService.Contains("Kind: \"lucky5\"", StringComparison.Ordinal)
                && gameService.Contains("FindRepeatedRankCabinetCard(activeRound?.ResultCards, 4)", StringComparison.Ordinal)
                && gameService.Contains("TryBuildCabinetCardFromCode(\"5S\")", StringComparison.Ordinal)
                && rootScript.Contains("var bonus_stage_panel: PanelContainer", StringComparison.Ordinal)
                && rootScript.Contains("bonus_stage_panel = PanelContainer.new()", StringComparison.Ordinal)
                && rootScript.Contains("bonus_stage_card = TextureRect.new()", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_bonus_stage() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("var bonus: Dictionary = _bonus_presentation()", StringComparison.Ordinal)
                && rootScript.Contains("func _fallback_bonus_presentation() -> Dictionary:", StringComparison.Ordinal)
                && rootScript.Contains("store.hand_rank() == \"FourOfAKind\"", StringComparison.Ordinal)
                && rootScript.Contains("func _four_kind_rank_card_code() -> String:", StringComparison.Ordinal)
                && rootScript.Contains("const CABINET_AI9_SKIN_ROOT := \"res://skins/cabinet_ai9/\"", StringComparison.Ordinal)
                && rootScript.Contains("func _load_cabinet_skin_resources() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("arcade_font = _load_cabinet_font(\"fonts/ARCADE.ttf\")", StringComparison.Ordinal)
                && rootScript.Contains("press_sound = _load_cabinet_audio(CABINET_PRESS_SOUND)", StringComparison.Ordinal)
                && rootScript.Contains("_set_bonus_stage_texture(card_code, active, kind)", StringComparison.Ordinal)
                && rootScript.Contains("_load_cabinet_texture(\"images/lucky5.png\")", StringComparison.Ordinal)
                && rootScript.Contains("_load_cabinet_texture(\"images/bonus.png\")", StringComparison.Ordinal)
                && rootScript.Contains("_load_cabinet_texture(\"images/free.png\")", StringComparison.Ordinal)
                && rootScript.Contains("_style_bonus_stage(active)", StringComparison.Ordinal)
                && rootScript.Contains("_animate_bonus_stage(active)", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet win display must animate the AI9Poker-style paytable-row win drain and pulse credits from backend values",
            rootScript.Contains("const WIN_COUNTER_MIN_DURATION := 0.18", StringComparison.Ordinal)
                && rootScript.Contains("const WIN_COUNTER_MAX_DURATION := 0.75", StringComparison.Ordinal)
                && rootScript.Contains("const CREDIT_DRAIN_MIN_DURATION := 1.20", StringComparison.Ordinal)
                && rootScript.Contains("const CREDIT_DRAIN_MAX_DURATION := 2.00", StringComparison.Ordinal)
                && rootScript.Contains("const CREDIT_DRAIN_JACKPOT_DURATION := 5.00", StringComparison.Ordinal)
                && rootScript.Contains("var win_displayed_amount := 0", StringComparison.Ordinal)
                && rootScript.Contains("var win_paytable_rank_key := \"\"", StringComparison.Ordinal)
                && rootScript.Contains("var last_machine_credit_amount := -1", StringComparison.Ordinal)
                && rootScript.Contains("var displayed_machine_credit_amount := -1", StringComparison.Ordinal)
                && rootScript.Contains("var credit_target_amount := -1", StringComparison.Ordinal)
                && rootScript.Contains("var credit_transfer_active := false", StringComparison.Ordinal)
                && rootScript.Contains("var credit_counter_tween: Tween", StringComparison.Ordinal)
                && rootScript.Contains("func _build_win_display(_parent: Node) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("win_slot_label.visible = false", StringComparison.Ordinal)
                && rootScript.Contains("win_amount_label.visible = false", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_credit_display()", StringComparison.Ordinal)
                && rootScript.Contains("var pending := store.pending_win_amount()", StringComparison.Ordinal)
                && rootScript.Contains("func _set_credit_display_amount(value: Variant) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _animate_credit_transfer(from_amount: int, to_amount: int, drain_amount: int) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _settlement_drain_duration(amount: int) -> float:", StringComparison.Ordinal)
                && rootScript.Contains("func _on_credit_transfer_finished() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("if credit_transfer_active:", StringComparison.Ordinal)
                && rootScript.Contains("var jackpot_win: int = _current_jackpot_win_amount()", StringComparison.Ordinal)
                && rootScript.Contains("if credit_gain > 0 and jackpot_win > 0:", StringComparison.Ordinal)
                && rootScript.Contains("pending_command_type == \"take_score\" or pending_command_type == \"cash_out\"", StringComparison.Ordinal)
                && rootScript.Contains("func _animate_win_amount_to(target_amount: int) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("tween_method(Callable(self, \"_set_credit_display_amount\")", StringComparison.Ordinal)
                && rootScript.Contains("tween_method(Callable(self, \"_set_win_display_amount\")", StringComparison.Ordinal)
                && rootScript.Contains("func _pulse_credit_display() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _pulse_win_display() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _active_win_paytable_amount_label() -> Label:", StringComparison.Ordinal)
                && rootScript.Contains("func _paytable_rank_key(raw_rank: String) -> String:", StringComparison.Ordinal)
                && rootScript.Contains("win_paytable_rank_key = _paytable_rank_key", StringComparison.Ordinal)
                && rootScript.Contains("var score_label := _active_win_paytable_amount_label()", StringComparison.Ordinal)
                && rootScript.Contains("score_label.scale = Vector2(1.10, 1.10)", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_paytable_values()", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_paytable_highlights()", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet paytable must mirror AI9Poker with dynamic stake payouts, paytable-row score drain, and backend-compatible Full House jackpot lookup",
            rootScript.Contains("var paytable_rows: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var paytable_amount_labels: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var paytable_multipliers: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var full_house_rank_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("var full_house_jackpot_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("paytable_rows[str(hand[0])] = row_panel", StringComparison.Ordinal)
                && rootScript.Contains("paytable_amount_labels[str(hand[0])] = amount_l", StringComparison.Ordinal)
                && rootScript.Contains("paytable_multipliers[str(hand[0])] = int(hand[2])", StringComparison.Ordinal)
                && rootScript.Contains("jackpot_counters[\"fh\"] = full_house_jackpot_label", StringComparison.Ordinal)
                && rootScript.Contains("if win_displayed_amount > 0 and str(key) == score_key:", StringComparison.Ordinal)
                && rootScript.Contains("amount_l.text = \"+%s\" % _format_amount(win_displayed_amount)", StringComparison.Ordinal)
                && rootScript.Contains("amount_l.text = _format_amount(stake * multiplier)", StringComparison.Ordinal)
                && rootScript.Contains("full_house_rank_label.text = _full_house_rank_text()", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_jackpot_counter(\"fh\", store._to_int(_du_first_value(jp, [\"full_house\", \"fullHouse\", \"FullHouse\"], 0)))", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_paytable_values()", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_paytable_highlights()", StringComparison.Ordinal)
                && rootScript.Contains("sty.bg_color = Color(1.0, 0.86, 0.16, 0.36)", StringComparison.Ordinal)
                && rootScript.Contains("sty.border_color = COLOR_GOLD", StringComparison.Ordinal)
                && rootScript.Contains("sty.border_width_left = 1; sty.border_width_right = 1", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet jackpot strip must expose exactly the three AI9Poker machine counters and frame the active 4K slot",
            rootScript.Contains("var jackpot_counter_panels: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("[\"*\", \"4k-a\", COLOR_GREEN_DIM]", StringComparison.Ordinal)
                && rootScript.Contains("[\"SF\", \"sf\", COLOR_RED]", StringComparison.Ordinal)
                && rootScript.Contains("[\"*\", \"4k-b\", COLOR_GREEN_DIM]", StringComparison.Ordinal)
                && !rootScript.Contains("[\"FH\", \"fh\"", StringComparison.Ordinal)
                && rootScript.Contains("jackpot_counter_panels[str(slot[1])] = counter_panel", StringComparison.Ordinal)
                && rootScript.Contains("_set_jackpot_counter_active(\"4k-a\", active_4k == \"A\")", StringComparison.Ordinal)
                && rootScript.Contains("_set_jackpot_counter_active(\"4k-b\", active_4k == \"B\")", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet jackpot counters must animate live trickles and visible jackpot drains instead of snapping meter values",
            rootScript.Contains("const JACKPOT_TRICKLE_DURATION := 0.30", StringComparison.Ordinal)
                && rootScript.Contains("const JACKPOT_DRAIN_MIN_DURATION := 2.80", StringComparison.Ordinal)
                && rootScript.Contains("const JACKPOT_DRAIN_MAX_DURATION := 5.50", StringComparison.Ordinal)
                && rootScript.Contains("var displayed_jackpots: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var jackpot_counter_tweens: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("func _animate_jackpot_counter(slot_key: String, from_value: int, to_value: int) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("to_value < from_value", StringComparison.Ordinal)
                && rootScript.Contains("func _jackpot_counter_duration(from_value: int, to_value: int) -> float:", StringComparison.Ordinal)
                && rootScript.Contains("JACKPOT_DRAIN_MIN_DURATION, JACKPOT_DRAIN_MAX_DURATION", StringComparison.Ordinal)
                && rootScript.Contains("func _pulse_jackpot_counter(slot_key: String) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_jackpot_counter(\"fh\", store._to_int(_du_first_value(jp, [\"full_house\", \"fullHouse\", \"FullHouse\"], 0)))", StringComparison.Ordinal)
                && rootScript.Contains("tween_method(Callable(self, \"_set_jackpot_counter_display\").bind(slot_key)", StringComparison.Ordinal)
                && rootScript.Contains("func _set_jackpot_counter_display(value: float, slot_key: String) -> void:", StringComparison.Ordinal));

        Assert(
            failures,
"Godot cabinet idle screen must delay the armed Full House rank and then show it alone after the Lucky 5 title",
            rootScript.Contains("const IDLE_FH_CARD_DELAY_SECONDS := 60.0", StringComparison.Ordinal)
                && rootScript.Contains("const IDLE_TITLE_TEXT := \"LUCKY 5\"", StringComparison.Ordinal)
                && rootScript.Contains("var idle_fh_rank_revealed := false", StringComparison.Ordinal)
                && rootScript.Contains("var idle_title_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("idle_fh_timer.timeout.connect(_on_idle_fh_timer_timeout)", StringComparison.Ordinal)
                && rootScript.Contains("idle_title_label = _make_label(IDLE_TITLE_TEXT", StringComparison.Ordinal)
                && rootScript.Contains("func _sync_idle_fh_timer(is_blank_idle: bool) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _on_idle_fh_timer_timeout() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("var show_idle_rank_card := is_blank_idle and idle_fh_rank_revealed", StringComparison.Ordinal)
                && rootScript.Contains("card_container.visible = not du_active and not show_idle_title", StringComparison.Ordinal)
                && rootScript.Contains("if show_idle_rank_card and index == 2:", StringComparison.Ordinal)
                && rootScript.Contains("if show_idle_rank_card:", StringComparison.Ordinal)
                && rootScript.Contains("_stage_empty_card_slot(slot)", StringComparison.Ordinal)
                && rootScript.Contains("var rank_code := _full_house_rank_card_code()", StringComparison.Ordinal)
                && rootScript.Contains("slot[\"hold_label\"].text = \"FH\"", StringComparison.Ordinal)
                && rootScript.Contains("func _full_house_rank_card_code() -> String:", StringComparison.Ordinal)
                && rootScript.Contains("return str(max(2, rank_value)) + \"S\" if rank_value > 0 else \"AS\"", StringComparison.Ordinal));
    }

    private static string ResolveRepoFilePath(params string[] segments)
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(new[] { dir.FullName }.Concat(segments).ToArray());
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new FileNotFoundException($"Could not locate repo file '{Path.Combine(segments)}' from base directory '{AppContext.BaseDirectory}'");
    }

    private static bool RepoFileExists(params string[] segments)
    {
        try
        {
            _ = ResolveRepoFilePath(segments);
            return true;
        }
        catch (FileNotFoundException)
        {
            return false;
        }
    }

    private static void Assert(List<string> failures, string message, bool condition)
    {
        if (!condition)
        {
            failures.Add(message);
        }
    }

    private static int CountOccurrences(string source, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = source.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
    }

    private static string ExtractBetween(string source, string start, string end)
    {
        var startIndex = source.IndexOf(start, StringComparison.Ordinal);
        if (startIndex < 0)
        {
            return string.Empty;
        }

        var endIndex = source.IndexOf(end, startIndex + start.Length, StringComparison.Ordinal);
        return endIndex < 0 ? source[startIndex..] : source[startIndex..endIndex];
    }
}
