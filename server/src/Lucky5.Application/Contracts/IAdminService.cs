namespace Lucky5.Application.Contracts;

using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;

public interface IAdminService
{
    Task<IReadOnlyList<AdminUserDto>> ListUsersAsync(CancellationToken cancellationToken);
    Task<IReadOnlyList<AdminUserDto>> SearchUsersAsync(string query, CancellationToken cancellationToken);
    Task<AdminUserDto> GetUserAsync(Guid userId, CancellationToken cancellationToken);
    Task<WalletLedgerEntryDto> AdminCreditAsync(Guid adminId, AdminCreditRequest request, CancellationToken cancellationToken);
    Task<IReadOnlyList<AdminMachineDto>> ListMachinesAsync(CancellationToken cancellationToken);
    Task<AdminMachineDto> GetMachineAsync(int machineId, CancellationToken cancellationToken);
    Task<AdminMachineDto> ResetMachineAsync(Guid adminId, int machineId, CancellationToken cancellationToken);
}
