namespace Lucky5.Application.Dtos;

using System.Text.Json.Serialization;

public sealed record CabinetSnapshotDto(
    [property: JsonPropertyName("schema_version")]
    string SchemaVersion,
    [property: JsonPropertyName("state_version")]
    long StateVersion,
    [property: JsonPropertyName("session_id")]
    Guid? SessionId,
    [property: JsonPropertyName("machine_id")]
    int MachineId,
    [property: JsonPropertyName("variant_id")]
    string VariantId,
    [property: JsonPropertyName("game_state")]
    string GameState,
    CabinetHandDto Hand,
    CabinetEvaluationDto Evaluation,
    [property: JsonPropertyName("double_up")]
    CabinetDoubleUpDto DoubleUp,
    CabinetCreditsDto Credits,
    CabinetJackpotDto Jackpot,
    [property: JsonPropertyName("ui_hints")]
    CabinetUiHintsDto UiHints,
    DateTime Timestamp,
    [property: JsonPropertyName("sequence_number")]
    long SequenceNumber);

public sealed record CabinetHandDto(
    IReadOnlyList<PokerCardDto> Cards,
    IReadOnlyList<int> Held,
    [property: JsonPropertyName("result_cards")]
    IReadOnlyList<PokerCardDto> ResultCards);

public sealed record CabinetEvaluationDto(
    [property: JsonPropertyName("hand_rank")]
    string HandRank,
    [property: JsonPropertyName("payout_multiplier")]
    decimal PayoutMultiplier,
    [property: JsonPropertyName("win_amount")]
    decimal WinAmount);

public sealed record CabinetDoubleUpDto(
    bool Active,
    [property: JsonPropertyName("card_revealed")]
    bool CardRevealed,
    string Outcome,
    [property: JsonPropertyName("dealer_card")]
    PokerCardDto? DealerCard,
    [property: JsonPropertyName("challenger_card")]
    PokerCardDto? ChallengerCard,
    [property: JsonPropertyName("switches_remaining")]
    int SwitchesRemaining,
    [property: JsonPropertyName("is_no_lose_active")]
    bool IsNoLoseActive,
    [property: JsonPropertyName("card_trail")]
    IReadOnlyList<PokerCardDto> CardTrail);

public sealed record CabinetCreditsDto(
    decimal Balance,
    decimal Bet,
    [property: JsonPropertyName("total_won")]
    decimal TotalWon,
    decimal Denomination);

public sealed record CabinetJackpotDto(
    [property: JsonPropertyName("current_values")]
    IReadOnlyDictionary<string, decimal> CurrentValues,
    [property: JsonPropertyName("last_hit")]
    string LastHit,
    [property: JsonPropertyName("full_house_rank")]
    int FullHouseRank,
    [property: JsonPropertyName("active_four_of_a_kind_slot")]
    int ActiveFourOfAKindSlot,
    [property: JsonPropertyName("machine_serial")]
    string MachineSerial,
    [property: JsonPropertyName("machine_serie")]
    string MachineSerie,
    [property: JsonPropertyName("machine_kent")]
    string MachineKent);

public sealed record CabinetUiHintsDto(
    [property: JsonPropertyName("enabled_buttons")]
    IReadOnlyList<string> EnabledButtons,
    [property: JsonPropertyName("animation_cue")]
    string AnimationCue,
    string Message,
    [property: JsonPropertyName("bonus_message")]
    string BonusMessage,
    [property: JsonPropertyName("idle_title_visible")]
    bool IdleTitleVisible);

public sealed record CabinetEventDto(
    [property: JsonPropertyName("schema_version")]
    string SchemaVersion,
    [property: JsonPropertyName("event_type")]
    string EventType,
    IReadOnlyDictionary<string, object?> Payload,
    [property: JsonPropertyName("sequence_number")]
    long SequenceNumber,
    DateTime Timestamp);

public sealed record CabinetCommandDto(
    [property: JsonPropertyName("schema_version")]
    string SchemaVersion,
    [property: JsonPropertyName("command_id")]
    Guid CommandId,
    [property: JsonPropertyName("command_type")]
    string CommandType,
    [property: JsonPropertyName("session_id")]
    Guid? SessionId,
    [property: JsonPropertyName("machine_id")]
    int MachineId,
    [property: JsonPropertyName("expected_state_version")]
    long ExpectedStateVersion,
    [property: JsonPropertyName("idempotency_key")]
    string IdempotencyKey,
    IReadOnlyDictionary<string, object?> Payload,
    DateTime Timestamp);

public sealed record VariantDefinitionDto(
    [property: JsonPropertyName("schema_version")]
    string SchemaVersion,
    [property: JsonPropertyName("variant_id")]
    string VariantId,
    [property: JsonPropertyName("display_name")]
    string DisplayName,
    string Description,
    [property: JsonPropertyName("variant_schema_version")]
    string VariantSchemaVersion,
    [property: JsonPropertyName("ruleset_version")]
    string RulesetVersion,
    IReadOnlyDictionary<string, object?> Rules,
    IReadOnlyDictionary<string, decimal> Paytable,
    [property: JsonPropertyName("paytable_hash")]
    string PaytableHash,
    [property: JsonPropertyName("rtp_model_version")]
    string RtpModelVersion,
    [property: JsonPropertyName("double_up_profile")]
    DoubleUpProfileDto DoubleUpProfile,
    [property: JsonPropertyName("cabinet_skin")]
    CabinetSkinDto CabinetSkin,
    [property: JsonPropertyName("presentation_profile")]
    PresentationProfileDto PresentationProfile,
    [property: JsonPropertyName("machine_policy")]
    MachinePolicyProfileDto MachinePolicy,
    VariantGovernanceDto Governance);

public sealed record DoubleUpProfileDto(
    bool Enabled,
    [property: JsonPropertyName("max_attempts")]
    int MaxAttempts,
    [property: JsonPropertyName("card_count")]
    int CardCount,
    [property: JsonPropertyName("house_edge")]
    decimal HouseEdge);

public sealed record CabinetSkinDto(
    [property: JsonPropertyName("theme_id")]
    string ThemeId,
    [property: JsonPropertyName("asset_pack")]
    string AssetPack,
    [property: JsonPropertyName("color_palette")]
    IReadOnlyDictionary<string, string> ColorPalette);

public sealed record PresentationProfileDto(
    [property: JsonPropertyName("animation_set")]
    string AnimationSet,
    [property: JsonPropertyName("sound_pack")]
    string SoundPack,
    [property: JsonPropertyName("pacing_config")]
    IReadOnlyDictionary<string, int> PacingConfig);

public sealed record MachinePolicyProfileDto(
    [property: JsonPropertyName("min_bet")]
    decimal MinBet,
    [property: JsonPropertyName("max_bet")]
    decimal MaxBet,
    decimal Denomination,
    [property: JsonPropertyName("rtp_target")]
    decimal RtpTarget);

public sealed record VariantGovernanceDto(
    [property: JsonPropertyName("approved_by")]
    string ApprovedBy,
    [property: JsonPropertyName("approved_at")]
    DateTime ApprovedAt,
    [property: JsonPropertyName("simulation_report_id")]
    string SimulationReportId,
    [property: JsonPropertyName("enabled_for_production")]
    bool EnabledForProduction,
    [property: JsonPropertyName("migration_notes")]
    string MigrationNotes);
