if(($PSVersionTable.PSVersion | Select-Object -ExpandProperty Major) -lt 3){
    Write-Output "The current Powershell version does not support PSScriptRoot, stopping..."
    exit
}

$isElevated = (whoami.exe) -eq "nt authority\system"
if(-not $isElevated) {
    Write-Output "Script not being run with TrustedInstaller permissions, elevating..."
    .\tools\AdvancedRun.exe /StartDirectory "$PSScriptRoot" /CommandLine "& '.\Enable Scripts.bat' ; .\main.ps1 '$($Env:Username)'" /RunMode 4 /RunAs 4 /Run
    exit
}

Set-MpPreference -ExclusionPath ($PSScriptRoot)
Set-MpPreference -AttackSurfaceReductionOnlyExclusions ($PSScriptRoot)

cmd /c color # Make colored printing work

if(!(Test-Path .\CURRENT_USER.txt)) {
    $args[0] | Out-File -FilePath .\CURRENT_USER.txt
}

$modulePath = $PSScriptRoot + "\modules"
$modules = @(Get-ChildItem -Path $modulePath -Filter *.ps1)

function printMenu() {
    $num = 1
    Write-Output "Choose an option below`n`n"
    $modules | ForEach-Object {
        $name = $_.ToString().Substring(0, $_.ToString().IndexOf("."));
        Write-Output "[$num] $name`n"
        $num += 1
    }
}

while($true) {
    clear
    printMenu
    $index = [int](Read-Host "Enter a number") - 1
    If($index -lt 0 -or $index -ge $modules.Count) { continue }
    clear
    powershell.exe -File "$($modulePath)\$($modules[$index].Name)"
    Write-Output ""
    pause
}
