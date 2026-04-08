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
        try
        {
            var json = await cache.GetStringAsync(options.Value.SnapshotKey, cancellationToken);
            if (string.IsNullOrWhiteSpace(json))
            {
                logger.LogWarning("No snapshot found in Redis at key {Key}", options.Value.SnapshotKey);
                return null;
            }

            var snapshot = JsonSerializer.Deserialize<PersistentStateSnapshot>(json, jsonOptions);
            if (snapshot == null)
            {
                logger.LogWarning("Failed to deserialize snapshot from Redis at key {Key}", options.Value.SnapshotKey);
                return null;
            }

            if (snapshot.SchemaVersion != PersistentStateSnapshot.CurrentSchemaVersion)
            {
                logger.LogError("Schema mismatch: expected {Expected}, found {Found}", PersistentStateSnapshot.CurrentSchemaVersion, snapshot.SchemaVersion);
                throw new InvalidOperationException($"Schema mismatch: expected {PersistentStateSnapshot.CurrentSchemaVersion}, found {snapshot.SchemaVersion}");
            }

            logger.LogInformation("Successfully loaded snapshot from Redis with {UserCount} users, {SessionCount} sessions", snapshot.Users.Count, snapshot.MachineSessions.Count);
            return snapshot;
        }
        catch (Exception ex) when (ex is InvalidOperationException || ex is JsonException)
        {
            logger.LogError(ex, "Failed to load snapshot from Redis due to data error");
            throw;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to load snapshot from Redis - returning null");
            return null;
        }
    }

    public async Task SaveAsync(PersistentStateSnapshot snapshot, CancellationToken cancellationToken)
    {
        try
        {
            var payload = JsonSerializer.Serialize(snapshot, jsonOptions);
            await cache.SetStringAsync(options.Value.SnapshotKey, payload, cancellationToken);
            logger.LogInformation("Persistent state checkpoint saved at {CapturedUtc} using schema v{SchemaVersion}.", snapshot.CapturedUtc, snapshot.SchemaVersion);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to save snapshot to Redis");
        }
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
                LastSuccessfulCheckpointUtc: DateTime.UtcNow,
                LastError: null);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Redis health check failed - marking as degraded");
            return new PersistentStoreHealth(
                IsReady: false,
                IsDegraded: true,
                Description: "Redis snapshot store unavailable - service running on in-memory state.",
                LastSuccessfulCheckpointUtc: null,
                LastError: ex.Message);
        }
    }
}
