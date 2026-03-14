namespace Lucky5.Application.Requests;

public sealed record AdminCreditRequest(
    Guid TargetUserId,
    decimal Amount,
    string Reason);
