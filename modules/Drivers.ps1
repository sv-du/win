Import-Module .\api.ps1

function getAllDrivers() {
    # Code later
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

# Code later

Write-Output "Fetching unsigned drivers"

# Code later