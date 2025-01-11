$isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"
if(!$isADInstalled) {
    Write-Output "This is an AD specific tool"
    exit
}

$ErrorActionPreference = "SilentlyContinue"

if(!(Get-Command -Name "docker")) { # Install Docker if docker command not found
    curl.exe -o ".\DockerInstaller.exe" "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    Write-Output "Downloaded the Docker Installer (you actually need to follow the installer's directions when it says to either restart or logoff)"
    Write-Output "You also need to run the installer manually (its in the script's main directory) since TI fucks with it"
    Write-Output "UNCHECK THE WSL OPTION"
    exit
}

$ErrorActionPreference = "Continue"

if(Test-Path ".\DockerInstaller.exe") {
    del ".\DockerInstaller.exe"
}

if(!(Test-Path ".\tools\BloodHound")) {
    mkdir .\tools\BloodHound | Out-Null
    cd .\tools\BloodHound
    (curl.exe -L https://ghst.ly/getbhce) > docker-compose.yml
    $sharpHoundVersion = (Invoke-RestMethod "https://api.github.com/repos/SpecterOps/SharpHound/releases/latest").name
    curl.exe -o "SharpHound.zip" -L "https://github.com/SpecterOps/SharpHound/releases/download/$sharpHoundVersion/SharpHound-$sharpHoundVersion.zip"
    Expand-Archive -Path ".\SharpHound.zip" -DestinationPath ".\SharpHound"
    del ".\SharpHound.zip"
    .\SharpHound\SharpHound.exe
} else {
    cd .\tools\BloodHound
}

clear
Write-Output "BloodHound will be started shortly. The username is admin, but unfortunately, you'll need to find the random password generated for it in the console logs"
Write-Output "Once you login, you'll be asked to change your password: WRITE IT DOWN SOMEWHERE"
Write-Output "Once you're done, if you'd like to cleanup, open the Docker GUI and go through all the tabs and delete everything"
pause

docker compose pull ;; docker compose up