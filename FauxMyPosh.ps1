class GitParser {
    static [string]   $localBranch
    static [string]   $remoteBranch
    static [string]   $gitPath
    static [string[]] $status
    static [int32]    $numUntracked
    static [int32]    $numTracked
    static [int32]    $numModified
    static [bool]     $showBadge
    static [bool]     $hasUncommitedChanges

    static [bool] IsGitEnabled(){
        git rev-parse 2>$null
        return $?
    }

    static [object] StatusToString(){
        if([GitParser]::showBadge){
            $statusBadges = @(
                @{ $true = '*{0}' -f [GitParser]::numModified;  $false = '' }[[GitParser]::numModified  -gt 0]
                @{ $true = '+{0}' -f [GitParser]::numTracked;   $false = '' }[[GitParser]::numTracked   -gt 0]
                @{ $true = '?{0}' -f [GitParser]::numUntracked; $false = '' }[[GitParser]::numUntracked -gt 0]
                @{ $true = ''; $false = 'No Remote!' }[[GitParser]::remoteBranch -eq [GitParser]::localBranch]
            ) -join ", " -replace "(,\s*)+", ", " -replace "^, ", "" | Where-Object {$_}
            if($statusBadges.Count -gt 0){
                $statusBadges = '>> {0}' -f $statusBadges
                return ('| {0}  {1}' -f [GitParser]::localBranch, $statusBadges)
            }
            return ('| {0}  ' -f [GitParser]::localBranch)
        }
        return $null
    }

    static [void] CheckRemote (){
        if (-not [GitParser]::remoteBranch -or [GitParser]::remoteBranch -ne [GitParser]::localBranch) {
            [GitParser]::remoteBranch = $_branches = $_branch = $null

            $_branches = git branch -a 
            if($_branches){
                $_branch = $_branches | Where-Object { 
                    $_ -match (".{2}remotes.*$([GitParser]::localBranch)")
                }
            }

            if ($_branch) {
                [GitParser]::remoteBranch = $_branch.Split("/")[-1]
            }
        }
    }

    static [void] Update(){
        [GitParser]::showBadge = [GitParser]::IsGitEnabled()

        if([GitParser]::showBadge){
            [GitParser]::localBranch  = git branch --show-current
            [GitParser]::status       = git status --porcelain
            [GitParser]::numModified  = ([GitParser]::status | Where-Object { $_ -match '^\s?M'  }).Count
            [GitParser]::numTracked   = ([GitParser]::status | Where-Object { $_ -match '^\s?A'  }).Count
            [GitParser]::numUntracked = ([GitParser]::status | Where-Object { $_ -match '^\?+' }).Count
            
            [GitParser]::hasUncommitedChanges = $false
            if(([GitParser]::numModified + [GitParser]::numModified + [GitParser]::numModified) -gt 0){
                [GitParser]::hasUncommitedChanges = $true
            }

            [GitParser]::CheckRemote()
        }
    }
}


function Get-ThemedText {
  param
  (
      [System.String]
      $text,

      [ValidateSet("white", "black", "blue", "orange", "green", "purple", "darkorange", "darkgray", "darkred")]
      [System.String]
      $background,

      [ValidateSet("white", "black", "blue", "orange", "green", "purple", "darkorange", "darkgray", "darkred")]
      [System.String]
      $foreground,

      [switch]
      $RESET
  )

  Begin {
      # rgb = @(r, g, b)
      $colorOptions = @{
          "white"      = @(255, 255, 255) -join ";"
          "black"      = @(  0,   0,   0) -join ";"
          "blue"       = @(  0, 135, 175) -join ";"
          "orange"     = @(215,  95,   0) -join ";"
          "green"      = @( 55, 133,   4) -join ";"
          "purple"     = @(116,  77, 137) -join ";"
          "darkorange" = @(169, 116,   0) -join ";"
          "darkgray"   = @( 78,  78,  78) -join ";"
          "darkred"    = @(140,   0,   0) -join ";"
      }

      $_tcfg = @(38, 2) -join ";"
      $_tcbg = @(48, 2) -join ";"
      $__tc  = "m"

      $r__foreground = "####"
      $r__background = "!!!!"
      $r__escape     = "ESCAPEME"

      $templateParts = @(
          $r__escape
          $_tcbg
          $r__background
          $__tc
          $_tcfg
          $r__foreground
          $text
      )
      $colorTemplate = "{0}[{1};{2}{3}{0}[{4};{5}{3}{6}" -f $templateParts
  }

  Process {
      if ($RESET) {
          return $colorTemplate -replace $_tcbg, "" `
              -replace $_tcfg, "" `
              -replace $r__foreground, "0" `
              -replace $r__background, "0"
      }

      return $colorTemplate.Replace($r__foreground, $colorOptions.$foreground).Replace($r__background, $colorOptions.$background)
  }
}


function Initialize-ThemedText {
  param
  (
      [Parameter(Mandatory = $true,
          ValueFromPipeline = $true)]
      [System.String]
      $ThemedText
  )

  $ESC = [char]27
  $_escape = "ESCAPEME"

  return $ThemedText.Replace($_escape, $ESC)
}


function prompt {
    param()

    Begin {
        $user = ("    {0}@{1} " -f $env:USERNAME, $env:USERDOMAIN).ToLower()

        $numDirToShow = 3
        $splitPath = (get-location).Path.Split("\")
        if ($splitPath.Count -gt 3) {
            $bottomLevelParentDirs = $splitPath[($splitPath.Count - $numDirToShow)..$splitPath.Count]
            $location = (, "|> ..." + $bottomLevelParentDirs) -join "\"
            $location += "  "
        }
        else {
            $location = "|>  {0} " -f (get-location).Path
        }


        $promptSymbol = "PS> "

        # GIT STUFF
        [GitParser]::Update()
        $gitBadge = [GitParser]::StatusToString()
        if ($host.Name -notmatch 'ISE') {
            if ([GitParser]::hasUncommitedChanges) {
                $gitBadge = Get-ThemedText -text $gitBadge -background darkorange -foreground white
            }
            elseif (-not [GitParser]::remotebranch) {
                $gitBadge = Get-ThemedText -text $gitBadge -background purple -foreground white
            }
            else {
                $gitBadge = Get-ThemedText -text $gitBadge -background green -foreground white
            }
        }
    }

    Process {
        if ($host.Name -notmatch 'ISE') {
            $themedPrompt = "{0} {1} {2}{3}`n{4}" -f (@(
                (Get-ThemedText -text $user -background white -foreground darkgray)
                (Get-ThemedText -text $location -background blue -foreground white)
                $gitBadge
                (Get-ThemedText -RESET)
                $promptSymbol
            ) | Where-Object {$_})

            Initialize-ThemedText -ThemedText $themedPrompt
        }
        else {
            "| {0} {1} {2} `n{3}" -f (@(
                $user
                $location
                $gitBadge
                $promptSymbol
            ) | Where-Object {$_})
        }
    }
}
