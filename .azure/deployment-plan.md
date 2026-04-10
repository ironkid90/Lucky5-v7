# Azure Deployment Plan: Lucky5-v7

## Objective
Validate Azure readiness and establish a repeatable deployment path for the Lucky5-v7 multi-service architecture using the Azure Developer CLI (`azd`).

## Current Status
**Status**: 🏗️ **Planning / Awaiting Approval**  
**Validation Stage**: Initial Analysis (Pre-Validation)

---

## 1. Detected Azure Artifacts
The following files were identified in the repository root and `azure/` directory:

| Artifact | Path | Observations |
| :--- | :--- | :--- |
| `azure.yaml` | `azure.yaml` | Defines 6 services targeting Azure Container Apps. |
| `Deployment Template` | `azure/deploy.json` | **EMPTY**. Infrastructure-as-code definitions are currently missing. |
| `Parameters` | `azure/deploy-parameters.json` | Contains `subscriptionId`: `343ce01c-0b2a-46a3-bb0e-24c0469a9bfe`. |

## 2. Architecture Summary
Based on [`azure.yaml`](../azure.yaml), the system is composed of the following services, all hosted on **Azure Container Apps**:

- **Backend / Core**:
    - `lucky5-api`: .NET Gateway/API services (Web Port 8080). Uses local `Dockerfile`.
    - `lucky5-simulation`: .NET Game Simulation (Web Port 8080).
    - `lucky5-tests`: .NET Integration/Validation tests (Web Port 8080).
- **Frontend / Client Artifacts**:
    - `kilo`: JavaScript-based cabinet frontend layer (Port 80).
    - `kilocode`: JavaScript-based logic/tooling layer (Port 80).
    - `mobile`: JavaScript-based mobile/flutter-web target (Port 80).

## 3. Provisional Deployment Recipe
The repository is structured for `azd`-centric deployment. The proposed high-level workflow is:

1. **Environment Initialization**: `azd env new`
2. **Infrastructure Generation**: Since `azure/deploy.json` is empty, Bicep templates must be generated or mapped to provide the Container App Environment, Registry, and individual Apps.
3. **Provisioning**: `azd provision` (Targets Subscription `343ce...`)
4. **Deployment**: `azd deploy`

## 4. Validation Prerequisites
Before attempting Azure validation, ensure:
- [ ] **Tools**: `azd` (Azure Dev CLI) and Docker Desktop are installed and running.
- [ ] **Auth**: `azd auth login` has been executed successfully.
- [ ] **Subscription**: Access to Sub `343ce01c-0b2a-46a3-bb0e-24c0469a9bfe` is verified.
- [ ] **Local Artifacts**: Phase 3.4 implementation is stable and local builds pass.

## 5. Identified Risks and Gaps
- **Missing IaC**: `azure/deploy.json` is empty. The `azd` pipeline will stall without Bicep/ARM templates to define the target resources. 
- **Networking**: Service-to-service communication within the Container App Environment needs to be validated (e.g., `lucky5-api` reaching simulation services).
- **Persistence**: AGENTS.md notes that the persistence model is currently in-memory; we must ensure Azure deployment survives or handles this state correctly if a real Redis instance is not provisioned.

---

## 6. Next Steps (Awaiting Approval)
1. **Infrastructure Scaffolding**: Generate Bicep templates in `infra/` or `azure/` to support the 6 services defined in `azure.yaml`.
2. **Dry-Run Validation**: Run `azd provision --dry-run` or similar local validation checks.
3. **Summary Report**: Present final infrastructure footprint and estimated impact to the user.

> **ACTION REQUIRED**: Please review this plan. Provide approval to proceed with "Infrastructure Scaffolding" and "Azure Validation" steps.
