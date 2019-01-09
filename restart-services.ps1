param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("Stop","Start","Restart")]
    [string] $Action,
    [switch] $PerformIISReset = $true,
    [switch] $OnlyAppServers,
    [switch] $OnlyFrontEndServers,
    $Cred
)


$Message = "Credentials needed for IIS reset at end of service actions"
if(!$Cred)
{
    $Cred    = Get-Credential -UserName "$($env:USERDOMAIN)\$($env:USERNAME)" `
                              -Message  $Message    
}

$Servers         = Get-SPServer | ?{ $_.Role -ne "Invalid" }
$FrontEndServers = $Servers | ?{ $_.Role -like "*FrontEnd*" }
$AppServers      = $Servers | ?{ $_.Role -like "App*" }

if($OnlyAppServers -and !$OnlyFrontEndServers)
{
    $Servers = $AppServers 
}

if($OnlyFrontEndServers -and !$OnlyAppServers)
{
    $Servers = $FrontEndServers
}

# Update with service filter
$ServiceFilter   = "*nintex*"
$Retry           = $false


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

$UserSetParameters = Get-HashOfUserDefinedVariables
Write-Host ""
#Checks if ServiceName exists and provides ServiceStatus
function CheckMyService
{
    Param(
        $ServiceName
    )
	if (Get-Service $ServiceName -ErrorAction SilentlyContinue)
	{
		$ServiceStatus = (Get-Service -Name $ServiceName).Status
		Write-Host $ServiceName "-" $ServiceStatus
	}
	else
	{
		Write-Host "$ServiceName not found"
	}
}


function Perform-IISReset
{
    Param(
        $Servers
    )

    foreach ($Server in $Servers)
    {
        Write-Host "`n-------------->>>>vvvv  $($Server.Address) vvvv<<<<--------------`n" -F Green

        Invoke-Command -ComputerName $Server.Address `
                       -Credential   $Cred `
                       -ScriptBlock  { iisreset }
    }
}


foreach ($Server in $Servers) 
{
    Write-Host "`n-------------->>>>vvvv  $($Server.Address) vvvv<<<<--------------`n" -F Green

    $Services = Get-Service -ComputerName $Server.Address | ?{$_.Name -like $ServiceFilter}

    foreach ($Service in $Services)
    {
        $ServiceName = $Service.Name

        #Checks if service exists
        if (Get-Service $ServiceName -ErrorAction SilentlyContinue)
        {	#Condition if user wants to stop a service
	        if ($Action -eq 'Stop')
	        {
		        if ((Get-Service -Name $ServiceName).Status -eq 'Running')
		        {
                    $Retry = $true
			        Write-Host $ServiceName "is running, preparing to stop..."
			        Get-Service -ComputerName $Server.Address -Name $ServiceName | Stop-Service -ErrorAction SilentlyContinue
			        CheckMyService $ServiceName
		        }
		        elseif ((Get-Service -Name $ServiceName).Status -eq 'Stopped')
		        {
			        Write-Host $ServiceName "already stopped!"
		        }
		        else
		        {
			        Write-Host $ServiceName "-" $ServiceStatus
		        }
	        }
 
	        #Condition if user wants to start a service
	        elseif ($Action -eq 'Start')
	        {
		        if ((Get-Service -Name $ServiceName).Status -eq 'Running')
		        {
			        Write-Host $ServiceName "already running!"
		        }
		        elseif ((Get-Service -Name $ServiceName).Status -eq 'Stopped')
		        {
                    $Retry = $true
			        Write-Host $ServiceName "is stopped, preparing to start..."
			        Get-Service -ComputerName $Server.Address -Name $ServiceName | Start-Service -ErrorAction SilentlyContinue
			        CheckMyService $ServiceName
		        }
		        else
		        {
			        Write-Host $ServiceName "-" $ServiceStatus
		        }
	        }
 
	        #Condition if user wants to restart a service
	        elseif ($Action -eq 'Restart')
	        {
		        if ((Get-Service -Name $ServiceName).Status -eq 'Running')
		        {
                    $Retry  = $true
                    $Action = "Start"
			        Write-Host $ServiceName "is running, preparing to restart..."
			        Get-Service -ComputerName $Server.Address -Name $ServiceName | Stop-Service -ErrorAction SilentlyContinue
			        Get-Service -ComputerName $Server.Address -Name $ServiceName | Start-Service -ErrorAction SilentlyContinue
			        CheckMyService $ServiceName
		        }
		        elseif ((Get-Service -Name $ServiceName).Status -eq 'Stopped')
		        {
                    $Retry  = $true
                    $Action = "Start"
			        Write-Host $ServiceName "is stopped, preparing to start..."
			        Get-Service -ComputerName $Server.Address -Name $ServiceName | Start-Service -ErrorAction SilentlyContinue
			        CheckMyService $ServiceName
		        }
	        }
 
	        #Condition if action is anything other than stop, start, restart
	        else
	        {
		        Write-Host "Action parameter is missing or invalid!"
	        }
        }
 
        #Condition if provided ServiceName is invalid
        else
        {
	        Write-Host "$ServiceName not found"
        }
    }
}


if($Retry)
{
    Write-Host "`n`nRe-running to verify that services are at status: $($Action)" -ForegroundColor Yellow
    $UserSetParameters.PerformIISReset.IsPresent = $false
    Invoke-Expression -Command ($PSCommandPath + ' @UserSetParameters')
}

if($PerformIISReset) 
{
    write-host "Performing IIS Reset" -ForegroundColor Cyan
    Perform-IISReset -Servers $Servers 
}


