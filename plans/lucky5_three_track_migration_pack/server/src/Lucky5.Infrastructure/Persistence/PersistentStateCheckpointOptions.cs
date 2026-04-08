namespace Lucky5.Infrastructure.Persistence;

public sealed class PersistentStateCheckpointOptions
{
    public static readonly TimeSpan DefaultCheckpointInterval = TimeSpan.FromSeconds(10);

    public TimeSpan CheckpointInterval { get; set; } = DefaultCheckpointInterval;
    public bool GracefulDegradationEnabled { get; set; } = true;
    public string SnapshotKey { get; set; } = "lucky5:persistent-state:v2";
}
