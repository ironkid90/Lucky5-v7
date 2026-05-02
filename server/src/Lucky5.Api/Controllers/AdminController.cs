namespace Lucky5.Api.Controllers;

using Lucky5.Api.Models;
using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Domain.Entities;
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/[controller]")]
public sealed class AdminController(IAdminService adminService) : ControllerBase
{
    [HttpGet("users")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AdminUserDto>>>> ListUsers(CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        var users = await adminService.ListUsersAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<AdminUserDto>>.Ok(users, traceId: HttpContext.TraceIdentifier));
    }

    [HttpGet("users/search")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AdminUserDto>>>> SearchUsers([FromQuery] string q, CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        if (string.IsNullOrWhiteSpace(q)) return BadRequest(ApiResponse<IReadOnlyList<AdminUserDto>>.Fail("Query parameter 'q' is required", traceId: HttpContext.TraceIdentifier));
        var users = await adminService.SearchUsersAsync(q, cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<AdminUserDto>>.Ok(users, traceId: HttpContext.TraceIdentifier));
    }

    [HttpGet("users/{userId:guid}")]
    public async Task<ActionResult<ApiResponse<AdminUserDto>>> GetUser(Guid userId, CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        var user = await adminService.GetUserAsync(userId, cancellationToken);
        return Ok(ApiResponse<AdminUserDto>.Ok(user, traceId: HttpContext.TraceIdentifier));
    }

    [HttpPost("users/credit")]
    public async Task<ActionResult<ApiResponse<WalletLedgerEntryDto>>> Credit([FromBody] AdminCreditRequest request, CancellationToken cancellationToken)
    {
        var adminId = HttpContext.RequireAdminRole();
        var row = await adminService.AdminCreditAsync(adminId, request, cancellationToken);
        return Ok(ApiResponse<WalletLedgerEntryDto>.Ok(row, traceId: HttpContext.TraceIdentifier));
    }

    [HttpGet("machines")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<AdminMachineDto>>>> ListMachines(CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        var machines = await adminService.ListMachinesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<AdminMachineDto>>.Ok(machines, traceId: HttpContext.TraceIdentifier));
    }

    [HttpGet("machines/{machineId:int}")]
    public async Task<ActionResult<ApiResponse<AdminMachineDto>>> GetMachine(int machineId, CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        var machine = await adminService.GetMachineAsync(machineId, cancellationToken);
        return Ok(ApiResponse<AdminMachineDto>.Ok(machine, traceId: HttpContext.TraceIdentifier));
    }

    [HttpPost("machines/{machineId:int}/reset")]
    public async Task<ActionResult<ApiResponse<AdminMachineDto>>> ResetMachine(int machineId, CancellationToken cancellationToken)
    {
        var adminId = HttpContext.RequireAdminRole();
        var machine = await adminService.ResetMachineAsync(adminId, machineId, cancellationToken);
        return Ok(ApiResponse<AdminMachineDto>.Ok(machine, traceId: HttpContext.TraceIdentifier));
    }

    [HttpPost("machines/{machineId:int}/door-state")]
    public async Task<ActionResult<ApiResponse<DoorState>>> SetDoorState(int machineId, [FromBody] SetDoorStateRequest request, CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        var doorState = await adminService.SetDoorStateAsync(machineId, request.DoorState, cancellationToken);
        return Ok(ApiResponse<DoorState>.Ok(doorState, traceId: HttpContext.TraceIdentifier));
    }

    [HttpPost("users/recharge-bonus")]
    public async Task<ActionResult<ApiResponse<WalletLedgerEntryDto>>> RechargeBonus([FromBody] RechargeBonusRequest request, CancellationToken cancellationToken)
    {
        HttpContext.RequireAdminRole();
        var row = await adminService.RechargeBonusAsync(request.UserId, request.RechargeAmount, cancellationToken);
        return Ok(ApiResponse<WalletLedgerEntryDto>.Ok(row, traceId: HttpContext.TraceIdentifier));
    }
}
