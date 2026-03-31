---
name: Game Feature Development
description: Complete workflow for developing new Lucky5 game features
version: 1.0.0
author: Kade Orchestrator
tags: [game-development, feature, lucky5]
---

# Game Feature Development Workflow

This workflow orchestrates the complete development of new game features for Lucky5 video poker, from concept to deployment.

## Mission Breakdown

### Mission 1: Feature Analysis & Planning
**Agent Profile**: Game Analyst  
**Mode**: Focus  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] Review game mechanics documentation in `docs/GAME_FEEL_REFERENCE.md`
- [ ] Analyze existing codebase architecture in `server/src/Lucky5.Domain/Game/CleanRoom/`
- [ ] Identify integration points with current systems
- [ ] Create technical specification document
- [ ] Define success criteria and acceptance tests

#### Context Files:
- `docs/GAME_FEEL_REFERENCE.md` - Game design guidelines
- `server/src/Lucky5.Domain/` - Core game logic
- `README.md` - Project overview

---

### Mission 2: Backend Implementation
**Agent Profile**: .NET Backend Developer  
**Mode**: Focus  
**Estimated Time**: 8 hours

#### Tasks:
- [ ] Implement game engine logic in CleanRoom architecture
- [ ] Create/update API controllers in `server/src/Lucky5.Api/`
- [ ] Add SignalR hubs for real-time updates
- [ ] Write unit tests using custom test runner
- [ ] Update API documentation

#### Key Commands:
```bash
dotnet build server/Lucky5.sln -v minimal
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj
```

#### Context Files:
- `server/src/Lucky5.Domain/Game/CleanRoom/` - Game engine
- `server/src/Lucky5.Api/` - Web API
- `server/tests/` - Test suite

---

### Mission 3: Frontend Integration
**Agent Profile**: React/Flutter Developer  
**Mode**: Collaborate  
**Estimated Time**: 6 hours

#### Tasks:
- [ ] Update React components in `src/web/`
- [ ] Implement new game states and animations
- [ ] Add SignalR client integration
- [ ] Test user interactions and game flow
- [ ] Ensure responsive cabinet design

#### Context Files:
- `src/web/` - React web frontend
- `client/` - Flutter mobile client
- `server/src/Lucky5.Api/wwwroot/` - Vanilla JS cabinet

---

### Mission 4: Testing & Validation
**Agent Profile**: Game QA Specialist  
**Mode**: Review  
**Estimated Time**: 4 hours

#### Tasks:
- [ ] Run automated test suite
- [ ] Manual gameplay testing
- [ ] Performance testing under load
- [ ] Cross-browser and mobile validation
- [ ] Regulatory compliance checks

#### Key Commands:
```bash
pwsh scripts/smoke-api.ps1
dotnet run --project server/src/Lucky5.Api/Lucky5.Api.csproj
```

---

### Mission 5: Deployment Preparation
**Agent Profile**: DevOps Engineer  
**Mode**: Auto  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] Verify build processes
- [ ] Update deployment scripts
- [ ] Test Azure deployment pipeline
- [ ] Configure monitoring and logging
- [ ] Document deployment procedures

#### Key Commands:
```bash
bash scripts/setup-azure.sh
docker compose -f infra/docker-compose.yml up
```

---

## Integration Points

### Azure Deployment
- Uses `scripts/setup-azure.sh` for automated deployment
- Integrates with Azure Container Registry
- Configures App Service settings

### Testing Pipeline
- Custom test runner: `dotnet run --project server/tests/`
- Smoke testing: `pwsh scripts/smoke-api.ps1`
- Local development: `docker compose`

### Code Quality
- Linting: `trunk check`
- Build verification: `dotnet build server/Lucky5.sln`
- Documentation updates

## Success Criteria

1. ✅ Feature implemented according to game design specifications
2. ✅ All automated tests pass
3. ✅ Manual gameplay testing completed successfully
4. ✅ Deployment to Azure verified
5. ✅ Documentation updated
6. ✅ Performance meets requirements

## Rollback Plan

If any mission fails:
1. Document the failure point
2. Revert affected code changes
3. Run regression tests
4. Update mission plan based on learnings

## Notes

- Maintain CleanRoom architecture purity
- Preserve retro cabinet aesthetic
- Ensure SignalR real-time functionality
- Keep single-instance deployment constraints in mind
- Document any deviations from original design
