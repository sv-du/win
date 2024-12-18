$isCreatingBaseline = (Read-Host "Are you generating a driver baseline? (y/n)").ToLower() -eq "y"

if($isCreatingBaseline) {
    $fileName = $null
    $version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
    while(!@("10", "11", "19", "22").Contains($version)) {
        $version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
    }
    if($version -eq "10" -or $version -eq "11") {
        $fileName = $version + ".txt"
    } else {
        $isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"
        if($isADInstalled) {
            $fileName = $version + "-AD.txt"
        } else {
            $fileName = $version + ".txt"
        }
    }
    (Get-WindowsDriver -Online -All | ConvertTo-JSON) > ".\baselines\drivers\$fileName"
    Write-Output "Baseline has been generated"
    exit
}

$version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
while(!@("10", "11", "19", "22").Contains($version)) {
    $version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
}
if($version -eq "10" -or $version -eq "11") {
    $fileName = $version
} else {
    $isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"
    if($isADInstalled) {
        $fileName = $version + "-AD"
    } else {
        $fileName = $version
    }
}

Write-Output "Fetching baseline"

if(!(Test-Path ".\baselines\drivers\$fileName.txt")) {
    Write-Output "Baseline file not found, stopping script"
    exit
}

$computerDrivers = Get-WindowsDriver -Online -All
$baselineDrivers = Get-Content ".\baselines\drivers\$fileName.txt" | ConvertFrom-Json

function findDriver($arr, $name) {
    for($i = 0; $i -lt $arr.Count; $i++) {
        if($arr[$i].Driver -eq $name) { return $arr[$i] }
    }
    return $null
}

foreach($driver in $computerDrivers) {
    $baselineDriverData = findDriver($baselineDrivers) -name "$($driver.Driver)"
    if(!$baselineDriverData) { # Flag drivers not in baseline but installed
        Write-Output $driver
    }
}

Write-Output "Fetching unsigned drivers"

foreach($driver in $computerDrivers) {
    if($driver.DriverSignature -ne "Signed") {
        Write-Output $driver
    }
}