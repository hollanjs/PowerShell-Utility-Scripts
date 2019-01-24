# ======================================================================================
# manage restarting and resuming scripts
# ======================================================================================
function Initialize-Step {
    param(
        [int]$NextStep,
        [string]$ScriptName,
        [string]$AppRegPath = $_appConfig.RegSetupPath
    )

    $p = $AppRegPath.Split("\")
    $RunKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

    if ((Test-Path $AppRegPath) -eq $false) {
        New-Item -Path (Join-Path $p[0] $p[1]) -Name $p[2] | Out-Null
        New-ItemProperty -Path $AppRegPath -Name "Step" -Value $NextStep | Out-Null
    }
    else {	
        Set-ItemProperty -Path $AppRegPath -Name "Step" -Value $NextStep -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -Path $RunKey -Name "SystemSetupPath" -Value $("powershell.exe -file " + $ScriptName) | Out-Null
	
    Write-Host "`nThe next step to run is: $NextStep`n" -ForegroundColor Yellow
    Write-Host "Computer will restart in 5 seconds" -ForegroundColor Cyan
	
    Start-Sleep -Seconds 5
    Restart-Computer
}

# ======================================================================================
# cleanup Initialize-Step Function
# ======================================================================================
function Unregister-Step {
    param(
        [Parameter(Mandatory = $true)][string]$AppRegPath
    )

    Log -type Information -message "Removing registry entries used by this script"
    Remove-Item -Path $AppRegPath -ErrorAction SilentlyContinue | Out-Null
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "SystemSetupPath" -ErrorAction SilentlyContinue | Out-Null
}

# ======================================================================================
# used to log time data for operations
# ======================================================================================
function Measure-Time {
    param(
        [int]$TotalSeconds,
        $Operation
    )
    $timeStart = [DateTime]::Now
    $timeEnd = [DateTime]::Now.AddSeconds($TotalSeconds)
    $time = ($timeEnd - $timeStart)

    if ($time.Seconds -gt 0 -and $time.Minutes -eq 0 -and $time.Hours -eq 0) {
        if ($time.Seconds -le 1) {
            $secondVar = "{0} second" -f $time.Seconds
        }
        else {
            $secondVar = "{0} seconds" -f $time.Seconds
        }
        Log -type Information -message $($Operation + " in: " + $secondVar)
    }
    elseif ($time.Seconds -ge 0 -and $time.Minutes -gt 0 -and $time.Hours -eq 0) {
        if ($time.Minutes -le 1) {
            $minVar = "{0} minute and " -f $time.Minutes
        }
        else {
            $minVar = "{0} minutes and " -f $time.Minutes
        }

        if ($time.Seconds -le 1) {
            $secondVar = "{0} second" -f $time.Seconds
        }
        else {
            $secondVar = "{0} seconds" -f $time.Seconds
        }
        Log -type Information -message $($Operation + " in: " + $minVar + $secondVar)
    }
    elseif ($time.Seconds -ge 0 -and $time.Minutes -ge 0 -and $time.Hours -gt 0) {
        if ($time.Hours -le 1) {
            $hourVar = "{0} hour " -f $time.Hours
        }
        else {
            $hourVar = "{0} hours " -f $time.Hours
        }

        if ($time.Minutes -le 1) {
            $minVar = "{0} minute and " -f $time.Minutes
        }
        else {
            $minVar = "{0} minutes and " -f $time.Minutes
        }

        if ($time.Seconds -le 1) {
            $secondVar = "{0} second" -f $time.Seconds
        }
        else {
            $secondVar = "{0} seconds" -f $time.Seconds
        }
        Log -type Information -message $($Operation + " in: " + $hourVar + $minVar + $secondVar)
    }
    else {
        Log -type Information -message $($Operation + " in less than a second")
    }
}


# ======================================================================================
# extract zip file to specified location
# ======================================================================================
function Expand-ZipFile {
    param(
        [Parameter(Mandatory = $true)][String]$ZipFile,
        [Parameter(Mandatory = $true)][String]$Destination
    )

    $t = $ZipFile.Split("\")

    if (-not($t[-1].Contains(".zip"))) {
        $ZipFile = $($ZipFile + ".zip")
    }

    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
    Log -type Information -message $("Extracting " + $ZipFile + " to " + $Destination)
    $time = (Measure-Command {[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $Destination)}).TotalSeconds
    Measure-Time -TotalSeconds $time -Operation "Zip file extracted"
}

# ======================================================================================
# create zip file from specified path to specified location
# ======================================================================================
function Compress-ZipFile {
    param(
        [Parameter(Mandatory = $true)][String]$Path,
        [Parameter(Mandatory = $true)][String]$Destination,
        [ValidateSet('Optimal', 'NoCompression', 'Fastest')][string]$Compression = 'Optimal',
        [bool]$IncludeRoot = $false
    )

    $t = $Destination.Split("\")

    if (-not($t[-1].Contains(".zip"))) {
        $Destination = $($Destination + ".zip")
    }
    
    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
    Log -type Information -message $("Compressing " + $Path + " to " + $Destination)
    $time = (Measure-Command {[System.IO.Compression.ZipFile]::CreateFromDirectory($Path, $Destination, $Compression, $IncludeRoot)}).TotalSeconds
    Measure-Time -TotalSeconds $time -Operation "New zip file created"
}


# ======================================================================================
# write event log entry
# ======================================================================================
function Write-EventLogEntry {
    [cmdletbinding()]
    param(
        [string]$ComputerName = $env:COMPUTERNAME,
        [string]$Message = "",
        [System.Diagnostics.EventLogEntryType]$EntryType = "Information"
    )
    $application = $($_buildType + " Creation Script")

    if (-not [System.Diagnostics.EventLog]::SourceExists($application, $ComputerName)) {
        New-EventLog -LogName Application -Source $application -ComputerName $ComputerName
    }
    switch ($EntryType) {
        "Information" { $eID = 1001 }
        "Warning" { $eID = 1002 }
        "Error" { $eID = 1003 }
    }
    Write-EventLog -ComputerName $ComputerName -LogName Application -Source $application -EntryType $EntryType -EventID $eID -Message $Message
}

# ======================================================================================
# logging solution
# ======================================================================================
function Log {
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)][string]$message = $null,
        [Parameter(Mandatory = $false)][string]$object = $null,
        [ValidateSet('Information', 'Warning', 'Error', 'Lab', 'Fin')][string] $type = 'Information'
    )

    switch ($type) {
        "Information" {
            Write-Host -F Green [$(Get-Date -format g)] $message
            Write-EventLogEntry -Message $message -EntryType Information
        }
        "Warning" {
            Write-Host -F Yellow [$(Get-Date -format g)] $message
            Write-EventLogEntry -Message $message -EntryType Warning
        }
        "Error" {
            Write-Host -F Red [$(Get-Date -format g)] $message
            Write-EventLogEntry -Message $message -EntryType Error
            break
        }
        "Lab" {
            if ([string]::IsNullOrEmpty($object)) {
                Write-Host $(" -" + $message) -F Gray -NoNewline
            }
            else {
                Write-Host $(" -" + $message + ": " + $object) -F Gray -NoNewline
            }
        }
        "Fin" {
            Write-Host " ... Done" -F Green
        }
    }
}

function New-Collection {
    param (
        $LogPath = $_psdb.BuildLogs,
        [validateset('Start', 'Stop')]$Mode
    )

    $timestamp = [DateTime]::Now.ToString("yyyy-MM-dd_hh-mm-ss")
    $file = $($LogPath + "Build_Log_" + $timestamp + ".txt")

    switch ($Mode) {
        "Start" {
            Start-Transcript -Path $file -IncludeInvocationHeader -NoClobber | Out-Null
            log -type Information -message $("Transcript Started, Output to: " + $file)
        }
        "Stop" {
            log -type Information -message $("Transcript Stopped, Output to: " + $file)
            Stop-Transcript | Out-Null 
        }
    }
}

# ======================================================================================
# create new registry key
# ======================================================================================
Function New-RegistryKey {
    param(
        [string] $keyPath, 
        [string] $keyValue, 
        [string] $value, 
        [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'Qword', 'Unknown')][string]$propertyType = "DWord"
    )

    try {
        if ($keyPath.StartsWith("HKU:\")) {
            if ((Test-Path -Path "HKU:\") -eq $false) {
                New-PSDrive -Name "HKU" -PSProvider Registry -Root "Registry::HKEY_USERS" | Out-Null
            }
        }

        if (Test-Path -Path $keyPath) {
            $existingKeyValue = (Get-ItemProperty $keyPath).$keyValue
            
            if ($existingKeyValue -ne $null) {
                Set-ItemProperty -Path $keyPath -Name $keyValue -Value $value | Out-Null
            }
            else {
                New-ItemProperty -Path $keyPath -Name $keyValue -Value $value -PropertyType $propertyType | Out-Null
            }
        } 
        else {
            New-Item -Path $keyPath | Out-Null
            New-ItemProperty -Path $keyPath -Name $keyValue -Value $value -PropertyType $propertyType | Out-Null
        }

    }
    catch {
        log -type Error -message "Cannot Edit Registry"
    }
}


# ======================================================================================
# delete a windows registry key if it exists
# ======================================================================================
Function Remove-RegistryKey {
    param(
        [string]$keyPath
    )

    try {
        If (Test-Path -Path $keyPath) {
            Remove-Item -Path $keyPath -Recurse -Force | Out-Null
        }
    }
    catch {
        log -type Error -message "Cannot Edit Registry"
    }
}


Function Enable-LoginAfterReboot {
    param (
        [hashtable]$Account = $_accounts.CurrentUser,
        [switch]$AutoLogon
    )

    $domain = $Account.Domain
    $user = $Account.Username
    if ($AutoLogon.IsPresent) {
        New-CredentialsfromAccountDB -UserKey -Validate
        $password  = Read-EncryptedPassword -SecurePwdVariable $_accountCreds.CurrentUser.SecureKey -Key $_appConfig.SecureKey
        Enable-AutoAdminLogon -DefaultDomainName $domain -DefaultUserName $user -DefaultPassword $password -AutoLogonCount 1
    } else {
        $password = Read-Host -Prompt "Please enter your password"
        Enable-AutoAdminLogon -DefaultDomainName $domain -DefaultUserName $user -DefaultPassword $password -AutoLogonCount 1
    }
}

Function Enable-AutoAdminLogon {
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$computerName = ".",
        [Parameter(Mandatory = $false)]
        [String]$DefaultDomainName = $env:USERDOMAIN,
        [Parameter(Mandatory = $false)]
        [String]$DefaultUserName = $env:USERNAME,
        [Parameter(Mandatory = $true)]
        [String]$DefaultPassword,
        [Parameter(Mandatory = $false)]
        [Int]$AutoLogonCount
    )
    if ([IntPtr]::Size -eq 8) {
        $hostArchitecture = "amd64"
    }
    else {
        $hostArchitecture = "x86"
    }
    foreach ($computer in $computerName) {
        if (($hostArchitecture -eq "x86") -and ((Get-WmiObject -ComputerName $computer -Class Win32_OperatingSystem).OSArchitecture -eq "64-bit")) {
            Write-Host "System OS architecture is amd64. You must run this script from x64 PowerShell Host" -ForegroundColor White
            continue
        }
        else {
            if ($computer -ne ".") {
                if ((Get-Service -ComputerName $computer -Name RemoteRegistry).Status -ne "Running") {
                    Write-Error "remote registry service is not running on $($computer)"
                    continue
                }
                else {
                    Write-Host "Adding required registry values on $($computer)" -ForegroundColor Gray
                    $remoteRegBaseKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $computer)
                    $remoteRegSubKey = $remoteRegBaseKey.OpenSubKey("SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon", $true)
                    $remoteRegSubKey.SetValue("AutoAdminLogon", 1, [Microsoft.Win32.RegistryValueKind]::String)
                    $remoteRegSubKey.SetValue("DefaultDomainName", $DefaultDomainName, [Microsoft.Win32.RegistryValueKind]::String)
                    $remoteRegSubKey.SetValue("DefaultUserName", $DefaultUserName, [Microsoft.Win32.RegistryValueKind]::String)
                    $remoteRegSubKey.SetValue("DefaultPassword", $DefaultPassword, [Microsoft.Win32.RegistryValueKind]::String)
                    if ($AutoLogonCount) {
                        $remoteRegSubKey.SetValue("AutoLogonCount", $AutoLogonCount, [Microsoft.Win32.RegistryValueKind]::DWord)
                    }
                }
            }
            else {
                #do local modifications here
                #Write-Host "Adding required registry values on $($computer)" -ForegroundColor Gray
                #Write-Host "Saving curent location" -ForegroundColor Gray
                Push-Location
                Set-Location "HKLM:\Software\Microsoft\Windows NT\Currentversion\WinLogon"
                New-ItemProperty -Path $pwd.Path -Name "AutoAdminLogon" -Value 1 -PropertyType "String" -Force | Out-Null
                New-ItemProperty -Path $pwd.Path -Name "DefaultUserName" -Value $DefaultUserName -PropertyType "String" -Force | Out-Null
                New-ItemProperty -Path $pwd.Path -Name "DefaultPassword" -Value $DefaultPassword -PropertyType "String" -Force | Out-Null
                New-ItemProperty -Path $pwd.Path -Name "DefaultDomainName" -Value $DefaultDomainName -PropertyType "String" -Force | Out-Null
                if ($AutoLogonCount) {
                    New-ItemProperty -Path $pwd.Path -Name "AutoLogonCount" -Value $AutoLogonCount -PropertyType "Dword" -Force | Out-Null
                }
                #Write-Host "restoring earlier location" -ForegroundColor Gray
                Pop-Location
            }
        }
    }
}


function New-PSProcess {
    param (
        $FilePath,
        [switch]$Wait
    )
    if ($Wait.IsPresent -eq $true) {
        $time = (Measure-Command { Start-Process -FilePath "powershell.exe" -ArgumentList $FilePath -Wait }).TotalSeconds
        Measure-Time -TotalSeconds $time -Operation "Process Compleated"
    } else {
        Start-Process -FilePath "powershell.exe" -ArgumentList $FilePath
        Start-Sleep -Seconds 20
    }
}
