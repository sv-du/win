$res = Read-Host "This can take a while depending on the system. Are you sure you want to run this? (y/n)"

if($res -ne "y") { exit }

if(!(Test-Path .\tools\winPEASany_ofs.exe)) {
    Invoke-WebRequest https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASany_ofs.exe -OutFile tools\winPEASany_ofs.exe
}

Read-Host "If colored outputs don't work, quit the script using CTRL + C, run 'cmd /c color' and then run the script again"

.\tools\winPEASany_ofs.exe -lolbas