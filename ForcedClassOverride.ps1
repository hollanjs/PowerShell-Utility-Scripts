class PatchProcess {
    [string[]] $files = @()
    [void] GetPatchFiles() { throw "OVERRIDE ME" }
    [void] RunPatches() { throw "OVERRIDE ME" }

    static [void] StandardizedPendingRebootCheck($servername) {
        Write-Host "Checking pending reboots..."
        while ((Get-Random -Maximum 2) -gt 0) {
            Write-Host "Rebooting to apply patches..."
            [PatchProcess]::StandardizedPendingRebootCheck($servername)
        }
    }

    [void] Init() {
        $this.GetPatchFiles()
    }

    [void] Patch() {
        [PatchProcess]::StandardizedPendingRebootCheck($env:COMPUTERNAME)
        $this.RunPatches()
    }
}

class FileSharePatching : PatchProcess {
    [void] GetPatchFiles() {
        # whatever the file share method of getting patch files
        "FileShare1.exe", "FileShare2.exe", "FileShare3.exe" | ForEach-Object {
            Write-Host "Getting file from file share: $PSItem"
            $this.files += $PSItem
        }
    }

    [void] RunPatches() {
        # process for running file share patches
        $this.files | ForEach-Object {
            Write-Host "Patching using: $PSItem"
        }
    }

    FileSharePatching() {
        Write-Host 'Initialized a FileShare Patch Process'
        $this.init()
    }
}

class MecmPatching : PatchProcess {
    [void] GetPatchFiles() {
        # whatever the file share method of getting patch files
        "MecmPatch1.exe", "MecmPatch2.exe", "MecmPatch3.exe" | ForEach-Object {
            Write-Host "Getting file from file share: $PSItem"
            $this.files += $PSItem
        }
    }

    [void] RunPatches() {
        # process for running file share patches
        $this.files | ForEach-Object {
            Write-Host "Patching using: $PSItem"
        }
    }

    MecmPatching() {
        Write-Host 'Initialized a FileShare Patch Process'
        $this.Init()
    }
}

enum PatchType {
    FileShare
    MECM
}

function Get-PatchProcess {
    param
    (
        [Parameter(Mandatory = $true,
            Position = 0)]
        [PatchType]
        $Type
    )
    switch ($Type) {
        FileShare { return New-Object FileSharePatching }
        MECM { return New-Object MecmPatching }
    }
}

$PatchManager = Get-PatchProcess -Type FileShare
$PatchManager.Patch()

$PatchManager = PatchProcess MECM
$PatchManager.Patch()
