function Get-SelectionFromArray{
    Param(
        [string]$Message,
        $InputArray
    )

    Begin
    {
        $Max = $InputArray.Length

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
    }

    Process
    {
        Write-Host "`n$($Message)`n" -ForegroundColor Cyan
        Display-Options -DisplayArray $InputArray
        $Choice = Get-Choice -Max $Max
        return $InputArray[$Choice]
    }
}

# Get actions folder based of current Photoshop install configuration
$ps = New-Object -ComObject photoshop.application
$ActionCopyLocation =  "$($ps.PreferencesFolder)..\presets\actions"

function Get-FileStorageDrives 
{
    $DiskArr = @()
    $Disks = Get-Disk | ?{ $_.PartitionStyle -eq "GPT" }
    foreach($Disk in $Disks)
    {
        $Partitions = Get-Partition $Disk.Number | ?{ $_.DriveLetter -match "[A-Z]" }
        foreach($Partition in $Partitions)
        {
            $DiskType = (($Partition.DiskPath -split "#")[0] -split "\\")[-1].ToUpper()

            if($DiskType -like "*usb*")
            {
                $DiskType = "USB"
            }

            $Name = $Disk.FriendlyName
            $DriveLetter = (Get-PSDrive $Partition.DriveLetter).Root

            $hash = @{
                Name = $Name
                DriveLetter = $DriveLetter
                DiskType = $DiskType
                InfoString = "Drive ($($DriveLetter)) - $($Name) [$($DiskType)]"
            }

            $DiskArr += New-Object PSObject -Property $hash
        }
    }
    return $DiskArr | Sort-Object -Property DriveLetter
}


$DiskOptions = Get-FileStorageDrives

$DiskSelectionMenu  = @()
$DiskSelectionMenu += "SEARCH ALL listed hard drives"
$DiskSelectionMenu += $DiskOptions | Select-Object -ExpandProperty Infostring
$DiskSelectionMenu += "EXIT"
$Message = "Select where you want to search for PS .atn files..."
$Selection = Get-SelectionFromArray -InputArray $DiskSelectionMenu -Message $Message

switch($Selection)
{
    "SEARCH ALL listed hard drives" { $Drives = $DiskOptions }
    "EXIT" { exit }
    default { $Drives = $DiskOptions | ?{ $_.InfoString -eq $Selection } }
}

foreach($Drive in $Drives)
{
    Write-Host "`n###############################################################" -ForegroundColor Gray
    Write-Host "#" -ForegroundColor Gray
    Write-Host "#" -ForegroundColor Gray -NoNewline
    Write-Host "   Searching $($Drive.InfoString)"
    Write-Host "#" -ForegroundColor Gray
    Write-Host "###############################################################`n" -ForegroundColor Gray
    cd $Drive.DriveLetter
    # Search through drive and get all actions - the select unique
    $Found = Get-ChildItem -File -Recurse -Filter "*.atn" -ErrorAction SilentlyContinue | select -Unique 
    Write-Host "Found the following .atn files:" -ForegroundColor Cyan
    $Found | Select-Object -ExpandProperty FullName

    $Found = $Found | Out-GridView -Title "Select the actions you want to copy over (CTRL + A to select them all)" `
                                   -PassThru

    foreach($File in $Found)
    {
        $destinationFile = "$($ActionCopyLocation)\$($File.Name)"
        if (-not (test-path $destinationFile))
        {
            Write-Host "Copying " -NoNewline -ForegroundColor Cyan
            Write-Host $File.Name -NoNewline
            Write-Host " to Photoshop Actions folder..."  -NoNewline -ForegroundColor Cyan

            $opts = @{'path' = $File.FullName; 'destination' = $ActionCopyLocation; 'confirm' = $false}
            Copy-Item @opts | Out-Null

            Write-Host "Complete" -ForegroundColor Green
        }
        else
        {
            Write-Host "Action " -NoNewline -ForegroundColor Cyan
            Write-Host $File.Name -NoNewline
            Write-Host " already exists - confirm overwrite..." -NoNewline -ForegroundColor Cyan

            $opts = @{'path' = $File.FullName; 'destination' = $ActionCopyLocation; 'confirm' = $true}
            $overwritten = Copy-Item @opts

            if($overwritten)
            {
                Write-Host "Complete" -ForegroundColor Green
            }
            else
            {
                Write-Host "Skipping" -ForegroundColor Yellow
            }
        }
    }
}
 

cd $PSScriptRoot
