Import-Module .\api.ps1

if(!((GetSettings).ADInstalled)) {
    Write-Output "This is an active directory specific module"
    exit
}

if(!(Test-Path ".\tools\PingCastle")) {
    $downloadURL = (Invoke-RestMethod "https://api.github.com/repos/netwrix/pingcastle/releases/latest").assets[0].browser_download_url
    curl.exe -o "PingCastle.zip" -L "$downloadURL"
    Expand-Archive -Path ".\PingCastle.zip" -DestinationPath ".\tools\PingCastle"
    del ".\PingCastle.zip"
    cd .\tools\PingCastle
} else {
    cd .\tools\PingCastle
}

.\PingCastleAutoUpdater.exe
.\PingCastle.exe