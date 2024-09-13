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
            "black"      = @(  0, 0, 0) -join ";"
            "blue"       = @(  0, 135, 175) -join ";"
            "orange"     = @(215, 95, 0) -join ";"
            "green"      = @( 55, 133, 4) -join ";"
            "purple"     = @(116, 77, 137) -join ";"
            "darkorange" = @(169, 116, 0) -join ";"
            "darkgray"   = @( 78, 78, 78) -join ";"
            "darkred"    = @(140, 0, 0) -join ";"
        }

        $_tcfg = @(38, 2) -join ";"
        $_tcbg = @(48, 2) -join ";"
        $__tc = "m"

        $r__foreground = "####"
        $r__background = "!!!!"
        $r__escape = "ESCAPEME"

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

function Escape-ThemedText {
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
            $location += " "
        }
        else {
            $location = "|>  {0} " -f (get-location).Path
        }


        $promptSymbol = "PS> "

        # GIT STUFF
        git rev-parse 2>$null
        $isGitRepo = $?

        $gitBadge = ""
        if ($isGitRepo) {
            $branch = git branch --show-current
            $gitBadge += " {0} " -f $branch

            $status = git status --porcelain

            if (-not $global:remote -or $global:remote -ne $branch) {
                $remotebranch = (git branch -a) | Where-Object { $_ -match ".{2}remotes.*$branch" }
                if ($remotebranch) {
                    $global:remote = $remotebranch.Split("/")[-1]
                }
            }

            $modified = ($status | Where-Object { $_ -match '^M' }).Count
            $newTracked = ($status | Where-Object { $_ -match '^A' }).Count
            $newUntracked = ($status | Where-Object { $_ -match '^\?' }).Count

            if ($modified -or $newTracked -or $newUntracked) {
                $gitBadge += "> "
            }

            if ($modified) {
                $gitBadge += "*{0} " -f $modified
            }

            if ($newTracked) {
                $gitBadge += "+{0} " -f $newTracked
            }

            if ($newUntracked) {
                $gitBadge += "?{0} " -f $newUntracked
            }

            if ($host.Name -notmatch 'ISE') {
                if ($modified -or - $newTracked -or $newUntracked) {
                    $gitBadge = Get-ThemedText -text $gitBadge -background darkorange -foreground white
                }
                elseif (-not $global:remote) {
                    $gitBadge += "> No Remote! "
                    $gitBadge = Get-ThemedText -text $gitBadge -background purple -foreground white
                }
                else {
                    $gitBadge = Get-ThemedText -text $gitBadge -background green -foreground white
                }
            }
            else {
                if (-not $global:remote -and -not $modified -and -not $newTracked -and -not $newUntracked) {
                    $gitBadge += "> No Remote! "
                }
            }
        }
    }

    Process {
        if ($host.Name -notmatch 'ISE') {
            if ($isGitRepo) {
                $gitBadge = Get-ThemedText -text $gitBadge -background green -foreground white
            }
            $themedPrompt = "{0} {1} {2} {3}`n{4}" -f @(
                (Get-ThemedText -text $user -background white -foreground darkgray)
                (Get-ThemedText -text $location -background blue -foreground white)
                $gitBadge
                (Get-ThemedText -RESET)
                $promptSymbol
            )

            Escape-ThemedText -ThemedText $themedPrompt
        }
        else {
            "| {0} {1} {2} `n{3}" -f @(
                $user
                $location
                $gitBadge
                $promptSymbol
            )
        }
    }
}
