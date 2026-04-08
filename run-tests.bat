@echo off
echo Starting Lucky5 Three-Track Migration Tests
echo.

echo 1. Building solution...
cd server
dotnet build Lucky5.sln -v minimal
if %ERRORLEVEL% NEQ 0 (
    echo Build FAILED
    goto :error
)
echo Build SUCCESS
echo.

echo 2. Running unit tests...
dotnet run --project tests/Lucky5.Tests/Lucky5.Tests.csproj
if %ERRORLEVEL% NEQ 0 (
    echo Tests FAILED
    goto :error
)
echo Tests SUCCESS
echo.

echo 3. Running simulation gate (10K rounds)...
dotnet run --project src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --rounds 10000 --min-rtp 0.78 --max-rtp 0.82
if %ERRORLEVEL% NEQ 0 (
    echo Simulation FAILED
    goto :error
)
echo Simulation SUCCESS
echo.

echo 4. Running certification simulation (500K rounds)...
dotnet run --project src/Lucky5.Simulation/Lucky5.Simulation.csproj -- --certification --min-rtp 0.78 --max-rtp 0.82
if %ERRORLEVEL% NEQ 0 (
    echo Certification FAILED
    goto :error
)
echo Certification SUCCESS
echo.

echo All tests completed successfully!
goto :end

:error
echo.
echo TEST FAILED - Exit code: %ERRORLEVEL%
exit /b 1

:end
cd ..
echo.
echo Migration verification complete.
pause
