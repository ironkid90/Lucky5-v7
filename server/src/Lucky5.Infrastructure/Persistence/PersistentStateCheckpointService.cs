using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Lucky5.Infrastructure.Persistence;

/// <summary>
/// Periodically checkpoints authoritative in-memory state into the durable store.
/// The interval is hard-pinned to 10 seconds by default per the migration target.
/// </summary>
public sealed class PersistentStateCheckpointService : BackgroundService
{
    private readonly IPersistentStateCoordinator coordinator;
    private readonly IPersistentStateStore store;
    private readonly IOptions<PersistentStateCheckpointOptions> options;
    private readonly ILogger<PersistentStateCheckpointService> logger;
    private DateTimeOffset? lastSuccessfulCheckpointUtc;
    private string? lastError;

    public PersistentStateCheckpointService(
        IPersistentStateCoordinator coordinator,
        IPersistentStateStore store,
        IOptions<PersistentStateCheckpointOptions> options,
        ILogger<PersistentStateCheckpointService> logger)
    {
        this.coordinator = coordinator;
        this.store = store;
        this.options = options;
        this.logger = logger;
    }

    public DateTimeOffset? LastSuccessfulCheckpointUtc => lastSuccessfulCheckpointUtc;
    public string? LastError => lastError;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(options.Value.CheckpointInterval);
        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                var snapshot = await coordinator.CaptureAsync(stoppingToken);
                await store.SaveAsync(snapshot with { SchemaVersion = PersistentStateSnapshot.CurrentSchemaVersion }, stoppingToken);
                lastSuccessfulCheckpointUtc = DateTimeOffset.UtcNow;
                lastError = null;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                lastError = ex.Message;
                logger.LogError(ex, "Persistent checkpoint failed.");

                if (!options.Value.GracefulDegradationEnabled)
                {
                    throw;
                }
            }
        }
    }
}
