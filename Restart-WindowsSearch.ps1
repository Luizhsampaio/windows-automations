<#
.SYNOPSIS
Creates a logon task to restart the Windows Search host process.

.DESCRIPTION
Run this script normally to create or update a Windows Task Scheduler task for
the current user. The task runs at user sign-in. When started by the task, the
script waits 10 seconds, checks whether SearchHost is running, and force-stops
it if found. If SearchHost is not running, no action is taken.

.NOTES
WHY?
On some Windows 11 systems, Windows Search may not start correctly during
system startup. This script provides a transparent workaround by registering
itself to run at user sign-in, then restarting SearchHost if it is running. It
does not change Windows Search settings or guarantee a permanent fix.
#>

param(
    [switch]$RunScheduledTask
)

if (-not $RunScheduledTask) {
    if (-not $PSCommandPath) {
        throw "Run this script from its .ps1 file to register the scheduled task."
    }

    $TaskName = "Restart-WindowsSearch"
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $PowerShellExecutable = (Get-Process -Id $PID).Path
    $TaskArguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -RunScheduledTask' -f $PSCommandPath

    $Action = New-ScheduledTaskAction -Execute $PowerShellExecutable -Argument $TaskArguments
    $Trigger = New-ScheduledTaskTrigger -AtLogOn -User $CurrentUser
    $Principal = New-ScheduledTaskPrincipal -UserId $CurrentUser -LogonType Interactive -RunLevel Limited
    $Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

    Register-ScheduledTask -TaskName $TaskName -Description "Restarts Windows Search at user sign-in when needed." -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null

    Write-Host "Scheduled task '$TaskName' registered for user sign-in."
    return
}

# Wait for Windows to finish loading the user session.
Start-Sleep -Seconds 10

# Look for the Windows Search host process.
$SearchProcess = Get-Process -Name "SearchHost" -ErrorAction SilentlyContinue

if ($SearchProcess) {
    # Stop the process so Windows can start it again when needed.
    Stop-Process -Name "SearchHost" -Force

    # Allow time for the process to exit.
    Start-Sleep -Seconds 2
}
