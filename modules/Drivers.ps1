Import-Module .\api.ps1

function getAllDrivers() {
    $driverHashes = [System.Collections.ArrayList]::new()
    Get-ChildItem "C:\Windows\System32\drivers" -Recurse | ForEach-Object {
        if(!(Test-Path "$($_.FullName)" -PathType Container)) {
            $hash = (Get-FileHash -Algorithm SHA256 "$($_.FullName)").Hash
            $driverHashes.Add($hash) | Out-Null
        }
    }
    return $driverHashes
}

$fileName = GetBaselineFileName
$isCreatingBaseline = (Read-Host "Are you generating a driver baseline? (y/n)").ToLower() -eq "y"

if($isCreatingBaseline) {
    $drivers = getAllDrivers
    (ConvertTo-Json $drivers) > ".\baselines\drivers\$fileName.txt"
    Write-Output "Baseline has been generated"
    exit
}

Write-Output "Fetching baseline"

if(!(Test-Path ".\baselines\drivers\$fileName.txt")) {
    Write-Output "Baseline file not found, stopping script"
    exit
}

$baselineDrivers = [System.Collections.ArrayList]((Get-Content ".\baselines\drivers\$fileName.txt") | ConvertFrom-Json)

Get-ChildItem "C:\Windows\System32\drivers" -Recurse | ForEach-Object {
    if(!(Test-Path "$($_.FullName)" -PathType Container)) {
        $hash = (Get-FileHash -Algorithm SHA256 "$($_.FullName)").Hash
        if(!$baselineDrivers.Contains($hash)) {
            Write-Host "The following driver, $($_.FullName), is installed but not part of the baseline. Investigate" -ForegroundColor Red
        }
    }
}