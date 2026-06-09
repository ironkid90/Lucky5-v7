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
        string webHomePage;
        string webGodotRoute;
        string webGodotShell;
        string webPackageJson;
        string webEnvExample;
        string netlifyConfig;
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
            webHomePage = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "app", "page.tsx"));
            webGodotRoute = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "app", "godot", "page.tsx"));
            webGodotShell = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "components", "godot-web-shell.tsx"));
            webPackageJson = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", "package.json"));
            webEnvExample = await File.ReadAllTextAsync(ResolveRepoFilePath("src", "web", ".env.example"));
            netlifyConfig = await File.ReadAllTextAsync(ResolveRepoFilePath("netlify.toml"));
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
            "Godot cabinet project must stay portrait, iconed, GL Compatibility based for desktop/web, and Mobile-rendered for Android",
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
                && project.Contains("renderer/rendering_method.mobile=\"mobile\"", StringComparison.Ordinal)
                && project.Contains("textures/vram_compression/import_etc2_astc=true", StringComparison.Ordinal));

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
                && exportPresets.Contains("architectures/x86_64=true", StringComparison.Ordinal)
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
            "Merged web shell must treat the exported Godot cabinet as the main Lucky5 surface and keep the React cabinet as fallback",
            webExportScript.Contains("--export-release", StringComparison.Ordinal)
                && webExportScript.Contains("$PresetName = 'Web'", StringComparison.Ordinal)
                && webExportScript.Contains("$OutputPath = 'src/web/public/godot-cabinet/index.html'", StringComparison.Ordinal)
                && webExportScript.Contains("lucky5.godot_web_export.v1", StringComparison.Ordinal)
                && webExportScript.Contains("entry_url = '/godot'", StringComparison.Ordinal)
                && webExportScript.Contains("asset_url = '/godot-cabinet/index.html'", StringComparison.Ordinal)
                && webHomePage.Contains("GodotWebShell", StringComparison.Ordinal)
                && webHomePage.Contains("dynamic = \"force-dynamic\"", StringComparison.Ordinal)
                && webHomePage.Contains("fallback={<Lucky5Cabinet />}", StringComparison.Ordinal)
                && webGodotShell.Contains("fs.existsSync(exportPath)", StringComparison.Ordinal)
                && webGodotShell.Contains("fallback", StringComparison.Ordinal)
                && webGodotShell.Contains("src=\"/godot-cabinet/index.html\"", StringComparison.Ordinal)
                && webGodotShell.Contains("Godot export missing", StringComparison.Ordinal)
                && webGodotRoute.Contains("dynamic = \"force-dynamic\"", StringComparison.Ordinal)
                && webGodotRoute.Contains("return <GodotWebShell />;", StringComparison.Ordinal)
                && webPackageJson.Contains("\"godot:export\"", StringComparison.Ordinal)
                && webPackageJson.Contains("Export-GodotWebCabinet.ps1", StringComparison.Ordinal)
                && gitIgnore.Contains("src/web/public/godot-cabinet/", StringComparison.Ordinal));

        Assert(
            failures,
            "Netlify web deploy scaffolding must pin the web base directory and document the backend origin env needed for hosted cabinet builds",
            netlifyConfig.Contains("base = \"src/web\"", StringComparison.Ordinal)
                && netlifyConfig.Contains("command = \"npm run build\"", StringComparison.Ordinal)
                && netlifyConfig.Contains("NODE_VERSION = \"20\"", StringComparison.Ordinal)
                && webEnvExample.Contains("LUCKY5_API_ORIGIN=", StringComparison.Ordinal)
                && webEnvExample.Contains("NEXT_PUBLIC_API_BASE=", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet store must normalize legacy v1 snapshots and legacy button IDs at the boundary",
            storeScript.Contains("func _normalize_snapshot", StringComparison.Ordinal)
                && storeScript.Contains("\"schema_version\": \"cabinet.v1\"", StringComparison.Ordinal)
                && storeScript.Contains("\"deal\": \"deal_draw\"", StringComparison.Ordinal)
                && storeScript.Contains("\"cancel\": \"cancel_hold\"", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet store must expose backend-advised holds so the cabinet command path matches the web auto-hold flow",
            storeScript.Contains("func advised_hold_indexes() -> Array:", StringComparison.Ordinal)
                && storeScript.Contains("hand.get(\"advised_holds\", [])", StringComparison.Ordinal)
                && storeScript.Contains("index >= 0 and index < 5", StringComparison.Ordinal));

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
                && rootScript.Contains("const DEAL_DURATION := 0.12", StringComparison.Ordinal)
                && rootScript.Contains("const DEAL_STAGGER := 0.10", StringComparison.Ordinal)
                && rootScript.Contains("const DRAW_OUT_DURATION := 0.08", StringComparison.Ordinal)
                && rootScript.Contains("const DRAW_IN_DURATION := 0.12", StringComparison.Ordinal)
                && rootScript.Contains("const DRAW_STAGGER := 0.10", StringComparison.Ordinal)
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
                && rootScript.Contains("AUTO-HOLD SUGGESTED - DRAW OR ADJUST", StringComparison.Ordinal)
                && rootScript.Contains("func _visual_hold_indexes() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("func _draw_hold_indexes() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("func _editable_hold_baseline() -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("store.advised_hold_indexes()", StringComparison.Ordinal)
                && rootScript.Contains("\"hold_indexes\": _draw_hold_indexes()", StringComparison.Ordinal)
                && rootScript.Contains("auto_holds_cancelled = true; _send_command(\"clear_holds\"", StringComparison.Ordinal));

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
            rootScript.Contains("const DOUBLE_UP_BOARD_SLOT_COUNT := 5", StringComparison.Ordinal)
                && rootScript.Contains("_build_du_deck_row(card_center)", StringComparison.Ordinal)
                && rootScript.Contains("func _build_du_deck_row(parent: Node) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("du_trail_container.name = \"DoubleUpDeckRow\"", StringComparison.Ordinal)
                && rootScript.Contains("du_trail_container.add_theme_constant_override(\"separation\", CARD_GAP)", StringComparison.Ordinal)
                && rootScript.Contains("var command_switched_dealer := (pending_command_type == \"double_up_switch\" or pending_command_type == \"swap_double_up_card\") and challenger_code.is_empty() and dealer_changed", StringComparison.Ordinal)
                && rootScript.Contains("_prepare_du_board(du_data, board_dealer_code, board_challenger_code, board_status, switch_replaced_dealer)", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_du_trail(du_data: Dictionary, dealer_code: String, challenger_code: String, status: String, dealer_replace_only: bool = false) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _du_visible_page_entries(du_data: Dictionary, dealer_code: String, challenger_code: String, slot_count: int) -> Array:", StringComparison.Ordinal)
                && rootScript.Contains("var page_entries := []", StringComparison.Ordinal)
                && rootScript.Contains("page_entries = _du_visible_page_entries(du_data, dealer_code, challenger_code, slot_count)", StringComparison.Ordinal)
                && rootScript.Contains("_set_du_board_back(slot_index, \"BIG / SMALL ?\", 1.0)", StringComparison.Ordinal)
                && rootScript.Contains("func _du_page_start_for_dealer_index(dealer_position: int, slot_count: int) -> int:", StringComparison.Ordinal)
                && rootScript.Contains("AI9 pages reuse the fifth card as slot 0 of the next deck row.", StringComparison.Ordinal)
                && rootScript.Contains("func _append_du_local_trail_entry(code: String, label_text: String = \"PLAYED\") -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _start_du_card_shuffle(new_dealer_code: String, new_player_code: String) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _start_du_dealer_replace_shuffle(new_dealer_code: String) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _process_du_shuffle() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("func _finish_du_card_shuffle() -> void:", StringComparison.Ordinal));

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
                && rootScript.Contains("return _format_amount(machine_credit_amount)", StringComparison.Ordinal)
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
                && storeScript.Contains("\"doubleup_switch\": \"double_up_switch\"", StringComparison.Ordinal)
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
        var ai9CabinetImageAssetNames = new[]
        {
            "ASX.png", "AHX.png", "ADX.png", "ACX.png",
            "machine2.png", "machine21.png", "menu.png", "splash.png",
        };
        var ai9CabinetAnimationAssetNames = new[]
        {
            "spinner.gif", "treasurecoins.gif", "treasureempty.gif",
        };

        Assert(
            failures,
            "Godot cabinet physical controls must use the same AI9Poker-style photographed button assets from the dedicated AI9 cabinet skin",
            rootScript.Contains("const BUTTON_ASSET_BASE_PATH := \"res://skins/cabinet_ai9/buttons/\"", StringComparison.Ordinal)
                && rootScript.Contains("func _apply_button_asset_styles(button: Button, asset_key: String) -> bool:", StringComparison.Ordinal)
                && rootScript.Contains("var style := StyleBoxTexture.new()", StringComparison.Ordinal)
                && rootScript.Contains("ResourceLoader.load(path) as Texture2D", StringComparison.Ordinal)
                && rootScript.Contains("var button_asset_textures: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("button_asset_textures[asset_name] = texture", StringComparison.Ordinal)
                && rootScript.Contains("button.set_meta(\"uses_ai9_button_asset\", true)", StringComparison.Ordinal)
                && rootScript.Contains("_make_button(\"HOLD\", CONTROL_HOLD_BUTTON_HEIGHT, COLOR_BUTTON_YELLOW, COLOR_BG, COLOR_GOLD_DARK, \"hold\")", StringComparison.Ordinal)
                && rootScript.Contains("return \"hold_off\"", StringComparison.Ordinal)
                && rootScript.Contains("return \"hold_on\"", StringComparison.Ordinal)
                && rootScript.Contains("var asset_key := str(def[0])", StringComparison.Ordinal)
                && rootScript.Contains("hold_button.text = \"HOLD\" if held else (\"\" if _button_uses_asset(hold_button) else (\"FH\" if fh_switch else \"HOLD\"))", StringComparison.Ordinal)
                && ai9ButtonAssetNames.All(name => RepoFileExists("godot", "cabinet", "skins", "cabinet_ai9", "buttons", name))
                && ai9CabinetImageAssetNames.All(name => RepoFileExists("godot", "cabinet", "skins", "cabinet_ai9", "images", name))
                && ai9CabinetAnimationAssetNames.All(name => RepoFileExists("godot", "cabinet", "skins", "cabinet_ai9", "animations", name)));

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
                && rootScript.Contains("func _add_machine_info_segment(row: HBoxContainer, title_text: String, separator_text: String, value_label: Label, expand := false) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("_add_machine_info_segment(hbox, \"KENT /3\", \" . \", machine_kent_label, true)", StringComparison.Ordinal)
                && rootScript.Contains("bonus_message_label = _make_label(\"4 OF A KIND   WINS BONUS\"", StringComparison.Ordinal)
                && rootScript.Contains("bonus_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL", StringComparison.Ordinal)
                && rootScript.Contains("machine_kent_label.text = str(_du_first_value(jackpots, [\"kent_streak\", \"kentStreak\", \"KentStreak\"], machine.get(\"machine_kent\", \"0\")))", StringComparison.Ordinal)
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
                && rootScript.Contains("const BONUS_COIN_SIZE := Vector2(28, 28)", StringComparison.Ordinal)
                && rootScript.Contains("var bonus_stage_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("var bonus_stage_amount_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("bonus_stage_label = _make_label(\"FREE GAMES\", 13, COLOR_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)", StringComparison.Ordinal)
                && rootScript.Contains("bonus_stage_amount_label = _make_label(\"BONUS 0\", 13, COLOR_RED, HORIZONTAL_ALIGNMENT_RIGHT)", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_bonus_stage() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("var bonus: Dictionary = _bonus_presentation()", StringComparison.Ordinal)
                && rootScript.Contains("func _fallback_bonus_presentation() -> Dictionary:", StringComparison.Ordinal)
                && rootScript.Contains("store.hand_rank() == \"FourOfAKind\"", StringComparison.Ordinal)
                && rootScript.Contains("bonus_stage_label.visible = active", StringComparison.Ordinal)
                && rootScript.Contains("bonus_stage_amount_label.visible = active", StringComparison.Ordinal)
                && rootScript.Contains("\"FREE GAMES %03d\"", StringComparison.Ordinal)
                && rootScript.Contains("bonus_message_label.text = message if active else \"4 OF A KIND   WINS BONUS\"", StringComparison.Ordinal)
                && rootScript.Contains("const CABINET_AI9_SKIN_ROOT := \"res://skins/cabinet_ai9/\"", StringComparison.Ordinal)
                && rootScript.Contains("func _load_cabinet_skin_resources() -> void:", StringComparison.Ordinal)
                && rootScript.Contains("arcade_font = _load_cabinet_font(\"fonts/ARCADE.ttf\")", StringComparison.Ordinal)
                && rootScript.Contains("press_sound = _load_cabinet_audio(CABINET_PRESS_SOUND)", StringComparison.Ordinal)
                && RepoFileExists("godot", "cabinet", "skins", "cabinet_ai9", "images", "coin.png"));

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
                && rootScript.Contains("[\"SF\", \"sf\", COLOR_GOLD]", StringComparison.Ordinal)
                && rootScript.Contains("[\"*\", \"4k-b\", COLOR_GREEN_DIM]", StringComparison.Ordinal)
                && !rootScript.Contains("[\"FH\", \"fh\"", StringComparison.Ordinal)
                && rootScript.Contains("jackpot_counter_panels[str(slot[1])] = counter_panel", StringComparison.Ordinal)
                && rootScript.Contains("_set_jackpot_counter_active(\"4k-a\", active_4k == \"A\")", StringComparison.Ordinal)
                && rootScript.Contains("_set_jackpot_counter_active(\"4k-b\", active_4k == \"B\")", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet jackpot counters must animate live trickles and visible jackpot drains instead of snapping meter values",
            rootScript.Contains("const JACKPOT_TRICKLE_DURATION := 0.30", StringComparison.Ordinal)
                && rootScript.Contains("const JACKPOT_DRAIN_DURATION := 2.80", StringComparison.Ordinal)
                && rootScript.Contains("var displayed_jackpots: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var jackpot_counter_tweens: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("func _animate_jackpot_counter(slot_key: String, from_value: int, to_value: int) -> void:", StringComparison.Ordinal)
                && rootScript.Contains("to_value < from_value", StringComparison.Ordinal)
                && rootScript.Contains("tween_method(Callable(self, \"_set_jackpot_counter_display\").bind(slot_key)", StringComparison.Ordinal)
                && rootScript.Contains("func _set_jackpot_counter_display(value: float, slot_key: String) -> void:", StringComparison.Ordinal));

        Assert(
            failures,
"Godot cabinet idle screen must show the armed Full House rank as the middle card like the reference cabinet",
            rootScript.Contains("var show_idle_rank_card := game_state == \"idle\" and not du_active and cards.is_empty()", StringComparison.Ordinal)
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
