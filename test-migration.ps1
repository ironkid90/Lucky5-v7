# Test script for Lucky5 Three-Track Migration
Write-Host "=== Lucky5 Three-Track Migration Test ===" -ForegroundColor Green

# Test 1: Build the solution
Write-Host "`n1. Building solution..." -ForegroundColor Yellow
try {
    Set-Location "server"
    $buildResult = dotnet build Lucky5.sln -v minimal
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Build: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "   Build: FAILED" -ForegroundColor Red
        Write-Host $buildResult
    }
} catch {
    Write-Host "   Build: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Run unit tests
Write-Host "`n2. Running unit tests..." -ForegroundColor Yellow
try {
    $testResult = dotnet run --project tests/Lucky5.Tests/Lucky5.Tests.csproj
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Tests: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "   Tests: FAILED" -ForegroundColor Red
        Write-Host $testResult
    }
} catch {
    Write-Host "   Tests: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Run simulation (10K rounds)
Write-Host "`n3. Running simulation gate (10K rounds)..." -ForegroundColor Yellow
try {
    $simResult = dotnet run --project src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --rounds 10000 --min-rtp 0.78 --max-rtp 0.82
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Simulation: PASS" -ForegroundColor Green
    } else {
        Write-Host "   Simulation: FAIL" -ForegroundColor Red
        Write-Host $simResult
    }
} catch {
    Write-Host "   Simulation: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Run certification simulation (500K rounds)
Write-Host "`n4. Running certification simulation (500K rounds)..." -ForegroundColor Yellow
try {
    $certResult = dotnet run --project src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --certification --min-rtp 0.78 --max-rtp 0.82
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Certification: PASS" -ForegroundColor Green
    } else {
        Write-Host "   Certification: FAIL" -ForegroundColor Red
        Write-Host $certResult
    }
} catch {
    Write-Host "   Certification: EXCEPTION - $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== Migration Test Complete ===" -ForegroundColor Green
