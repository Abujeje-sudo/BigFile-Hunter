@echo off
setlocal EnableExtensions EnableDelayedExpansion
title BIG FILE HUNTER
color 07

rem ==========================================================================
rem  BIG FILE HUNTER
rem  Finds the biggest (or smallest) files on EVERY folder of EVERY drive.
rem  - Batch handles the UI, menus, animations and ASCII art
rem  - PowerShell (built into Windows) does the heavy scanning, because plain
rem    batch cannot handle file sizes above 2 GB.
rem  Tip: run as Administrator for a complete scan of system folders.
rem ==========================================================================

set "BF_SELF=%~f0"
set "BF_OUT=%TEMP%\bigfile_hunter_result.csv"
set "BF_DONE=%TEMP%\bigfile_hunter_done.flag"
set "BF_STATUS=%TEMP%\bigfile_hunter_status.txt"
set "WAIT=ping -n 1 -w 35 192.0.2.1 >nul"
set "full=########################################"
set "none=........................................"
set "PSRUN=powershell -NoProfile -ExecutionPolicy Bypass -Command"
set "PSLOAD=$p=[IO.File]::ReadAllText($env:BF_SELF) -split ('#__'+'PS__'); "

rem ---- ANSI colour codes ----------------------------------------------------
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "cyan=!ESC![96m"
set "yel=!ESC![93m"
set "grn=!ESC![92m"
set "red=!ESC![91m"
set "wht=!ESC![97m"
set "gry=!ESC![90m"
set "rst=!ESC![0m"

rem ==========================================================================
:intro
cls
echo.
call :printart B 51 1 3
echo.
echo  !gry!      Find the heaviest files in EVERY folder on EVERY drive!rst!
echo.
call :fakeload

net session >nul 2>&1
if not errorlevel 1 goto menu
echo.
echo  !yel![WARNING]!rst! Not running as Administrator.
echo            Some system folders will be skipped, so the scan won't be 100%% complete.
echo.
choice /c YN /n /m "  Restart as Administrator for a full scan? [Y/N]: "
if errorlevel 2 goto menu
powershell -NoProfile -Command "Start-Process -FilePath $env:BF_SELF -Verb RunAs"
if errorlevel 1 goto menu
exit /b

rem ==========================================================================
:menu
set "BF_ORDER=D"
set "BF_TOP=10"
set "BF_DRIVES="
set "BF_MIN="
cls
call :printart B 51 0 3
echo.
echo  !gry!------------------------------------------------------------------------------!rst!
echo  !wht! STEP 1/4!rst!  !cyan!How should I sort the results?!rst!
echo.
echo       !yel![1]!rst!  Biggest to Smallest
echo       !yel![2]!rst!  Smallest to Biggest
echo.
choice /c 12 /n /m "      Your choice [1/2]: "
if errorlevel 2 set "BF_ORDER=A"

echo.
echo  !gry!------------------------------------------------------------------------------!rst!
echo  !wht! STEP 2/4!rst!  !cyan!How many files do you want to see?!rst!
echo.
echo       !yel![1]!rst! Top 10    !yel![2]!rst! Top 25    !yel![3]!rst! Top 50    !yel![4]!rst! Top 100    !yel![5]!rst! Custom
echo.
choice /c 12345 /n /m "      Your choice [1-5]: "
if errorlevel 2 set "BF_TOP=25"
if errorlevel 3 set "BF_TOP=50"
if errorlevel 4 set "BF_TOP=100"
if errorlevel 5 goto ask_top
goto step3

:ask_top
set "BF_TOP="
set /p "BF_TOP=      How many files [1-9999]: "
if not defined BF_TOP goto ask_top
for /f "delims=0123456789" %%a in ("!BF_TOP!") do goto ask_top
if not "!BF_TOP:~4!"=="" goto ask_top

:step3
echo.
echo  !gry!------------------------------------------------------------------------------!rst!
echo  !wht! STEP 3/4!rst!  !cyan!Which storage drives should I search?!rst!
%PSRUN% "%PSLOAD% iex $p[6]"
:ask_drives
echo       !gry!Press Enter for ALL drives, or type letters like:  C D E!rst!
set "sel="
set /p "sel=      Drives to scan: "
if not defined sel goto drives_all
if "!sel!"=="*" goto drives_all
if /i "!sel!"=="ALL" goto drives_all

set "clean=!sel!"
set "BF_DRIVES="
:parse_loop
if not defined clean goto parse_done
set "ch=!clean:~0,1!"
set "clean=!clean:~1!"
if "!ch!"==" " goto parse_loop
if exist "!ch!:\" (
    set "tmp=,!BF_DRIVES!,"
    if "!tmp:,%ch%,=!"=="!tmp!" (
        if defined BF_DRIVES (set "BF_DRIVES=!BF_DRIVES!,!ch!") else set "BF_DRIVES=!ch!"
    )
)
goto parse_loop
:parse_done
if not defined BF_DRIVES (
    echo       !red!No valid drive found, try again.!rst!
    goto ask_drives
)
goto step4
:drives_all
set "BF_DRIVES=ALL"

:step4
if "!BF_ORDER!"=="D" (set "defmin=1") else set "defmin=0"
echo.
echo  !gry!------------------------------------------------------------------------------!rst!
echo  !wht! STEP 4/4!rst!  !cyan!Ignore files smaller than how many MB?!rst!
echo       !gry!Higher = faster scan. Enter = !defmin! MB. Use 0 to include everything.!rst!
:ask_min
set "BF_MIN="
set /p "BF_MIN=      Minimum size in MB: "
if not defined BF_MIN set "BF_MIN=!defmin!"
for /f "delims=0123456789" %%a in ("!BF_MIN!") do goto ask_min
if not "!BF_MIN:~6!"=="" goto ask_min

if "!BF_ORDER!"=="D" (set "ordtxt=Biggest to Smallest") else set "ordtxt=Smallest to Biggest"
if "!BF_DRIVES!"=="ALL" (set "drvtxt=ALL DRIVES") else set "drvtxt=!BF_DRIVES!"
echo.
echo  !gry!------------------------------------------------------------------------------!rst!
echo  !wht! MISSION BRIEFING!rst!
echo       Order    : !yel!!ordtxt!!rst!
echo       Results  : !yel!Top !BF_TOP!!rst!
echo       Drives   : !yel!!drvtxt!!rst!
echo       Min size : !yel!!BF_MIN! MB!rst!
echo.
choice /c YN /n /m "      Start the hunt? [Y = go, N = change settings]: "
if errorlevel 2 goto menu

rem ==========================================================================
:scan
cls
echo.
call :printart S 214 0 2
echo.
echo  !wht! HUNTING...!rst!  !gry!This can take a while on big drives. Sit back.!rst!
echo.
del "%BF_DONE%" "%BF_OUT%" "%BF_STATUS%" >nul 2>&1
start "" /b %PSRUN% "%PSLOAD% iex $p[1]" >nul 2>&1

set /a pos=1, dir=1, f=0
set "spin=|/-\"
call :clock
set "T0=!now!"
:spin_loop
if exist "%BF_DONE%" goto spin_end
set /a pos+=dir
if !pos! geq 24 set "dir=-1"
if !pos! leq 1 set "dir=1"
set /a f=(f+1)%%4, rest=25-pos
call :elapsed
set "cur=Starting..."
if exist "%BF_STATUS%" ( 2>nul set /p cur=<"%BF_STATUS%" )
<nul set /p "=!ESC![1G  !cyan![!gry!!none:~0,%pos%!!ESC![96m#####!gry!!none:~0,%rest%!!cyan!]!rst! !yel!!spin:~%f%,1!!rst!  Scanning !wht!!cur!!rst!  !gry!!mm!:!ss!!rst! !ESC![K"
%WAIT%
goto spin_loop

:spin_end
call :elapsed
<nul set /p "=!ESC![1G!ESC![K"
echo  !grn![OK]!rst! Scan finished in !wht!!mm!:!ss!!rst!
ping -n 2 127.0.0.1 >nul

rem ==========================================================================
:results
cls
echo.
call :printart R 226 0 1
echo.
echo  !grn! SCAN COMPLETE!rst!  !gry!time !mm!:!ss!   order: !ordtxt!   drives: !drvtxt!!rst!
echo.
%PSRUN% "%PSLOAD% iex $p[2]"
echo.
:actions
echo  !gry!------------------------------------------------------------------------------!rst!
echo   !yel![O]!rst! Open file location    !yel![D]!rst! Delete to Recycle Bin    !yel![S]!rst! Save CSV report
echo   !yel![N]!rst! New scan              !yel![Q]!rst! Quit
choice /c ODSNQ /n /m "  Choose: "
if errorlevel 5 goto quit
if errorlevel 4 goto menu
if errorlevel 3 goto act_save
if errorlevel 2 goto act_delete

:act_open
set "BF_PICK="
set /p "BF_PICK=  Enter result number: "
%PSRUN% "%PSLOAD% iex $p[3]"
goto actions

:act_delete
set "BF_PICK="
set /p "BF_PICK=  Enter result number to delete: "
%PSRUN% "%PSLOAD% iex $p[5]"
goto actions

:act_save
%PSRUN% "%PSLOAD% iex $p[4]"
goto actions

:quit
del "%BF_DONE%" "%BF_OUT%" "%BF_STATUS%" >nul 2>&1
echo.
echo  !cyan!  Thanks for hunting! Stay lean.!rst!
echo.
endlocal
exit /b

rem ==========================================================================
rem  SUBROUTINES
rem ==========================================================================

:printart
rem  %1 = art tag, %2 = start colour (0-255), %3 = 1 for line-by-line delay, %4 = colour step
set "stp=%~4"
if not defined stp set "stp=3"
set /a idx=0
for /f "delims=" %%L in ('findstr /b /c:":::%~1 " "%BF_SELF%"') do (
    set "ln=%%L"
    set /a col=%~2 - idx*stp
    echo !ESC![38;5;!col!m!ln:~5!!ESC![0m
    set /a idx+=1
    if "%~3"=="1" %WAIT%
)
exit /b

:fakeload
set /a n=1
:fl_loop
set /a pct=n*100/40
set "msg=Warming up the engines"
if !n! geq 10 set "msg=Loading modules"
if !n! geq 20 set "msg=Detecting storage drives"
if !n! geq 30 set "msg=Calibrating file radar"
<nul set /p "=!ESC![1G  !cyan![!grn!!full:~0,%n%!!gry!!none:~%n%!!cyan!]!rst! !pct!%%  !msg!!ESC![K"
%WAIT%
set /a n+=1
if !n! lss 40 goto fl_loop
<nul set /p "=!ESC![1G  !cyan![!grn!!full!!cyan!]!rst! 100%%  Ready to hunt!ESC![K"
echo.
%WAIT%
exit /b

:clock
set "t=%time: =0%"
set /a now=(1!t:~0,2!-100)*3600+(1!t:~3,2!-100)*60+(1!t:~6,2!-100)
exit /b

:elapsed
call :clock
set /a el=now-T0
if !el! lss 0 set /a el+=86400
set /a mm=el/60, ss=el%%60
if !ss! lss 10 set "ss=0!ss!"
if !mm! lss 10 set "mm=0!mm!"
exit /b

rem ==========================================================================
rem  Nothing below this line is executed by cmd.exe
rem ==========================================================================
exit /b

:::B   ####   ###   ####       #####  ###  #      #####
:::B   #   #   #   #           #       #   #      #
:::B   ####    #   #  ##       ####    #   #      ####
:::B   #   #   #   #   #       #       #   #      #
:::B   ####   ###   ####       #      ###  #####  #####
:::B   #   #  #   #  #   #  #####  #####  ####
:::B   #   #  #   #  ##  #    #    #      #   #
:::B   #####  #   #  # # #    #    ####   ####
:::B   #   #  #   #  #  ##    #    #      #  #
:::B   #   #   ###   #   #    #    #####  #   #

:::S        .---.
:::S      .'     '.
:::S     /         \
:::S    |           |
:::S     \         /
:::S      '.     .'
:::S        '---'.
:::S               '.
:::S                 '.
:::S                   '-.

:::R       ___________
:::R      '._==_==_=_.'
:::R      .-\:      /-.
:::R     | (|:.     |) |
:::R      '-|:.     |-'
:::R        \::.    /
:::R         '::. .'
:::R           ) (
:::R         _.' '._
:::R        '-------'

#__PS__
# ---------------------------- SECTION 1 : SCANNER ----------------------------
$ErrorActionPreference = 'SilentlyContinue'
try {
    $min = [int64]$env:BF_MIN * 1MB
    $top = [int]$env:BF_TOP
    if ($top -lt 1) { $top = 10 }

    if ($env:BF_DRIVES -eq 'ALL') {
        $roots = [IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady } | ForEach-Object { $_.Name }
    } else {
        $roots = $env:BF_DRIVES -split ',' | ForEach-Object { $_ + ':\' }
    }

    $n = 0
    $all = foreach ($r in $roots) {
        Set-Content -Path $env:BF_STATUS -Value $r
        Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue |
            ForEach-Object {
                $n++
                if (($n % 2000) -eq 0) {
                    Set-Content -Path $env:BF_STATUS -Value ($r + '  [' + $n.ToString('N0') + ' files checked]')
                }
                if ($_.Length -ge $min) {
                    [pscustomobject]@{ FullName = $_.FullName; Length = $_.Length }
                }
            }
    }

    if ($env:BF_ORDER -eq 'D') { $sorted = $all | Sort-Object Length -Descending }
    else                       { $sorted = $all | Sort-Object Length }

    $sorted | Select-Object -First $top | Export-Csv -Path $env:BF_OUT -NoTypeInformation -Encoding UTF8
}
finally {
    New-Item -ItemType File -Path $env:BF_DONE -Force | Out-Null
}
#__PS__
# ---------------------------- SECTION 2 : RESULTS TABLE ----------------------
$ErrorActionPreference = 'SilentlyContinue'
function Fmt([double]$b) {
    if     ($b -ge 1TB) { '{0:N2} TB' -f ($b / 1TB) }
    elseif ($b -ge 1GB) { '{0:N2} GB' -f ($b / 1GB) }
    elseif ($b -ge 1MB) { '{0:N2} MB' -f ($b / 1MB) }
    elseif ($b -ge 1KB) { '{0:N2} KB' -f ($b / 1KB) }
    else                { '{0} B' -f [int64]$b }
}
if (-not (Test-Path $env:BF_OUT)) {
    Write-Host '  No files matched your filters. Try a smaller minimum size.' -ForegroundColor Yellow
    return
}
$rows = @(Import-Csv -Path $env:BF_OUT)
$max = ($rows | ForEach-Object { [int64]$_.Length } | Measure-Object -Maximum).Maximum
if (-not $max) { $max = 1 }
$w = $Host.UI.RawUI.WindowSize.Width
if (-not $w -or $w -lt 60) { $w = 100 }
$pw = [Math]::Max(20, $w - 46)

Write-Host ('  {0,-5} {1,11}  {2,-20}  {3}' -f '#', 'SIZE', 'GRAPH', 'PATH') -ForegroundColor White
Write-Host ('  ' + ('-' * ($w - 4))) -ForegroundColor DarkGray
$i = 0
foreach ($r in $rows) {
    $i++
    $len = [int64]$r.Length
    $col = if     ($len -ge 1GB)   { 'Red' }
           elseif ($len -ge 100MB) { 'Yellow' }
           elseif ($len -ge 10MB)  { 'Cyan' }
           else                    { 'Green' }
    $k = [int][Math]::Round(20 * $len / $max)
    if ($k -lt 1) { $k = 1 }
    $bar = ('#' * $k).PadRight(20, '.')
    $p = $r.FullName
    if ($p.Length -gt $pw) { $p = '...' + $p.Substring($p.Length - $pw + 3) }
    Write-Host ('  {0,-5} {1,11}  ' -f $i, (Fmt $len)) -NoNewline -ForegroundColor $col
    Write-Host $bar -NoNewline -ForegroundColor $col
    Write-Host ('  ' + $p) -ForegroundColor Gray
}
$total = ($rows | ForEach-Object { [int64]$_.Length } | Measure-Object -Sum).Sum
Write-Host ('  ' + ('-' * ($w - 4))) -ForegroundColor DarkGray
Write-Host ('  Showing {0} file(s), combined size: {1}' -f $rows.Count, (Fmt $total)) -ForegroundColor White
Write-Host '  Colors:  red = 1 GB+   yellow = 100 MB+   cyan = 10 MB+   green = smaller' -ForegroundColor DarkGray
#__PS__
# ---------------------------- SECTION 3 : OPEN LOCATION ----------------------
$rows = @(Import-Csv -Path $env:BF_OUT)
$n = 0
[void][int]::TryParse($env:BF_PICK, [ref]$n)
if ($n -ge 1 -and $n -le $rows.Count) {
    Start-Process explorer.exe -ArgumentList ('/select,"' + $rows[$n - 1].FullName + '"')
} else {
    Write-Host '  Invalid number.' -ForegroundColor Red
}
#__PS__
# ---------------------------- SECTION 4 : SAVE CSV REPORT --------------------
$desk = [Environment]::GetFolderPath('Desktop')
$dest = Join-Path $desk ('BigFileReport_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.csv')
if (Test-Path $env:BF_OUT) {
    Copy-Item $env:BF_OUT $dest
    Write-Host ('  Report saved to: ' + $dest) -ForegroundColor Green
} else {
    Write-Host '  Nothing to save.' -ForegroundColor Yellow
}
#__PS__
# ---------------------------- SECTION 5 : DELETE TO RECYCLE BIN --------------
$rows = @(Import-Csv -Path $env:BF_OUT)
$n = 0
[void][int]::TryParse($env:BF_PICK, [ref]$n)
if ($n -ge 1 -and $n -le $rows.Count) {
    $p = $rows[$n - 1].FullName
    Write-Host ''
    Write-Host ('  Move to Recycle Bin: ' + $p) -ForegroundColor Yellow
    $a = Read-Host '  Type YES to confirm'
    if ($a -ceq 'YES') {
        try {
            Add-Type -AssemblyName Microsoft.VisualBasic
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'AllDialogs', 'SendToRecycleBin')
            Write-Host '  Done.' -ForegroundColor Green
        } catch {
            Write-Host ('  Failed: ' + $_.Exception.Message) -ForegroundColor Red
        }
    } else {
        Write-Host '  Cancelled.' -ForegroundColor DarkGray
    }
} else {
    Write-Host '  Invalid number.' -ForegroundColor Red
}
#__PS__
# ---------------------------- SECTION 6 : DRIVE LIST -------------------------
$ErrorActionPreference = 'SilentlyContinue'
Write-Host ''
foreach ($d in [IO.DriveInfo]::GetDrives()) {
    $letter = $d.Name.Substring(0, 1)
    if ($d.IsReady) {
        $col = switch ($d.DriveType) { 'Fixed' { 'Green' } 'Removable' { 'Yellow' } 'Network' { 'Magenta' } default { 'Gray' } }
        $tot  = [Math]::Round($d.TotalSize / 1GB, 1)
        $free = [Math]::Round($d.AvailableFreeSpace / 1GB, 1)
        Write-Host ('       [{0}]  {1,-10} {2,-18} {3,9} GB total {4,9} GB free' -f $letter, $d.DriveType, $d.VolumeLabel, $tot, $free) -ForegroundColor $col
    } else {
        Write-Host ('       [{0}]  not ready' -f $letter) -ForegroundColor DarkGray
    }
}
Write-Host ''