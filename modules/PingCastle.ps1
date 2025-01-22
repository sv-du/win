$isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"
if(!$isADInstalled) {
    Write-Output "This is an AD specific tool"
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