@echo off
echo === Lucky5 Three-Track Migration Test ===

echo.
echo 1. Building solution...
cd server
dotnet build Lucky5.sln -v minimal
if %ERRORLEVEL% EQU 0 (
    echo    Build: SUCCESS
) else (
    echo    Build: FAILED
    goto :error
)

echo.
echo 2. Running unit tests...
dotnet run --project tests/Lucky5.Tests/Lucky5.Tests.csproj
if %ERRORLEVEL% EQU 0 (
    echo    Tests: SUCCESS
) else (
    echo    Tests: FAILED
    goto :error
)

echo.
echo 3. Running simulation gate (10K rounds)...
dotnet run --project src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --rounds 10000 --min-rtp 0.78 --max-rtp 0.82
if %ERRORLEVEL% EQU 0 (
    echo    Simulation: PASS
) else (
    echo    Simulation: FAIL
    goto :error
)

echo.
echo 4. Running certification simulation (500K rounds)...
dotnet run --project src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --certification --min-rtp 0.78 --max-rtp 0.82
if %ERRORLEVEL% EQU 0 (
    echo    Certification: PASS
) else (
    echo    Certification: FAIL
    goto :error
)

echo.
echo === Migration Test Complete ===
goto :end

:error
echo.
echo === Test Failed ===
exit /b 1

:end
cd ..
pause
