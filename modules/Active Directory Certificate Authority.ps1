Import-Module .\api.ps1

if(!((GetSettings).ADInstalled)) {
    Write-Output "This is an active directory specific module"
    exit
}

Add-WindowsFeature Adcs-Cert-Authority -IncludeManagementTools
Install-AdcsCertificationAuthority -CAtype EnterpriseRootCA

net.exe stop ntds /y
net.exe start ntds

Write-Output "Finding vulnerable certificates"

.\tools\certify.exe find /vulnerable

Write-Output "Delete any certificates that pop up"