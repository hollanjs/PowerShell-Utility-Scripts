#region LOGGING
$Global:ScriptLogFilePath = $pwd.Path + "\script log folder"
if(!(Test-Path -Path $Global:ScriptLogFilePath))
{
    New-Item -ItemType Directory -Force -Path $Global:ScriptLogFilePath | Out-Null
}

function Start-ScriptLog {
    $TimeStamp   = Get-Date -Format MM-dd-yyyy_HH-mm-ss
    $ScriptName  = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.ScriptName)
    $LogFileName = "\$($ScriptName)_$($TimeStamp).txt"
    $LogFullPath = $Global:ScriptLogFilePath + $LogFileName
    Start-Transcript -Path $LogFullPath -NoClobber
}

Start-ScriptLog
#endregion

function Get-Choice {
    Param(
        $Max
    )

    Begin
    {
        $i = Read-Host "Choice"
        try
        {
            $i = [int]$i
        }
        catch
        {
            Write-Host "Not a number - try again"
            Get-Choice -Max $Max
        }
    }
    
    Process
    {
        if($i -gt $Max){
            Write-Host "Try Again"
            Get-Choice -Max $Max 
        }
        else{
            return ($i - 1)
        }
            
    }
}


function Get-SelectionFromArray{
    Param(
        [string]$Message,
        $InputArray
    )

    Begin
    {
        $Max = $InputArray.Length
    }

    Process
    {
        Write-Host "`n$($Message)`n" -ForegroundColor Cyan
        Display-Options -DisplayArray $InputArray
        $Choice = Get-Choice -Max $Max
        return $InputArray[$Choice]
    }
}


function Display-Options {
    Param(
        $DisplayArray
    )

    $_options = @()

    $DisplayArray | %{
        $_objProp = @{}
        $_objProp.Add('Option', $DisplayArray.IndexOf($_) + 1)
        $_objProp.Add('Process', $_)
        $_obj = New-Object -TypeName psobject -Property $_objProp
        
        $_options += $_obj
    }

    $FormatOption = @{
        n='Option';
        e={$_.Option};
        align='center';
    }

    $FormatProcess = @{
        n='                                           ';
        e={$_.Process};
    }

    Write-Host "--------------------------------------------------"
    Write-Host ($_options | select Option, Process | Format-Table -AutoSize $FormatOption, $FormatProcess | Out-String).Trim()
    Write-Host "--------------------------------------------------"
}


function Wait-ForJustAMoment {
    Param(
        $Seconds
    )

    Begin
    {
        $i = 0
    }

    Process
    {
        Write-Host "Waiting for $($Seconds) seconds" -NoNewline -ForegroundColor Cyan
        while ($i -le $Seconds)
        {
            Write-Host "." -NoNewLine -ForegroundColor White 
            Start-Sleep -Seconds 1
            $i++
        }
        Write-Host ""
    }
}

function Ask-ToRunAgain {
    $EnterAnotherTerm = Read-Host -Prompt "Enter another single term? (default 'n')  y/n"
    $EnterAnotherTerm = $EnterAnotherTerm.ToLower()
    if($EnterAnotherTerm -eq "y"){ __Main__ -Single }
}

function Backup-WebConfigs
{
    $webApps = Get-SPWebApplication
    $backupDir = "D:\Web Config Backups"
    $backupDir = "$($backupDir)\$(Get-Date -Format MM-dd-yyyy)"
    if(!(Test-Path -Path $backupDir))
    {
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    }

    foreach ($webApp in $webApps)
    {
    #format later
    $webAppName = $webApp.DisplayName
    Write-Host "Backing up $($webApp.DisplayName) web.config file…" -foreground Gray –nonewline
    ## You may wish to iterate through all the available zones 
    $zone = $webApp.AlternateUrls[0].UrlZone
    ## Get the collection of IIS settings for the zone 
    $iisSettings = $webApp.IisSettings[$zone]
    ## Get the path from the settings 
    $path = $iisSettings.Path.ToString() + "\web.config"
    ## copy the web.config file from the path 
    copy-item $path -destination $backupDir\$webAppName
    Write-Host "done" -foreground Green

    }
}

function Get-UserDefinedVariables
{
    Get-Variable | Where-Object {
        (@("FormatEnumerationLimit",
        "MaximumAliasCount",
        "MaximumDriveCount",
        "MaximumErrorCount",
        "MaximumFunctionCount",
        "MaximumVariableCount",
        "PGHome",
        "PGSE",
        "PGUICulture",
        "PGVersionTable",
        "PROFILE",
        "PSSessionOption",
        "psISE",
        "psUnsupportedConsoleApplications",
        "uservariable"
        ) -notcontains $_.name) `
        -and (([psobject].Assembly.GetType('System.Management.Automation.SpecialVariables').GetFields('NonPublic,Static') `
              | Where-Object FieldType -eq ([string]) `
              | ForEach-Object GetValue $null)) -notcontains $_.name
    }
}
<#rerun same script with user defined parameters

$UserSetParameters = Get-HashOfUserDefinedVariables
Invoke-Expression -Command ($PSCommandPath + ' @UserSetParameters')

#>

function Transform-ArrayToHash {
    Param(
        $InputArray
    )
    $hash = @{}
    $InputArray | %{
         $hash[$_.Name] = $_.Value 
    }
    return $hash
}

function Get-HashOfUserDefinedVariables {
    return Transform-ArrayToHash -InputArray (Get-UserDefinedVariables)
}

#$UserSetParameters = Get-HashOfUserDefinedVariables


#region Progress Report Function
$global:i = 0;

function WriteProgress($Count)
{
    $_count = $Count

    $global:i++;

    if($global:i -eq 1)
    {
        $global:timeStart = [DateTime]::Now
    }

    $timeNow = [DateTime]::Now
    $timeSpan = New-TimeSpan $global:timeStart $timeNow
    $timeRemaining = (($timeSpan.TotalSeconds / $global:i) * ($_count - $global:i))
        
    Write-Progress -Activity "Checking for user profile..." `
                   -Status "Checked $i of $_count sites" `
                   -PercentComplete ($i/$_count*100) `
                   -SecondsRemaining $timeRemaining
}
#endregion


function Test-Server {
    param (
        $ServerName
    )
    $ping = New-Object System.Net.Networkinformation.Ping
    try {
        $pingResult = $ping.Send($ServerName, 10)
        return $pingResult.Status
    }
    catch {
        return "Failure"
    }
}

function Test-PendingReboot {
    param (
        $server
    )

<# Example block

foreach ($server in $_Servers.Keys | Sort-Object) {
    Write-Host ' ------------->>>vvv  ' $_Servers.$server.ServerName ' vvv<<<-------------' -F Green
    Write-Host '|                                                          |' -F Green
    Test-PendingReboot -server $_Servers.$server.ServerName
    Write-Host '|                                                          |' -F Green
    
}

Write-Host ' ----------------------------------------------------------' -F Green

#>

    $testRebootScriptBlock = {
        if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
        if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
        if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
        try { 
            $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
            $status = $util.DetermineIfRebootPending()
            if(($status -ne $null) -and $status.RebootPending){
                return $true
            }
        }catch{}
        return $false
    }

    $verifyServer = Test-Server -ServerName $server
    if ($verifyServer -eq "Success") {
        $rebootRequired = $null
        If ($server -ne $env:COMPUTERNAME) {
            $rebootRequired = Invoke-Command -Computer $server -ScriptBlock $testRebootScriptBlock
        }
        elseif ($server -eq $env:COMPUTERNAME) {
            $rebootRequired = Invoke-Command -ScriptBlock $testRebootScriptBlock
        }

        If ($rebootRequired) {
            Write-Host $(">  --> REBOOT REQUIRED                                     <") -F Yellow -B DarkRed
        }
        else {
            Write-Host $("|  --> NO REBOOT REQUIRED                                  |") -F Green -BackgroundColor DarkGreen
        }
    }
    else {
        Write-Host $("|  " + $server + " DOES NOT EXIST                          |") -ForegroundColor Red -BackgroundColor Black
    }
}
