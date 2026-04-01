using Lucky5.Application.Contracts;
using Lucky5.Application.Dtos;
using Lucky5.Application.Requests;
using Lucky5.Domain.Game.CleanRoom;
using Lucky5.Domain.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Lucky5.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GameController(IGameService gameService, IAdminService adminService, ILogger<GameController> logger) : ControllerBase
{
    private Guid UserId => Guid.Parse(User.FindFirst("sub")?.Value ?? throw new UnauthorizedAccessException());

    [HttpGet("machines")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<MachineListingDto>>>> GetMachines(CancellationToken cancellationToken)
    {
        var machines = await gameService.GetMachinesAsync(cancellationToken);
        return Ok(ApiResponse<IReadOnlyList<MachineListingDto>>.Ok(machines, traceId: HttpContext.TraceIdentifier));
    }

    [HttpGet("rules")]
    public async Task<ActionResult<ApiResponse<DefaultRulesDto>>> GetRules(CancellationToken cancellationToken)
    {
        var rules = await gameService.GetDefaultRulesAsync(cancellationToken);
        return Ok(ApiResponse<DefaultRulesDto>.Ok(rules, traceId: HttpContext.TraceIdentifier));
    }

    [HttpGet("active-round/{machineId}")]
    public async Task<ActionResult<ApiResponse<ActiveRoundStateDto?>>> GetActiveRound(int machineId, CancellationToken cancellationToken)
    {
        var result = await gameService.GetActiveRoundAsync(UserId, machineId, cancellationToken);
        return Ok(new ApiResponse<ActiveRoundStateDto?>(true, "OK", result, [], HttpContext.TraceIdentifier));
    }

    [HttpPost("deal")]
    public async Task<ActionResult<ApiResponse<DealResultDto>>> Deal([FromBody] DealRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.DealAsync(UserId, request, cancellationToken);
            return Ok(ApiResponse<DealResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DealResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpPost("draw")]
    public async Task<ActionResult<ApiResponse<DrawResultDto>>> Draw([FromBody] DrawRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.DrawAsync(UserId, request, cancellationToken);
            return Ok(ApiResponse<DrawResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DrawResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpPost("double-up/start")]
    public async Task<ActionResult<ApiResponse<DoubleUpResultDto>>> StartDoubleUp([FromBody] StartDoubleUpRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.StartDoubleUpAsync(UserId, request.RoundId, cancellationToken);
            return Ok(ApiResponse<DoubleUpResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DoubleUpResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpPost("double-up/guess")]
    public async Task<ActionResult<ApiResponse<DoubleUpResultDto>>> GuessDoubleUp([FromBody] DoubleUpRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.GuessDoubleUpAsync(UserId, request.RoundId, request.Guess, cancellationToken);
            return Ok(ApiResponse<DoubleUpResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DoubleUpResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpPost("double-up/switch")]
    public async Task<ActionResult<ApiResponse<DoubleUpResultDto>>> SwitchDealer([FromBody] SwitchDealerRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.SwitchDealerAsync(UserId, request.RoundId, cancellationToken);
            return Ok(ApiResponse<DoubleUpResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DoubleUpResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpPost("double-up/take-half")]
    public async Task<ActionResult<ApiResponse<DoubleUpResultDto>>> TakeHalf([FromBody] TakeHalfRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.TakeHalfAsync(UserId, request.RoundId, cancellationToken);
            return Ok(ApiResponse<DoubleUpResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DoubleUpResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpPost("double-up/cashout")]
    public async Task<ActionResult<ApiResponse<DoubleUpResultDto>>> CashoutDoubleUp([FromBody] CashoutDoubleUpRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var result = await gameService.CashoutDoubleUpAsync(UserId, request.RoundId, cancellationToken);
            return Ok(ApiResponse<DoubleUpResultDto>.Ok(result, traceId: HttpContext.TraceIdentifier));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ApiResponse<DoubleUpResultDto>(false, ex.Message, null, [], HttpContext.TraceIdentifier));
        }
    }

    [HttpGet("machine/{id}/state")]
    public async Task<ActionResult<object>> MachineState(int id, CancellationToken cancellationToken)
    {
        var result = await gameService.GetMachineStateAsync(id, cancellationToken);
        return Ok(result);
    }
}
