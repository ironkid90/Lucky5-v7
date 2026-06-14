---
name: Azure Deployment Automation
description: Automated deployment workflow for Lucky5 to Azure App Service
version: 1.0.0
author: Kade Orchestrator
tags: [deployment, azure, automation, devops]
---

# Azure Deployment Automation Workflow

This workflow automates the deployment of Lucky5 to Azure App Service with proper validation and monitoring.

## Mission Breakdown

### Mission 1: Pre-Deployment Validation
**Agent Profile**: DevOps Engineer  
**Mode**: Focus  
**Estimated Time**: 1 hour

#### Tasks:
- [ ] Verify all components build successfully
- [ ] Run comprehensive test suite
- [ ] Check Azure CLI authentication
- [ ] Validate deployment scripts
- [ ] Backup current production state

#### Validation Commands:
```bash
# Build verification
dotnet build server/Lucky5.sln -v minimal

# Test execution
dotnet run --project server/tests/Lucky5.Tests/Lucky5.Tests.csproj

# Azure authentication
az account show

# Script validation
bash -n scripts/setup-azure.sh
```

---

### Mission 2: Deployment Execution
**Agent Profile**: DevOps Engineer  
**Mode**: Auto  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] Execute Azure deployment script
- [ ] Monitor deployment progress
- [ ] Verify service health endpoints
- [ ] Configure application settings
- [ ] Set up monitoring and logging

#### Deployment Commands:
```bash
# Main deployment
bash scripts/setup-azure.sh

# Health verification
curl https://<app-name>.azurewebsites.net/health/live

# Log monitoring
az webapp log tail --resource-group <resource-group> --name <app-name>
```

---

### Mission 3: Post-Deployment Validation
**Agent Profile**: QA Specialist  
**Mode**: Review  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] Full smoke testing of deployed application
- [ ] Verify SignalR/WebSocket connectivity
- [ ] Test game functionality end-to-end
- [ ] Performance testing under load
- [ ] Documentation update

#### Validation Checklist:
- [ ] Application loads correctly
- [ ] User authentication works
- [ ] Game mechanics function properly
- [ ] Real-time features work
- [ ] Mobile responsiveness maintained
- [ ] Error handling works correctly

---

## Deployment Configuration

### Azure Resources
- **Resource Group**: `lucky5-rg`
- **App Service Plan**: Linux B1 (or higher)
- **Container Registry**: Azure Container Registry
- **Web App**: Custom container deployment

### Environment Variables
```bash
WEBSITES_PORT=8080
PORT=8080
ASPNETCORE_ENVIRONMENT=Production
CORS__ALLOWED_ORIGINS=<app-url>
LUCKY5_ADMIN_USERNAME=<admin-user>
LUCKY5_ADMIN_PASSWORD=<admin-password>
LUCKY5_ADMIN_PHONE=<admin-phone>
```

### Critical Settings
- **Always On**: Enabled (for SignalR)
- **WebSockets**: Enabled (for real-time)
- **HTTP/2**: Enabled (for performance)
- **HTTPS Only**: Enabled (for security)

## Monitoring and Alerting

### Health Endpoints
- **Application Health**: `/health/live`
- **SignalR Hub**: `/CarrePokerGameHub`
- **API Root**: `/`

### Key Metrics
- Response time
- Error rate
- Memory usage
- CPU utilization
- Active connections

### Alert Thresholds
- Error rate > 5%
- Response time > 2 seconds
- Memory usage > 80%
- CPU usage > 75%

## Rollback Procedures

### Immediate Rollback
If deployment fails validation:
```bash
# Get previous deployment
az webapp deployment list --name <app-name> --resource-group <resource-group>

# Rollback to previous version
az webapp deployment source config-zip --resource-group <resource-group> --name <app-name> --src <previous-package>
```

### Database Considerations
- Current deployment uses in-memory state
- No database rollback needed
- State will reset on redeploy

## Troubleshooting Guide

### Common Issues

#### Container Won't Start
1. Check port configuration (8080)
2. Verify container logs
3. Validate environment variables
4. Check resource allocation

#### SignalR Connection Issues
1. Verify WebSockets enabled
2. Check CORS configuration
3. Validate hub routing
4. Test with different browsers

#### Performance Issues
1. Monitor resource usage
2. Check App Service Plan limits
3. Review application logs
4. Consider scaling up

### Debug Commands
```bash
# View container logs
az webapp log tail --resource-group <resource-group> --name <app-name>

# Check app settings
az webapp config appsettings list --resource-group <resource-group> --name <app-name>

# Restart app service
az webapp restart --resource-group <resource-group> --name <app-name>

# Scale up if needed
az appservice plan update --resource-group <resource-group> --name <plan-name> --sku B2
```

## Security Considerations

### Network Security
- HTTPS only enforced
- CORS properly configured
- No exposed admin endpoints
- Secure authentication tokens

### Application Security
- Environment variables for secrets
- No hardcoded credentials
- Regular security updates
- Input validation

## Performance Optimization

### Recommended Settings
- **Minimum SKU**: B1 for development
- **Production SKU**: B2 or higher
- **Auto-scaling**: Consider for traffic spikes
- **CDN**: Azure CDN for static assets

### Optimization Tips
- Enable Always On for SignalR
- Use Azure Front Door for global distribution
- Implement caching where appropriate
- Monitor and tune based on usage patterns
