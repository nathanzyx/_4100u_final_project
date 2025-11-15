# --------------------------------------------------------------------------------------
#
#   Powershell file for easily running the StudyConnect app.
#   
#   Instructions:
#       1. Make sure a recognized virtual device is running before executing this file
#       2. Using Powershell, go to the projects base directory:
#               'cd <path_to>/_4100u_final_project'
#       3. Run this file:
#               '.\run_project.ps1'
#
# --------------------------------------------------------------------------------------


# Config
$serverDir = "study_connect_server"
$serverPort = 8080
$serverProcess = $null

function Stop-StudyConnectServer 
{
    if ($serverProcess -and -not $serverProcess.HasExited) 
    {
        try 
        {
            Write-Host "Stopping StudyConnect server..." -ForegroundColor Yellow
            $serverProcess.Kill()
            Write-Host "StudyConnect server was running and successfully stopped." -ForegroundColor Green
        }
        catch
        {
        }
    }
}

try{
    # Port Check
    $portInUse = netstat -ano | Select-String ":$serverPort"
    if ($portInUse)
    {
        Write-Host "------------------------------------------------------------------------------------"
        Write-Host "    ISSUE: Port $serverPort is already in use, StudyConnect's Server cannot run!    " -ForegroundColor Red
        Write-Host ""
        Write-Host "    To fix, run:" -ForegroundColor Green
        Write-Host "        netstat -ano | findstr :$serverPort" -ForegroundColor Gray
        Write-Host "    Then terminate that port, run:" -ForegroundColor Green
        Write-Host "        taskkill /PID <pid> /F" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    Aborting run_project.ps1" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------------------------------"
        exit 1
    }


    # Start Server
    Write-Host "Attempting StudyConnect server startup..."
    $serverProcess = Start-Process `
        -FilePath "dart" `
        -ArgumentList "run bin/study_connect_server.dart" `
        -WorkingDirectory $serverDir `
        -PassThru
    Start-Sleep -Seconds 2


    # Flutter App Startup
    Write-Host "Checking for active Flutter devices..."
    $devicesOutput = flutter devices
    # no flutter devices check (abort app and server running)
    if ($devicesOutput -match "No devices detected") {
        Write-Host "------------------------------------------------------------------------------------"
        Write-Host "    ISSUE: No Flutter device detected! Please start a recognized Flutter device.    " -ForegroundColor Red
        Write-Host "------------------------------------------------------------------------------------"
        return
    }

    # After a virtual device has been found, start the app
    Write-Host "Running StudyConnect app..."
    flutter run
}
finally
{
    Write-Host "StudyConnect app finished." -ForegroundColor Cyan
    Stop-StudyConnectServer
}