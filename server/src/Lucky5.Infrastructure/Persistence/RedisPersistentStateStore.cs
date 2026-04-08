using System.Text.Json;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Lucky5.Infrastructure.Persistence;

/// <summary>
/// Redis-backed snapshot store implemented via IDistributedCache to keep the live web host simple.
/// The durable image remains versioned and self-describing so startup can reject stale or incompatible data.
/// </summary>
public sealed class RedisPersistentStateStore : IPersistentStateStore
{
    private readonly IDistributedCache cache;
    private readonly IOptions<PersistentStateCheckpointOptions> options;
    private readonly ILogger<RedisPersistentStateStore> logger;
    private readonly JsonSerializerOptions jsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false
    };

    public RedisPersistentStateStore(
        IDistributedCache cache,
        IOptions<PersistentStateCheckpointOptions> options,
        ILogger<RedisPersistentStateStore> logger)
    {
        this.cache = cache;
        this.options = options;
        this.logger = logger;
    }

    public async Task<PersistentStateSnapshot?> LoadAsync(CancellationToken cancellationToken)
    {
        var payload = await cache.GetStringAsync(options.Value.SnapshotKey, cancellationToken);
        if (string.IsNullOrWhiteSpace(payload))
        {
            return null;
        }

        var snapshot = JsonSerializer.Deserialize<PersistentStateSnapshot>(payload, jsonOptions);
        if (snapshot is null)
        {
            return null;
        }

        if (snapshot.SchemaVersion != PersistentStateSnapshot.CurrentSchemaVersion)
        {
            throw new InvalidOperationException(
                $"Persistent state schema mismatch. Expected v{PersistentStateSnapshot.CurrentSchemaVersion}, got v{snapshot.SchemaVersion}.");
        }

        return snapshot;
    }

    public async Task SaveAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken)
    {
        var payload = JsonSerializer.Serialize(snapshot, jsonOptions);
        await cache.SetStringAsync(options.Value.SnapshotKey, payload, cancellationToken);
        logger.LogInformation("Persistent state checkpoint saved at {CapturedUtc} using schema v{SchemaVersion}.", snapshot.CapturedUtc, snapshot.SchemaVersion);
    }

    public async Task<PersistentStoreHealth> GetHealthAsync(CancellationToken cancellationToken)
    {
        try
        {
            _ = await cache.GetStringAsync(options.Value.SnapshotKey, cancellationToken);
            return new PersistentStoreHealth(
                IsReady: true,
                IsDegraded: false,
                Description: "Redis snapshot store reachable.",
                LastSuccessfulCheckpointUtc: null,
                LastError: null);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Redis snapshot store is unavailable.");
            return new PersistentStoreHealth(
                IsReady: false,
                IsDegraded: true,
                Description: "Redis snapshot store unavailable; service should remain live in graceful degradation mode.",
                LastSuccessfulCheckpointUtc: null,
                LastError: ex.Message);
        }
    }
}
