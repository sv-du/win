if(!(Test-Path .\tools\BlueSpawn)) {
    mkdir .\tools\BlueSpawn
    $assets = ((Invoke-WebRequest "https://api.github.com/repos/ION28/BLUESPAWN/releases" -UseBasicParsing) | ConvertFrom-Json)[0].assets
    foreach($asset in $assets) {
        if($asset.Name.Contains("x64")) {
            $url = $asset.browser_download_url
            Invoke-WebRequest $url -OutFile .\tools\BlueSpawn\BlueSpawn.exe
        }
    }
}

clear

$action = (Read-Host "What would you like BlueSpawn to do? (audit/hunt/monitor)").ToLower()

while(!@("audit", "hunt", "monitor").Contains($action)) {
    clear
    $action = (Read-Host "What would you like BlueSpawn to do? (audit/hunt/monitor)").ToLower()
}

if($action -eq "audit") {
    .\tools\BlueSpawn\BlueSpawn.exe --mitigate --mode=audit --aggressiveness intensive
} elseif($action -eq "hunt") {
    .\tools\BlueSpawn\BlueSpawn.exe --hunt --aggressiveness intensive
} else {
    .\tools\BlueSpawn\BlueSpawn.exe --monitor --aggressiveness intensive
}