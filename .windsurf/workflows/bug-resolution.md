---
name: Bug Resolution Workflow
description: Systematic approach to fixing Lucky5 game bugs
version: 1.0.0
author: Kade Orchestrator
tags: [bug-fixing, debugging, quality-assurance]
---

# Bug Resolution Workflow

This workflow provides a systematic approach to identifying, analyzing, and fixing bugs in the Lucky5 video poker game.

## Mission Breakdown

### Mission 1: Bug Analysis
**Agent Profile**: Debug Specialist  
**Mode**: Focus  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] Reproduce bug consistently
- [ ] Identify root cause using debugging tools
- [ ] Analyze impact scope on game systems
- [ ] Document bug reproduction steps
- [ ] Assess priority and risk level

#### Debugging Commands:
```bash
# Run local server for debugging
dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj

# Check build status
dotnet build server/Lucky5.sln -v minimal

# Run tests to identify failing areas
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

#### Context Files:
- `server/src/Lucky5.Infrastructure/Services/GameService.cs` - Game logic
- `server/src/Lucky5.Domain/Game/CleanRoom/` - Game engine
- `server/tests/` - Test cases

---

### Mission 2: Fix Implementation
**Agent Profile**: Backend Developer  
**Mode**: Collaborate  
**Estimated Time**: 4 hours

#### Tasks:
- [ ] Develop fix for identified issue
- [ ] Add regression tests to prevent recurrence
- [ ] Update related documentation
- [ ] Verify fix doesn't break existing functionality
- [ ] Code review and optimization

#### Key Considerations:
- Maintain CleanRoom architecture principles
- Preserve game state integrity
- Ensure SignalR real-time updates work correctly
- Follow existing code patterns and conventions

---

### Mission 3: Validation & Testing
**Agent Profile**: QA Specialist  
**Mode**: Review  
**Estimated Time**: 3 hours

#### Tasks:
- [ ] Run full test suite
- [ ] Manual gameplay testing
- [ ] Performance impact assessment
- [ ] Cross-platform compatibility check
- [ ] Documentation verification

#### Testing Commands:
```bash
# Full smoke test
pwsh scripts/smoke-api.ps1

# Local development stack
docker compose -f infra/docker-compose.yml up

# Test deployment locally
dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj
```

---

## Common Bug Categories

### Game Logic Issues
- **Location**: `server/src/Lucky5.Domain/Game/CleanRoom/`
- **Common Issues**: Card dealing logic, payout calculations, hand evaluation
- **Debug Strategy**: Add logging to game engine, verify deterministic behavior

### Real-time/SignalR Issues
- **Location**: `server/src/Lucky5.Realtime/`
- **Common Issues**: Connection drops, state synchronization, message delivery
- **Debug Strategy**: Check hub connections, monitor WebSocket traffic

### API/Backend Issues
- **Location**: `server/src/Lucky5.Api/`
- **Common Issues**: HTTP endpoints, authentication, data serialization
- **Debug Strategy**: Check API logs, verify request/response flow

### Frontend Integration Issues
- **Location**: `src/web/`, `client/`
- **Common Issues**: UI updates, game state display, user interactions
- **Debug Strategy**: Browser dev tools, network tab, console logs

## Bug Severity Levels

### Critical (P0)
- Game crashes or becomes unplayable
- Data corruption or loss
- Security vulnerabilities
- **Response Time**: Immediate (within hours)

### High (P1)
- Major game features broken
- Significant performance degradation
- Deployment failures
- **Response Time**: Same day

### Medium (P2)
- Minor feature issues
- UI/UX problems
- Documentation errors
- **Response Time**: Within week

### Low (P3)
- Cosmetic issues
- Code quality improvements
- Minor optimizations
- **Response Time**: Next release

## Rollback Procedures

If fix introduces new issues:
1. Revert code changes using git
2. Run regression tests
3. Verify original bug still exists
4. Document rollback reasons
5. Plan alternative fix approach

## Prevention Strategies

- Add comprehensive unit tests for fixed bugs
- Improve code documentation
- Add input validation where missing
- Enhance error handling and logging
- Regular code reviews for critical areas
