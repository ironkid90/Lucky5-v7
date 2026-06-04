namespace Lucky5.Tests;

public static class GodotCabinetRegressionTests
{
    public static async Task RunAsync(List<string> failures)
    {
        string project;
        string mainScene;
        string rootScript;
        string storeScript;
        string apiScript;
        string cardSkinScript;
        string devScript;
        try
        {
            project = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "project.godot"));
            mainScene = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scenes", "CabinetRoot.tscn"));
            rootScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_root.gd"));
            storeScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_store.gd"));
            apiScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "scripts", "cabinet_api.gd"));
            cardSkinScript = await File.ReadAllTextAsync(ResolveRepoFilePath("godot", "cabinet", "skins", "lucky5", "CardSkin_Lucky5.gd"));
            devScript = await File.ReadAllTextAsync(ResolveRepoFilePath("dev.ps1"));
        }
        catch (Exception ex)
        {
            failures.Add($"Godot cabinet regression setup failed: {ex.Message}");
            return;
        }

        Assert(
            failures,
            "Godot cabinet project must launch CabinetRoot.tscn as the playable main scene",
            project.Contains("run/main_scene=\"res://scenes/CabinetRoot.tscn\"", StringComparison.Ordinal));

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
            "dev.ps1 must launch the Godot cabinet by default and keep the legacy web cabinet behind an explicit -Web fallback",
            devScript.Contains("[switch]$Web", StringComparison.Ordinal)
                && devScript.Contains("$launchGodot = -not $Headless -and -not $Web", StringComparison.Ordinal)
                && devScript.Contains("Start-Process -FilePath $GodotBin", StringComparison.Ordinal)
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
            "Godot cabinet must reveal dealt and drawn cards through a sequential arcade deal queue instead of replacing the full hand at once",
            rootScript.Contains("func _queue_card_reveal", StringComparison.Ordinal)
                && rootScript.Contains("func _show_queued_card", StringComparison.Ordinal)
                && rootScript.Contains("deal_queue.append", StringComparison.Ordinal)
                && rootScript.Contains("deal_timer.start", StringComparison.Ordinal)
                && rootScript.Contains("_process_deal_queue", StringComparison.Ordinal)
                && rootScript.Contains("var previous_code: String = previous_codes[index] if index < previous_codes.size() else \"\"", StringComparison.Ordinal)
                && !rootScript.Contains("func _process_deal_queue() -> void: pass", StringComparison.Ordinal));

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
            "Godot cabinet double-up must use the arcade presentation: large centered challenger, small dealer reference, rapid card shuffle, and backend card trail",
            rootScript.Contains("const DU_MAIN_CARD_SIZE := Vector2(150, 210)", StringComparison.Ordinal)
                && rootScript.Contains("const DU_SHUFFLE_INTERVAL := 0.08", StringComparison.Ordinal)
                && rootScript.Contains("var du_shuffle_timer: Timer", StringComparison.Ordinal)
                && rootScript.Contains("du_shuffle_timer.timeout.connect(_process_du_shuffle)", StringComparison.Ordinal)
                && rootScript.Contains("du_challenger_rect.custom_minimum_size = DU_MAIN_CARD_SIZE", StringComparison.Ordinal)
                && !rootScript.Contains("var vs_label := _make_label(\"VS\"", StringComparison.Ordinal)
                && rootScript.Contains("func _start_du_card_shuffle", StringComparison.Ordinal)
                && rootScript.Contains("func _process_du_shuffle", StringComparison.Ordinal)
                && rootScript.Contains("func _finish_du_card_shuffle", StringComparison.Ordinal)
                && rootScript.Contains("du_shuffle_timer.start", StringComparison.Ordinal)
                && rootScript.Contains("func _refresh_du_trail", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_du_trail(du_data)", StringComparison.Ordinal)
                && rootScript.Contains("du_data.get(\"card_trail\", [])", StringComparison.Ordinal));

        Assert(
            failures,
            "Godot cabinet must expose the AI9Poker-style physical control deck and route double-up switch through BET",
            rootScript.Contains("var hold_buttons: Array = []", StringComparison.Ordinal)
                && rootScript.Contains("var menu_panel: VBoxContainer", StringComparison.Ordinal)
                && rootScript.Contains("func _build_control_deck", StringComparison.Ordinal)
                && rootScript.Contains("func _build_menu_panel", StringComparison.Ordinal)
                && rootScript.Contains("[\"big\", \"BIG\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"small\", \"SMALL\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"cancel_hold\", \"CANCEL\\nHOLD\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"deal_draw\", \"DEAL\\nDRAW\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"bet\", \"BET\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"take_half\", \"TAKE\\nHALF\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"menu\", \"MENU\"", StringComparison.Ordinal)
                && rootScript.Contains("[\"take_score\", \"TAKE\\nSCORE\"", StringComparison.Ordinal)
                && rootScript.Contains("_on_hold_button_pressed.bind(index)", StringComparison.Ordinal)
                && rootScript.Contains("if store.game_state() == \"double_up\" and store.can_press(\"swap_double_up_card\"):", StringComparison.Ordinal)
                && rootScript.Contains("_send_command(\"swap_double_up_card\"", StringComparison.Ordinal)
                && !rootScript.Contains("[\"swap_double_up_card\", \"SWAP\\nCARD\"", StringComparison.Ordinal));

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
            "Godot cabinet paytable must mirror AI9Poker with dynamic stake payouts plus a solid Full House rank jackpot selection tag",
            rootScript.Contains("var paytable_rows: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var paytable_amount_labels: Dictionary = {}", StringComparison.Ordinal)
                && rootScript.Contains("var full_house_rank_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("var full_house_jackpot_label: Label", StringComparison.Ordinal)
                && rootScript.Contains("paytable_rows[str(hand[0])] = row_panel", StringComparison.Ordinal)
                && rootScript.Contains("paytable_amount_labels[str(hand[0])] = amount_l", StringComparison.Ordinal)
                && rootScript.Contains("full_house_rank_label.text = _full_house_rank_text()", StringComparison.Ordinal)
                && rootScript.Contains("full_house_jackpot_label.text = _format_amount(jp.get(\"full_house\", 0))", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_paytable_values()", StringComparison.Ordinal)
                && rootScript.Contains("_refresh_paytable_highlights()", StringComparison.Ordinal));

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
"Godot cabinet idle screen must show the armed Full House rank as the middle card like the reference cabinet",
            rootScript.Contains("var show_idle_rank_card := game_state == \"idle\" and not du_active and cards.is_empty()", StringComparison.Ordinal)
                && rootScript.Contains("if show_idle_rank_card and index == 2:", StringComparison.Ordinal)
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

    private static void Assert(List<string> failures, string message, bool condition)
    {
        if (!condition)
        {
            failures.Add(message);
        }
    }
}
