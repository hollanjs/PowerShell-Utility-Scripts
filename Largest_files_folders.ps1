$ErrorActionPreference = "SilenlyContinue"

$path = "C:\"
$first = 25
$numSubDirs = Get-ChildItem $path -Recurse | Measure-Object | %{$_.Count}
$i = 0

function Get-DirSize($path, $j) {
    $size = 0 
    $folders = @() 
   
    foreach ($file in (Get-ChildItem $path -Force -ea SilentlyContinue)) { 
        if ($file.PSIsContainer) { 
            $subfolders = @(Get-DirSize $file.FullName $j) 
            $size += $subfolders[-1].Size 
            $folders += $subfolders 
        } else { 
            $size += $file.Length 
        } 
        $j++
        Write-Progress `
            -Activity "Mapping complete - checking --> $path" `
            -Status "Iterated $j of $numSubDirs files/folders" `
            -PercentComplete ($j/$numSubDirs*100)
    }

    $object = New-Object -TypeName PSObject 
    $object | Add-Member -MemberType NoteProperty -Name Folder `
                         -Value (Get-Item $path).FullName 
    $object | Add-Member -MemberType NoteProperty -Name Size -Value $size 
    $folders += $object 
    
    Write-Output $folders 
}

Function Get-FormattedNumber($size) { 
    if($size -ge 1GB) { "{0:n2}" -f  ($size / 1GB) + " GigaBytes" } 
    elseif($size -ge 1MB) { "{0:n2}" -f  ($size / 1MB) + " MegaBytes" } 
    else { "{0:n2}" -f  ($size / 1KB) + " KiloBytes" } 
}

if (-not(Test-Path -Path $path)) {  
     Write-Host -ForegroundColor red "Unable to locate $path"  
     Help $MyInvocation.InvocationName -full 
     exit  
}

Get-DirSize -path $path $i |  
Sort-Object -Property size -Descending |  
Select-Object -Property folder, size -First $first | 
Format-Table -Property Folder, @{ Label="Size of Folder" ; Expression = {Get-FormattedNumber($_.size)} } 
