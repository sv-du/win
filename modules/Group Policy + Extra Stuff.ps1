function downloadHardeningKitty() {
    if(Test-Path .\tools\HardeningKitty) { Remove-Item .\tools\HardeningKitty\ -Recurse }
    $link = ((Invoke-WebRequest "https://api.github.com/repos/scipag/HardeningKitty/releases/latest" -UseBasicParsing) | ConvertFrom-Json).zipball_url
    Invoke-WebRequest $link -Out .\tools\HardeningKitty.zip
    Expand-Archive -Path ".\tools\HardeningKitty.zip" -Destination ".\tools\HardeningKitty" -Force
    Remove-Item .\tools\HardeningKitty.zip -Force
    $randomFolderName = (Get-ChildItem ".\tools\HardeningKitty")[0].Name
    Move-Item -Path ".\tools\HardeningKitty\$randomFolderName" -Destination ".\tools\"
    Remove-Item .\tools\HardeningKitty -Recurse
    Rename-Item ".\tools\$randomFolderName" -NewName "HardeningKitty"
}

Write-Output "Downloading HardeningKitty"

downloadHardeningKitty

Import-Module .\tools\HardeningKitty\HardeningKitty.psm1

clear

$version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
$isADInstalled = $false

while(!@("10", "11", "19", "22").Contains($version)) {
    $version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
}

$name = $version

if($version -eq "19" -or $version -eq "22") {
    $isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"
    if($isADInstalled) {
        $name += "-AD"
    }
}

$lists = @{
    global = @(
        "finding_list_0x6d69636b_machine.csv",
        "finding_list_0x6d69636b_user.csv",
        "finding_list_dod_windows_defender_antivirus_stig_v2r1.csv",
        "finding_list_microsoft_windows_tls.csv",
        "finding_list_microsoft_windows_tls_future.csv"
    )
    "10" = @(
        "finding_list_cis_microsoft_windows_10_enterprise_22h2_machine.csv",
        "finding_list_cis_microsoft_windows_10_enterprise_22h2_user.csv",
        "finding_list_dod_microsoft_windows_10_stig_v2r1_machine.csv",
        "finding_list_dod_microsoft_windows_10_stig_v2r1_user.csv"
    )
    "11" = @(
        "finding_list_cis_microsoft_windows_11_enterprise_22h2_machine.csv",
        "finding_list_cis_microsoft_windows_11_enterprise_22h2_user.csv"
    )
    "19" = @(
        "finding_list_cis_microsoft_windows_server_2019_1809_3.0.0_machine.csv",
        "finding_list_cis_microsoft_windows_server_2019_1809_3.0.0_user.csv"
    )
    "19-AD" = @(
        "finding_list_cis_microsoft_windows_server_2019_1809_3.0.0_machine.csv",
        "finding_list_cis_microsoft_windows_server_2019_1809_3.0.0_user.csv",
        "finding_list_dod_microsoft_windows_server_2019_dc_stig_v2r1_machine.csv",
        "finding_list_dod_microsoft_windows_server_2019_dc_stig_v2r1_user.csv"
    )
    "22" = @(
        "finding_list_cis_microsoft_windows_server_2022_22h2_3.0.0_machine.csv"
        "finding_list_cis_microsoft_windows_server_2022_22h2_3.0.0_user.csv"
    )
    "22-AD" = @(
        "finding_list_cis_microsoft_windows_server_2022_22h2_3.0.0_machine.csv"
        "finding_list_cis_microsoft_windows_server_2022_22h2_3.0.0_user.csv"
    )
}

if($isADInstalled) {
    Write-Output "Disabling pre-existing GPOs"
    $GPOs = Get-GPO -All
    foreach($GPO in $GPOs) {
        $GPO.GpoStatus = "AllSettingsDisabled"
        Write-Output "GPO $($GPO.DisplayName) status set to AllSettingsDisabled"
    }
    gpupdate.exe /force
    clear
    Write-Output "Check GPO permissions manually (gpmc.msc > Domains > <domain name> > Group Policy Objects > <gp name> > Delegation > Right Click Entry)"
}

$cleanGPO = (Read-Host "Remove GPO files? (may break some stuff) (y/n)") -eq "y"

if($cleanGPO) {
    Remove-Item -Recurse -Force "$env:WinDir\System32\GroupPolicy" | Out-Null
    Remove-Item -Recurse -Force "$env:WinDir\System32\GroupPolicyUsers" | Out-Null
    secedit.exe /configure /cfg "$env:WinDir\inf\defltbase.inf" /db defltbase.sdb /verbose | Out-Null
    gpupdate.exe /force
}

foreach($list in $lists.global) {
    Invoke-HardeningKitty -Mode HailMary -FileFindingList ".\tools\HardeningKitty\lists\$list" -SkipMachineInformation -SkipRestorePoint
}

foreach($list in $lists[$name]) {
    Invoke-HardeningKitty -Mode HailMary -FileFindingList ".\tools\HardeningKitty\lists\$list" -SkipMachineInformation -SkipRestorePoint
}

Write-Output "Before continuing, please manually import the files\LSP files into their respective places"
if($isADInstalled) {
    Write-Output "Also before continuing, ensure the following Kerberos policies (secpol.msc > Account Policies > Kerberos Policy)"
    Write-Output "Enforce user logon restrictions: Enabled"
    Write-Output "Maximum lifetime for service ticket: 600 minutes"
    Write-Output "Maximum lifetime for user ticket: 10 hours"
    Write-Output "Maximum lifetime for user ticket renewal: 7 days"
    Write-Output "Maximum tolerance for computer clock synchronization: 5 minutes"
}
pause

$disableSignedElevation = (Read-Host "Do you want to disable that only signed executables can run (fixes script elevation)? (y/n)") -eq "y"
if($disableSignedElevation) {
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ValidateAdminCodeSignatures /t REG_DWORD /d 0 /f
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Creating non-default PS drives for registry" -ForegroundColor white

$CURRENT_USER_SID = ("" + (cmd /c ('wmic useraccount where name="{0}" get sid' -f (Get-Content .\CURRENT_USER.txt)))[2]).Trim()

if(!$CURRENT_USER_SID -or !$CURRENT_USER_SID.StartsWith("S-")) {
    Write-Host "FAILED TO GET CURRENT USER SID" -ForegroundColor Red
    Write-Host "Run the following command in COMMAND PROMPT" -ForegroundColor Yellow
    Write-Host ('wmic useraccount where name="{0}" get sid' -f (Get-Content .\CURRENT_USER.txt)) -ForegroundColor Yellow
    $CURRENT_USER_SID = (Read-Host "Enter the SID returned by the above command").Trim()
} else {
    Write-Host "CURRENT USER SID FOUND: $CURRENT_USER_SID" -ForegroundColor Green
    pause
}

# We are running on the SYSTEM account ; Remap PS HKCU drive to our old user drive
Remove-PSDrive -Name HKCU
New-PSDrive -Name HKCU -PSProvider Registry -Root "HKEY_USERS\$CURRENT_USER_SID"

New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
New-PSDrive -Name HU -PSProvider Registry -Root HKEY_USERS
New-PSDrive -Name HCC -PSProvider Registry -Root HKEY_CURRENT_CONFIG

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Remove Shadow Copies" -ForegroundColor white
vssadmin delete shadows /all

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable VerboseStatus" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v verbosestatus /t REG_DWORD /d 1 /f | Out-Null
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStatusMessages /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Harden RDP" -ForegroundColor white

reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v CachedLogonsCount /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"/t REG_DWORD /v fSingleSessionPerUser /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableLPT /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableCdm /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDisableCpm /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v SecurityLayer /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v AllowTSConnections /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fAllowToGetHelp /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MinEncryptionLevel /t REG_DWORD /d 3 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\Windows NT\Terminal Services" /v "AllowSignedFiles" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\Windows NT\Terminal Services" /v "AllowUnsignedFiles" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\Windows NT\Terminal Services" /v "DisablePasswordSaving" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Conferencing" /v "NoRDS" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\WinRS" /v "AllowRemoteShellAccess" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "AllowSignedFiles" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "AllowUnsignedFiles" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "CreateEncryptedOnlyTickets" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "DisablePasswordSaving" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fAllowToGetHelp" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fAllowUnsolicited" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fDenyTSConnections" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client" /v "fEnableUsbBlockDeviceBySetupClass" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client" /v "fEnableUsbNoAckIsochWriteToDevice" /t REG_DWORD /d 80 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client" /v "fEnableUsbSelectDeviceByInterface" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile\RemoteAdminSettings" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile\Services\RemoteDesktop" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile\Services\UPnPFramework" /v "Enabled" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "Shadow" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "DisableShadowConsent" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fDisableCcm" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTЕM\CurrеntControlSеt\Control\Tеrminal Sеrvеr" /v "AllowRemotеRPC" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fInheritInitialProgram /t REG_DWORD /d 0 /f | Out-Null
reg delete "HKU\$CURRENT_USER_SID\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v InitialProgram /f | Out-Null
reg delete "HKU\$CURRENT_USER_SID\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v WorkDirectory /f | Out-Null

$enableRDP = (Read-Host "Enable RDP? (y/n)") -eq "y"

if($enableRDP) {
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f | Out-Null
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v AllowTSConnections /t REG_DWORD /d 1 /f | Out-Null
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fDenyTSConnections /t REG_DWORD /d 0 /f | Out-Null
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable Windows Updates" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AutoInstallMinorUpdates /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v AUOptions /t REG_DWORD /d 4 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ElevateNonAdmins /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWUfBSafeguard /t REG_DWORD /d 0 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoWindowsUpdate /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\Internet Communication Management\Internet Communication" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f | Out-Null


Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Restrict CD ROM drive" -ForegroundColor white
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AllocateCDRoms /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable remote access to floppy disk" -ForegroundColor white
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AllocateFloppies /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable auto admin login" -ForegroundColor white
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Clear page file on shutdown" -ForegroundColor white
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable user ability to add print drivers" -ForegroundColor white
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers" /v AddPrinterDrivers /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] LSASS.exe configuration" -ForegroundColor white
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" /v AuditLevel /t REG_DWORD /d 00000008 /f| Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v auditbaseobjects /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v fullprivilegeauditing /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v restrictanonymous /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v restrictanonymoussam /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v disabledomaincreds /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v UseMachineId /t REG_DWORD /d 0 /f | Out-Null
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v dontdisplaylastusername /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v DisableRestrictedAdmin /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DisableRestrictedAdminOutboundCreds /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RunAsPPL /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\LSASS.exe" /v AuditLevel /t REG_DWORD /d 8 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v NoLMHash /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v SubmitControl /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v everyoneincludesanonymous /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v TokenLeakDetectDelaySecs /t REG_DWORD /d 30 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v RestrictRemoteSAM /t REG_SZ /d "O:BAG:BAD:(A;;RC;;;BA)" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 2 /f | Out-Null
reg add HKLM\System\CurrentControlSet\Control\Lsa /v SCENoApplyLegacyAuditPolicy /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] UAC" -ForegroundColor white
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d 5 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable Installer Detection" -ForegroundColor white
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableInstallerDetection /t REG_DWORD /d 1 /f
reg ADD HKLM\SOFTWARE\Microsot\Windows\CurrentVersion\Policies\System /v undockwithoutlogon /t REG_DWORD /d 0 /f
reg ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v DisableCAD /t REG_DWORD /d 0 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v DisablePasswordChange /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v RequireStrongKey /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v RequireSignOrSeal /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v SignSecureChannel /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\Netlogon\Parameters /v SealSecureChannel /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters /v FullSecureChannelProtection /t REG_DWORD /d 1 /f | Out-Null
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters /v autodisconnect /t REG_DWORD /d 45 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters /v enablesecuritysignature /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters /v requiresecuritysignature /t REG_DWORD /d 1 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters /v NullSessionPipes /t REG_MULTI_SZ /d "" /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanServer\Parameters /v NullSessionShares /t REG_MULTI_SZ /d "" /f
reg ADD HKLM\SYSTEM\CurrentControlSet\services\LanmanWorkstation\Parameters /v EnablePlainTextPassword /t REG_DWORD /d 0 /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\SecurePipeServers\winreg\AllowedExactPaths /v Machine /t REG_MULTI_SZ /d "" /f
reg ADD HKLM\SYSTEM\CurrentControlSet\Control\SecurePipeServers\winreg\AllowedPaths /v Machine /t REG_MULTI_SZ /d "" /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV8 /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Internet Explorer\PhishingFilter" /v EnabledV9 /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v DisablePasswordCaching /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v WarnonBadCertRecving /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v WarnOnPostRedirect /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Internet Explorer\Main" /v DoNotTrack /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Internet Explorer\Download" /v RunInvalidSignatures /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_LOCALMACHINE_LOCKDOWN\Settings" /v LOCALMACHINE_CD_UNLOCK /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v WarnonZoneCrossing /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
reg ADD "HKU\$CURRENT_USER_SID\.DEFAULT\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f
reg ADD "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 1 /f
reg ADD "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v CrashDumpEnabled /t REG_DWORD /d 0 /f
reg ADD "HKU\$CURRENT_USER_SID\SYSTEM\CurrentControlSet\Services\CDROM" /v AutoRun /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoAutorun" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d 255 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] IE Hardening" -ForegroundColor white
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap" /v IEHarden /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v lEHardenlENoWarn /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\Internet Explorer\PhishingFilter" /v "EnabledV9" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\PhishingFilter" /v "EnabledV9" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v SecureProtocols /t REG_DWORD /d 2048 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v SecureProtocols /t REG_DWORD /d 2048 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" /v "DEPOff" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" /v "Isolation64Bit" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main" /v Isolation /t REG_SZ /d "PMEM" /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\PrefetchPrerender" /v "Enabled" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Internet Explorer\Restrictions" /v "NoCrashDetection" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v "CallLegacyWCMPolicies" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v "EnableSSL3Fallback" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v "PreventIgnoreCertErrors" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings" /v "EnableHTTP2" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Lockdown_Zones\3" /v "1201" /t REG_DWORD /d 3 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Block Macros and Other Content Execution" -ForegroundColor white
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\access\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\excel\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\excel\security" /v "blockcontentexecutionfrominternet" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\excel\security" /v "excelbypassencryptedmacroscan" /t REG_DWORD /d 0 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\ms project\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\ms project\security" /v "level" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\outlook\security" /v "level" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\powerpoint\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\powerpoint\security" /v "blockcontentexecutionfrominternet" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\publisher\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\visio\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\visio\security" /v "blockcontentexecutionfrominternet" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\word\security" /v "vbawarnings" /t REG_DWORD /d 4 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\word\security" /v "blockcontentexecutionfrominternet" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\word\security" /v "wordbypassencryptedmacroscan" /t REG_DWORD /d 0 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\common\security" /v "automationsecurity" /t REG_DWORD /d 3 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\SystemCertificates\Root\ProtectedRoots" /v "Flags" /t REG_DWORD /d 1 /f
reg delete "HKU\$CURRENT_USER_SID\Environment" /v "UserInitMprLogonScript" /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\outlook\options\mail" /v "blockextcontent" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\office\16.0\outlook\options\mail" /v "junkmailenablelinks" /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Defender Configuration" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "ServiceKeepAlive" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "CheckForSignaturesBeforeRunningScan" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableHeuristics" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v "ScanWithAntiVirus" /t REG_DWORD /d 3 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "LocalSettingOverrideRealtimeScanDirection" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "LocalSettingOverrideDisableIOAVProtection" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "LocalSettingOverrideSpynetReporting" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting" /v "DisableGenericReports" /t REG_DWORD /d 1 /f


setx /M MP_FORCE_USE_SANDBOX 1

Add-MpPreference -AttackSurfaceReductionRules_Ids "56a863a9-875e-4185-98a7-b882c64b5ce5" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "d4f940ab-401b-4efc-aadc-ad5f3c50688a" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "be9ba2d9-53ea-4cdc-84e5-9b1eeee46550" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "01443614-cd74-433a-b99e-2ecdc07bfc25" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "5beb7efe-fd9a-4556-801d-275e5ffc04cc" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "d3e037e1-3eb8-44c8-a917-57927947596d" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "3b576869-a4ec-4529-8536-b80a7769e899" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "75668c1f-73b5-4cf0-bb93-3ecf5cb7cc84" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "26190899-1602-49e8-8b27-eb1d0a1ce869" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "e6db77e5-3df2-4cf1-b95a-636979351e5b" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "d1e49aac-8f56-4280-b9ba-993a6d77406c" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "a8f5898e-1dc8-49a9-9878-85004b8a61e6" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "92e97fa1-2edf-4476-bdd6-9dd0b4dddc7b" -AttackSurfaceReductionRules_Actions Enabled
Add-MpPreference -AttackSurfaceReductionRules_Ids "c1db55ab-c21a-4637-bb3f-a12568109d" -AttackSurfaceReductionRules_Actions Enabled

Set-MpPreference -AllowDatagramProcessingOnWinServer $true
Set-MpPreference -AllowNetworkProtectionDownLevel $true
Set-MpPreference -AllowNetworkProtectionOnWinServer $true
Set-MpPreference -AllowSwitchToAsyncInspection $true
Set-MpPreference -CheckForSignaturesBeforeRunningScan $true
Set-MpPreference -CloudBlockLevel HighPlus
Set-MpPreference -CloudExtendedTimeout 10
Set-MpPreference -ControlledFolderAccessAllowedApplications 10
Set-MpPreference -DisableArchiveScanning $false
Set-MpPreference -DisableAutoExclusions $true
Set-MpPreference -DisableBehaviorMonitoring $false
Set-MpPreference -DisableBlockAtFirstSeen $false
Set-MpPreference -DisableCacheMaintenance $false
Set-MpPreference -DisableCatchupFullScan $false
Set-MpPreference -DisableCatchupQuickScan $false
Set-MpPreference -DisableCpuThrottleOnIdleScans $false
Set-MpPreference -DisableDatagramProcessing $false
Set-MpPreference -DisableDnsOverTcpParsing $false
Set-MpPreference -DisableDnsParsing $false
Set-MpPreference -DisableEmailScanning $false
Set-MpPreference -DisableFtpParsing $false
Set-MpPreference -DisableGradualRelease $false
Set-MpPreference -DisableHttpParsing $false
Set-MpPreference -DisableInboundConnectionFiltering $false
Set-MpPreference -DisableIOAVProtection $false
Set-MpPreference -DisableNetworkProtectionPerfTelemetry $true
Set-MpPreference -DisablePrivacyMode $false
Set-MpPreference -DisableRdpParsing $false
Set-MpPreference -DisableRealtimeMonitoring $false
Set-MpPreference -DisableRemovableDriveScanning $false
Set-MpPreference -DisableRestorePoint $false
Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $false
Set-MpPreference -DisableScanningNetworkFiles $false
Set-MpPreference -DisableScriptScanning $false
Set-MpPreference -DisableSmtpParsing $false
Set-MpPreference -DisableSshParsing $false
Set-MpPreference -DisableTlsParsing $false
Set-MpPreference -EnableControlledFolderAccess Enabled
Set-MpPreference -EnableDnsSinkhole $true
Set-MpPreference -EnableFileHashComputation $true
Set-MpPreference -EnableFullScanOnBatteryPower $true
Set-MpPreference -EnableLowCpuPriority $false
Set-MpPreference -HighThreatDefaultAction Quarantine
Set-MpPreference -IntelTDTEnabled 1
Set-MpPreference -LowThreatDefaultAction Quarantine
Set-MpPreference -ModerateThreatDefaultAction Quarantine
Set-MpPreference -OobeEnableRtpAndSigUpdate $true
Remove-MpPreference -ProxyBypass
Set-MpPreference -PUAProtection Enabled
Set-MpPreference -QuarantinePurgeItemsAfterDelay 10
Set-MpPreference -RandomizeScheduleTaskTimes $True
Set-MpPreference -RealTimeScanDirection 0
Set-MpPreference -ReportingAdditionalActionTimeOut 60
Set-MpPreference -ReportingCriticalFailureTimeOut 60
Set-MpPreference -ReportingNonCriticalTimeOut 60
Set-MpPreference -ScanAvgCPULoadFactor 10
Set-MpPreference -ScanScheduleDay 0
Set-MpPreference -SevereThreatDefaultAction Quarantine
Set-MpPreference -SignatureDisableUpdateOnStartupWithoutEngine $True
Set-MpPreference -UnknownThreatDefaultAction Quarantine

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Reset SCM SDDL" -ForegroundColor white
sc.exe sdset scmanager "D:(A;;CC;;;AU)(A;;CCLCRPRC;;;IU)(A;;CCLCRPRC;;;SU)(A;;CCLCRPWPRC;;;SY)(A;;KA;;;BA)(A;;CC;;;AC)S:(AU;FA;KA;;;WD)(AU;OIIOFA;GA;;;WD)" | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable SEHOP" -ForegroundColor white
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableExceptionChainValidation /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] More Defender Shit" -ForegroundColor white

cmd /c "setx /M MP_FORCE_USE_SANDBOX 1" | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "HideExclusionsFromLocalAdmins" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "ServiceKeepAlive" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "MpCloudBlockLevel" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableBehaviorMonitoring" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableIOAVProtection" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "CheckForSignaturesBeforeRunningScan" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableHeuristics" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Scan" /v "DisableArchiveScanning" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "DisableBlockAtFirstSeen" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection" /v "ForceDefenderPassiveMode" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\MpEngine" /v "MpEnablePus" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "PUAProtection" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SpyNetReporting" /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" /v "SubmitSamplesConsent" /t REG_DWORD /d 3 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows Defender\Windows Defender Exploit Guard\Network Protection" /v EnableNetworkProtection /t REG_DWORD /d 1 /f | Out-Null

try {
    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure Windows Defender Exploit Guard" -ForegroundColor white
    Set-ProcessMitigation -PolicyFilePath ".\files\Default Defender Exploit Settings\$name.xml" | Out-Null
} catch {
    Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "ERROR" -ForegroundColor red -NoNewLine; Write-Host "] Detected old Defender version, skipped configuring Exploit Guard" -ForegroundColor white
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Remove Defender exclusions" -ForegroundColor white

# Not all types of exclusions are here since we override AttackSurfaceReductionOnlyExclusions and ExclusionPath values in the main file

foreach($ex_extension in (Get-MpPreference).ExclusionExtension) {
    Remove-MpPreference -ExclusionExtension $ex_extension | Out-Null
}

foreach($ex_proc in (Get-MpPreference).ExclusionProcess) {
    Remove-MpPreference -ExclusionProcess $ex_proc | Out-Null
}

foreach($ex_ip in (Get-MpPreference).ExclusionIpAddress) {
    Remove-MpPreference -ExclusionIpAddress $ex_ip | Out-Null
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Apply Account + Audit Policy" -ForegroundColor white

net accounts /UNIQUEPW:24 /MAXPWAGE:90 /MINPWAGE:30 /MINPWLEN:14 /lockoutthreshold:10 /lockoutduration:30 /lockoutwindow:30
auditpol /set /category:"Account Logon" /success:enable | Out-Null
auditpol /set /category:"Account Logon" /failure:enable | Out-Null
auditpol /set /category:"Account Management" /success:enable | Out-Null
auditpol /set /category:"Account Management" /failure:enable | Out-Null
auditpol /set /category:"DS Access" /success:enable | Out-Null
auditpol /set /category:"DS Access" /failure:enable | Out-Null
auditpol /set /category:"Logon/Logoff" /success:enable | Out-Null
auditpol /set /category:"Logon/Logoff" /failure:enable | Out-Null
auditpol /set /category:"Object Access" /failure:enable | Out-Null
auditpol /set /category:"Policy Change" /success:enable | Out-Null
auditpol /set /category:"Policy Change" /failure:enable | Out-Null
auditpol /set /category:"Privilege Use" /success:enable | Out-Null
auditpol /set /category:"Privilege Use" /failure:enable | Out-Null
auditpol /set /category:"Detailed Tracking" /success:enable | Out-Null
auditpol /set /category:"Detailed Tracking" /failure:enable | Out-Null
auditpol /set /category:"System" /success:enable | Out-Null
auditpol /set /category:"System" /failure:enable | Out-Null
auditpol /set /category:* /success:enable | Out-Null
auditpol /set /category:* /failure:enable | Out-Null
auditpol /set /subcategory:"Security State Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Security System Extension" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"System Integrity" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"IPsec Driver" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other System Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Logon" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Logoff" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Account Lockout" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"IPsec Main Mode" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"IPsec Quick Mode" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"IPsec Extended Mode" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Special Logon" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Logon/Logoff Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Network Policy Server" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"User / Device Claims" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Group Membership" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"File System" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Registry" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Kernel Object" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"SAM" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Certification Services" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Application Generated" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Handle Manipulation" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"File Share" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Filtering Platform Packet Drop" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Filtering Platform Connection" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Object Access Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Detailed File Share" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Removable Storage" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Central Policy Staging" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Non Sensitive Privilege Use" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Privilege Use Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Process Termination" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"DPAPI Activity" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"RPC Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Plug and Play Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Token Right Adjusted Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Authentication Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Authorization Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"MPSSVC Rule-Level Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Filtering Platform Policy Change" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Policy Change Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Computer Account Management" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Security Group Management" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Distribution Group Management" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Application Group Management" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Account Management Events" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Directory Service Access" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Directory Service Changes" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Directory Service Replication" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Detailed Directory Service Replication" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Kerberos Service Ticket Operations" /success:enable /failure:enable | Out-Null
auditpol /set /subcategory:"Other Account Logon Events" /success:enable /failure:enable  | Out-Null
auditpol /set /subcategory:"Kerberos Authentication Service" /success:enable /failure:enable | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditAccountLogon" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditAccountManage" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditDSAccess" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditLogonEvents" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditObjectAccess" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditPolicyChange" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditPrivilegeUse" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditProcessTracking" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditSystemEvents" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditKernelObject" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditSAM" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditSecuritySystemExtension" -Value 2 | Out-Null
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\EventLog\Security' -Name "AuditRegistry" -Value 2 | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable auditing of file system object changes on all drives" -ForegroundColor white

$volumes = Get-Volume | Where-Object {$_.DriveType -eq 'Fixed'}

foreach($volume in $volumes) {
    if(!$volume.DriveLetter) { continue }
    $drive = Get-PSDrive "$($volume.DriveLetter)"
    $acl = Get-Acl -Path $drive.Root
    $auditRule = New-Object System.Security.AccessControl.FileSystemAuditRule("Everyone", "CreateFiles", "Success")
    $acl.AddAuditRule($auditRule)
    Set-Acl -Path $drive.Root -AclObject $acl
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SMB" -ForegroundColor white

Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v "MinimumPIN" /t REG_DWORD /d "0x00000006" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "DisableExceptionChainValidation" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "SMB1" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\System" /v "MaxSize" /t REG_DWORD /d "0x00008000" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" /v "DisableIpSourceRouting" /t REG_DWORD /d "2" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "DisableIPSourceRouting" /t REG_DWORD /d "2" /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxDataRetransmissions /t REG_DWORD /d 3 /f
reg add "HKLM\System\CurrentControlSet\Services\Tcpip6\Parameters" /v TcpMaxDataRetransmissions /t REG_DWORD /d 3 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "LocalAccountTokenFilterPolicy" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\Wdigest" /v "UseLogonCredential" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\batfile\shell\runasuser\" /v "SuppressionPolicy" /t REG_DWORD /d "0x00001000" /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\cmdfile\shell\runasusers" /v "SuppressionPolicy" /t REG_DWORD /d "0x00001000" /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\exefile\shell\runasuser" /v "SuppressionPolicy" /t REG_DWORD /d "0x00001000" /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\exefile\shell\runasusers" /v "SuppressionPolicy" /t REG_DWORD /d "0x00001000" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LanmanWorkstation" /v "AllowInsecureGuestAuth" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Network Connections" /v "NC_ShowSharedAccessUI" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v "fMinimizeConnections" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy" /v "fBlockNonDomain" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v "AutoConnectAllowedOEM" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v "ProcessCreationIncludeCmdLine_Enabled" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" /v "AllowProtectedCreds" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Policies\EarlyLaunch" /v "DriverLoadPolicy" /t REG_DWORD /d "8" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Group Policy\{35378EAC-683F-11D2-A89A-00C04FBBCFA2}" /v "NoGPOListChanges" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v "DisableWebPnPDownload" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoWebServices" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v "DisableHTTPPrinting" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DontDisplayNetworkSelectionUI" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Policies\Microsoft\Windows\Systemh" /v "EnumerateLocalUsers" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v "DCSettingIndex" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SYSTEM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v "ACSettingIndex" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d "3" /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v "HypervisorEnforcedCodeIntegrity" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v HVCIMATRequired /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v "LsaCfgFlags" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" /v "ConfigureSystemGuardLaunch" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v DisableStackProtection /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /t REG_DWORD /d 0 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Locked" /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Mandatory" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" /v "DevicePKInitEnabled" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DontDisplayNetworkSelectionUI" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v "fAllowToGetHelp" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" /v "RestrictRemoteClients" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "MSAOptional" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v "DisableInventory" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "NoAutoplayfornonVolume" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoAutorun" /t REG_DWORD /d "1" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\CredUI" /v "EnumerateAdministrators" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "LimitEnhancedDiagnosticDataWindowsAnalytics" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d "0x000000ff" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v "DODownloadMode" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v "DODisallowCacheServerDownloadsOnVPN" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "EnableSmartScreen" /t REG_DWORD /d "0x00000002" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "ShellSmartScreenLevel" /t REG_SZ /d "v1607 LTSB:" /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "NoDataExecutionPrevention" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "DisableHHDEP" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "NoHeapTerminationOnCorruption" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "PreXPSP2ShellProtocolBehavior" /t REG_DWORD /d "0" /f | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" DisableCompression -Type DWORD -Value 1 -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "DisableBandwidthThrottling" -Type "DWORD" -Value 1 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "FileInfoCacheEntriesMax" -Type "DWORD" -Value 1024 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "DirectoryCacheEntriesMax" -Type "DWORD" -Value 1024 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "FileNotFoundCacheEntriesMax" -Type "DWORD" -Value 2048 -Force
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "IRPStackSize" -Type "DWORD" -Value 20 -Force
Set-SmbServerConfiguration -EncryptData $true -Force | Out-Null
Set-SmbServerConfiguration -MaxChannelPerSession 16 -Force

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Harden Edge" -ForegroundColor white
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "SitePerProcess" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "SSLVersionMin" /t REG_SZ /d "tls1.2" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "NativeMessagingUserLevelHosts" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "SmartScreenEnabled" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "PreventSmartScreenPromptOverride" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "PreventSmartScreenPromptOverrideForFiles" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "SSLErrorOverrideAllowed" /t REG_DWORD /d "0" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "SmartScreenPuaEnabled" /t REG_DWORD /d "0x00000001" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge" /v "AllowDeletingBrowserHistory" /t REG_DWORD /d "0x00000000" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge\ExtensionInstallAllowlist\1" /t REG_SZ /d "odfafepnkmbhccpbejgmiehpchacaeak" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist\1" /t REG_SZ /d "odfafepnkmbhccpbejgmiehpchacaeak" /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Edge\Extensions\odfafepnkmbhccpbejgmiehpchacaeak" /v "update_url" /t REG_SZ /d "https://edge.microsoft.com/extensionwebstorebase/v1/crx" /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\MicrosoftEdge\Addons" /v "FlashPlayerEnabled" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Addons" /v "FlashPlayerEnabled" /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "PreventOverrideAppRepUnknown" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "PreventOverride" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "EnabledV9" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "PreventOverrideAppRepUnknown" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "PreventOverride" /t REG_DWORD /d 1 /f
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\MicrosoftEdge\PhishingFilter" /v "EnabledV9" /t REG_DWORD /d 1 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Harden Chrome" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "AllowCrossOriginAuthPrompt" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SafeBrowsingAllowlistDomains" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "MediaRouterCastAllowAllIPs" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "BrowserNetworkTimeQueriesEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "ChromeVariations" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DNSInterceptionChecksEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "ComponentUpdatesEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "GloballyScopeHTTPAuthCacheEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "CommandLineFlagSecurityWarningsEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "ThirdPartyBlockingEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DefaultInsecureContentSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DefaultWebBluetoothGuardSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DefaultNotificationsSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "HttpsUpgradesEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "InsecureHashesInTLSHandshakesEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "RendererAppContainerEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "StrictMimetypeCheckForWorkerScriptsEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "RemoteDebuggingAllowed" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "PaymentMethodQueryEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "BlockThirdPartyCookies" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "BrowserSignin" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SyncDisabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "HttpsOnlyMode" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "AlwaysOpenPdfExternally" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "AmbientAuthenticationInPrivateModesEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "AudioCaptureAllowed" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "AudioSandboxEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DnsOverHttpsMode" /t REG_SZ /d secure /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "ScreenCaptureAllowed" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SitePerProcess" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "TLS13HardeningForLocalAnchorsEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "VideoCaptureAllowed" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "AdvancedProtectionAllowed" /t REG_DWORD /d "1" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "RemoteAccessHostFirewallTraversal" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultPopupsSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultGeolocationSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultSearchProviderName" /t REG_SZ /d "Google Encrypted" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultSearchProviderSearchURL" /t REG_SZ /d "https://www.google.com/#q={searchTerms}" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultSearchProviderEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "AllowOutdatedPlugins" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "BackgroundModeEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "CloudPrintProxyEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "MetricsReportingEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "SearchSuggestEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "ImportSavedPasswords" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "IncognitoModeAvailability" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "EnableOnlineRevocationChecks" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "SavingBrowserHistoryDisabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultPluginsSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "AllowDeletingBrowserHistory" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "PromptForDownloadLocation" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DownloadRestrictions" /t REG_DWORD /d 4 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "AutoplayAllowed" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "SafeBrowsingExtendedReportingEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "DefaultWebUsbGuardSetting" /t REG_DWORD /d 2 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "AdsSettingForIntrusiveAdsSites" /t REG_DWORD /d 2 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "ChromeCleanupEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "ChromeCleanupReportingEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "EnableMediaRouter" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "SSLVersionMin" /t REG_SZ /d "tls1.2" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "UrlKeyedAnonymizedDataCollectionEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "WebRtcEventLogCollectionAllowed" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "NetworkPredictionOptions" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "BrowserGuestModeEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome" /v "ImportAutofillFormData" /t REG_DWORD /d "0" /f
reg add "HKLM\Software\Policies\Google\Chrome\ExtensionInstallWhitelist" /v "1" /t REG_SZ /d "cjpalhdlnbpafiamejdnhcphjbkeiagm" /f
reg add "HKLM\Software\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "cjpalhdlnbpafiamejdnhcphjbkeiagm" /f
reg add "HKLM\Software\Policies\Google\Chrome\URLBlacklist" /v "1" /t REG_SZ /d "javascript://*" /f
reg add "HKLM\Software\Policies\Google\Update" /v "AutoUpdateCheckPeriodMinutes" /t REG_DWORD /d "1613168640" /f
reg add "HKLM\Software\Policies\Google\Chrome\Recommended" /v "SafeBrowsingProtectionLevel" /t REG_DWORD /d "2" /f
reg add "HKLM\Software\Policies\Google\Chrome\Recommended" /v "SyncDisabled" /t REG_DWORD /d "1" /f

reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v "DisableCompression" /t REG_DWORD /d "1" /f
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Set-SmbServerConfiguration -EncryptData $true -Force

if(Test-Path C:\Windows\System32\flshpnt.dll) {
    del C:\Windows\System32\flshpnt.dll
}

if(Test-Path C:\Windows\System32\drivers\WinDivert64.sys) {
    del C:\Windows\System32\drivers\WinDivert64.sys
}

Write-Output 'Set HKEY_CLASSES_ROOT\Microsoft.PowerShellScript.1\Shell\Open\Command to "C:\Windows\System32\notepad.exe" "%1"'
pause

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate HiveNightmare" -ForegroundColor white

icacls.exe $env:windir\system32\config\*.* /inheritance:e | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate PrintNightmare" -ForegroundColor white

reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers" /v CopyFilesPolicy /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows NT\Printers" /v RegisterSpoolerRemoteRpcEndPoint /t REG_DWORD /d 2 /f | Out-Null
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Control\Print" /v RpcAuthnLevelPrivacyEnabled /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint" /v RestrictDriverInstallationToAdministrators /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v DisableWebPnPDownload /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers" /v DisableHTTPPrinting /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers" /v AddPrinterDrivers /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configuring Credential Manager" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" /v AllowProtectedCreds /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\CredentialsDelegation" /v RestrictedRemoteAdministration /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\CredentialsDelegation" /v RestrictedRemoteAdministrationType /t REG_DWORD /d 3 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure UAC" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v FilterAdministratorToken /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableUIADesktopToggle /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorUser /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableInstallerDetection /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ValidateAdminCodeSignatures /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableSecureUIAPaths /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableVirtualization /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable WDigest" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v Negotiate /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Autologon" -ForegroundColor white

reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Set Screen saver grace period to 0 seconds" -ForegroundColor white

reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v ScreenSaverGracePeriod /t REG_DWORD /d 0 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable and clear logon cache" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v CachedLogonsCount /t REG_SZ /d 0 /f | Out-Null

$lines = (cmdkey.exe /list)

foreach($line in $lines) {
    if($line.ToLower().Contains("target:") -and $line.ToLower().Contains("microsoft")) {
        $line = $line.trim()
        $nameOfTarget = $line.Substring(8).trim()
        cmdkey.exe /del:"$nameOfTarget"
    }
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure NTLM" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LMCompatibilityLevel /t REG_DWORD /d 5 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v UseMachineId /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\LSA\MSV1_0" /v allownullsessionfallback /t REG_DWORD /d 0 /f | Out-Null
## Setting NTLM SSP server and client to require NTLMv2 and 128-bit encryption
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v NTLMMinServerSec /t REG_DWORD /d 537395200 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0" /v NTLMMinClientSec /t REG_DWORD /d 537395200 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable the loading of test-signed kernel drivers" -ForegroundColor white

bcdedit.exe /set TESTSIGNING OFF | Out-Null
bcdedit.exe /set loadoptions ENABLE_INTEGRITY_CHECKS | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enforce driver signatures" -ForegroundColor white

bcdedit.exe /set nointegritychecks off | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable DEP for all processes" -ForegroundColor white

bcdedit.exe /set "{current}" nx AlwaysOn | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable crash dump generation" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v "CrashDumpEnabled" /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable automatic reboot after system crash" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\CrashControl" /v AutoReboot /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Windows Installer always being elevated" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer" /v AlwaysInstallElevated /t REG_DWORD /d 0 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Policies\Microsoft\Windows\Installer" /v AlwaysInstallElevated /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Require password on wakeup" -ForegroundColor white

powercfg -SETACVALUEINDEX SCHEME_BALANCED SUB_NONE CONSOLELOCK 1 | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Set file associations to need to be opened manually" -ForegroundColor white

cmd /c 'ftype htafile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype wshfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype wsffile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype batfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype jsfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype jsefile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype vbefile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'
cmd /c 'ftype vbsfile="%SystemRoot%\system32\NOTEPAD.EXE" "%1"'

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable 8.3 filename creation" -ForegroundColor white

reg add "HKLM\System\CurrentControlSet\Control\FileSystem" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Remove 'Run As Different User' from context menus" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoStartBanner /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\batfile\shell\runasuser"	/v SuppressionPolicy /t REG_DWORD /d 4096 /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\cmdfile\shell\runasuser"	/v SuppressionPolicy /t REG_DWORD /d 4096 /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\exefile\shell\runasuser"	/v SuppressionPolicy /t REG_DWORD /d 4096 /f | Out-Null
reg add "HKLM\SOFTWARE\Classes\mscfile\shell\runasuser" /v SuppressionPolicy /t REG_DWORD /d 4096 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable hidden file and file extension visibility" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoFolderOptions" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\NOHIDDEN" /v "CheckedValue" /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\NOHIDDEN" /v "DefaultValue" /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\SHOWALL" /v "CheckedValue" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\SHOWALL" /v "DefaultValue" /t REG_DWORD /d 2 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSuperHidden" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Autorun" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v NoAutoplayfornonVolume /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoAutorun /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /v DisableAutoplay /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable DEP and heap termination for explorer" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v NoDataExecutionPrevention /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v NoHeapTerminationOnCorruption /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable shell protocol protected mode for explorer" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v PreXPSP2ShellProtocolBehavior /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Strengthen default object permissions" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v ProtectionMode /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable safe DLL search mode and blocked loading from remote folders" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v SafeDllSearchMode /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v CWDIllegalInDllSearch /t REG_DWORD /d 2 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable APPInit DLL loading" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v LoadAppInit_DLLs /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows" /v LoadAppInit_DLLs /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable remote access to registry paths" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurePipeServers\winreg\AllowedExactPaths" /v Machine /t REG_MULTI_SZ /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurePipeServers\winreg\AllowedPaths" /v Machine /t REG_MULTI_SZ /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable processing of RunOnce keys" -ForegroundColor white

reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisableLocalMachineRunOnce /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisableLocalMachineRunOnce /t REG_DWORD /d 1 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisableLocalMachineRunOnce /t REG_DWORD /d 1 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v DisableLocalMachineRunOnce /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure Ease of Access registry keys" -ForegroundColor white

reg add "HKU\$CURRENT_USER_SID\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f | Out-Null
reg add "HKU\$CURRENT_USER_SID\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" /v ShowTabletKeyboard /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SOFTWARE\Microsoft\Windows Embedded\EmbeddedLogon" /v BrandingNeutral /t REG_DWORD /d 8 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Remove vulnerable accessibility features" -ForegroundColor white

$files = @("sethc.exe", "Utilman.exe", "osk.exe", "Narrator.exe", "Magnify.exe")

foreach($file in $files) {
    if(!(Test-Path -Path "C:\Windows\System32\$file")) { continue }
    takeown.exe /f "C:\Windows\System32\$file" /A | Out-Null
    icacls.exe "C:\Windows\System32\$file" /grant administrators:F | Out-Null
    Remove-Item "C:\Windows\System32\$file" -Force | Out-Null
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate PsExec" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\PSEXESVC.exe" /v Debugger /t REG_SZ /d "svchost.exe" /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable offline files" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\CSC" /v Start /t REG_DWORD /d 4 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable UPnP" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\DirectPlayNATHelp\DPNHUPnP" /v UPnPMode /t REG_DWORD /d 2 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable DCOM" -ForegroundColor white

reg add "HKLM\Software\Microsoft\OLE" /v EnableDCOM /t REG_SZ /d N /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable digital signing and encryption of secure channel data" -ForegroundColor white

reg add "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" /v RequireSignOrSeal /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" /v SealSecureChannel /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" /v SignSecureChannel /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SChannel encryption ciphers" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\AES 128/128" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\AES 256/256" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\NULL" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 128/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 40/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC2 56/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 64/128" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\Triple DES 168" /v Enabled /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SChannel hashing algorithms" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\MD5" /v Enabled /t REG_DWORD /d 0x0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\SHA" /v Enabled /t REG_DWORD /d 0x0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\SHA256" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\SHA384" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\SHA512" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SChannel key exchange algorithms" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\Diffie-Hellman" /v ServerMinKeyBitLength /t REG_DWORD /d 0x00001000 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\ECDH" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\PKCS" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SChannel encryption protocols to TLS 1.2" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Client" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Client" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Server" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\Multi-Protocol Unified Hello\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Client" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Client" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Server" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\PCT 1.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Client" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" /v Enabled /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server" /v DisabledByDefault /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client" /v DisabledByDefault /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" /v Enabled /t REG_DWORD /d 0xffffffff /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server" /v DisabledByDefault /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SChannel cipher suites" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002" /v Functions /t REG_SZ /d "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256,TLS_DHE_RSA_WITH_AES_256_GCM_SHA384,TLS_DHE_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_3DES_EDE_CBC_SHA,TLS_RSA_WITH_NULL_SHA256,TLS_RSA_WITH_NULL_SHA,TLS_PSK_WITH_AES_256_GCM_SHA384,TLS_PSK_WITH_AES_128_GCM_SHA256,TLS_PSK_WITH_AES_256_CBC_SHA384,TLS_PSK_WITH_AES_128_CBC_SHA256,TLS_PSK_WITH_NULL_SHA384,TLS_PSK_WITH_NULL_SHA256" /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate SMBGhost" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v DisableCompression /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable SMB1 on server" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable SMBv1 on client" -ForegroundColor white

net.exe stop MrxSmb10
sc.exe config MrxSmb10 start=disabled

reg add "HKLM\SYSTEM\CurrentControlSet\Services\MrxSmb10" /v Start /t REG_DWORD /d 4 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation" /v DependOnService /t REG_MULTI_SZ /d "Bowser\0MRxSMB20\0NSI" /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable SMBv2/3 and data encryption" -ForegroundColor white

Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force | Out-Null
Set-SmbServerConfiguration -EncryptData $true -Force | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Services\LanmanServer\Parameters" /v SMB2 /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable sending unencrypted password to third-party SMB servers" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v EnablePlainTextPassword /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable guest logins for SMB" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v AllowInsecureGuestAuth /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable SMB signing" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v EnableSecuritySignature /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v EnableSecuritySignature /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable access to null session pipes and shares" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters" /v RestrictNullSessAccess /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionPipes /t REG_MULTI_SZ /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v NullSessionShares /t REG_MULTI_SZ /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Hide computer from share browse list" -ForegroundColor white

reg add "HKLM\System\CurrentControlSet\Services\Lanmanserver\Parameters" /v "Hidden" /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Audit SMB1 access" -ForegroundColor white

Set-SmbServerConfiguration -AuditSmb1Access $true -Force | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure RPC settings" -ForegroundColor white

reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Schedule" /v DisableRpcOverTcp /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v DisableRemoteScmEndpoints /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" /v RestrictRemoteClients /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Limit BITS transfer speeds" -ForegroundColor white

reg add "HKLM\Software\Policies\Microsoft\Windows\BITS" /v EnableBITSMaxBandwidth /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\BITS" /v MaxTransferRateOffSchedule /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\BITS" /v MaxDownloadTime /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable enforcement of LDAP client signing" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\LDAP" /v LDAPClientIntegrity /t REG_DWORD /d 2 /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" /v "LDAPServerIntegrity" /t REG_DWORD /d 2 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" /v "LdapEnforceChannelBinding" /t REG_DWORD /d 2 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics" /v "16 LDAP Interface Events" /t REG_DWORD /d 2 /f
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\LSA" /v "SuppressExtendedProtection" /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable stronger encryption types for Kerberos" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters" /v "SupportedEncryptionTypes" /t REG_DWORD /d 2147483640 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable WPAD" -ForegroundColor white

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DisableWpad /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable LLMNR" -ForegroundColor white

reg add "HKLM\Software\policies\Microsoft\Windows NT\DNSClient" /f | Out-Null
reg add "HKLM\Software\policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable SMHNR" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v DisableSmartNameResolution /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v DisableParallelAandAAAA /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable NBT-NS" -ForegroundColor white

$keys = Get-ChildItem -Path "HKLM:SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces\"

foreach($key in $keys) {
    reg add "$($key.Name)" /t REG_DWORD /v NetbiosOptions /d 2 /f | Out-Null
}

reg add "HKLM\System\CurrentControlSet\Services\NetBT\Parameters" /v NodeType /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Services\NetBT\Parameters" /v NoNameReleaseOnDemand /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable mDNS" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v EnableMDNS /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Flush DNS cache" -ForegroundColor white

ipconfig /flushdns
ipconfig /registerdns

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable IP source routing" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\tcpip\Parameters" /v DisableIPSourceRouting /t REG_DWORD /d 2 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\tcpip6\Parameters" /v DisableIPSourceRouting /t REG_DWORD /d 2 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable automatic detection of dead gateways" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\RasMan\Parameters" /v DisableSavePassword /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\System\CurrentControlSet\Services\Tcpip\Parameters" /v EnableDeadGWDetect /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable OSPF ICMP redirection" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\tcpip\Parameters" /v EnableICMPRedirect /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable IRDP" -ForegroundColor white

reg add "HKLM\System\CurrentControlSet\Services\Tcpip\Parameters" /v PerformRouterDiscovery /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable IGMP" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v IGMPLevel /t REG_DWORD /d 0 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SYN attack protection level" -ForegroundColor white

reg add "HKLM\System\CurrentControlSet\Services\Tcpip\Parameters" /v SynAttackProtect /t REG_DWORD /d 1 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Configure SYN-ACK retransmissions" -ForegroundColor white

reg add "HKLM\System\CurrentControlSet\Services\Tcpip\Parameters" /v TcpMaxConnectResponseRetransmissions /t REG_DWORD /d 2 /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable DCOM" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\OLE" /v EnableDCOM /t REG_SZ /d N /F

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable DEP, EmulateAtlThunks, BottomUp, HighEntropy, SEHOP, SEHOPTelemetry, TerminateOnError, and CFG" -ForegroundColor white

Set-ProcessMitigation -System -Enable DEP,EmulateAtlThunks,BottomUp,HighEntropy,SEHOP,SEHOPTelemetry,TerminateOnError,CFG

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable VBS Scripts" -ForegroundColor white

reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows Script Host\Settings" /v Enabled /t REG_DWORD /d 0 /f
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows Script Host\Settings" /v ActiveDebugging /t REG_SZ /d 1 /f
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows Script Host\Settings" /v DisplayLogo /t REG_SZ /d 1 /f
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows Script Host\Settings" /v SilentTerminate /t REG_SZ /d 0 /f
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows Script Host\Settings" /v UseWINSAFER /t REG_SZ /d 1 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] More shit gets configured here that I hope just works" -ForegroundColor white

reg add "HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v ACSettingIndex /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51" /v DCSettingIndex /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fAllowToGetHelp /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fEncryptRPCTraffic /t REG_DWORD /d 1 /f
reg add "HKLM\System\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 0 /f
reg add "HKLM\System\CurrentControlSet\Control\Remote Assistance" /v fAllowFullControl /t REG_DWORD /d 0 /f

wmic /interactive:off nicconfig where TcpipNetbiosOptions=0 call SetTcpipNetbios 2
wmic /interactive:off nicconfig where TcpipNetbiosOptions=1 call SetTcpipNetbios 2

Disable-PSRemoting -Force
Disable-WindowsOptionalFeature -Online -FeatureName TelnetClient -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName TelnetServer -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol-Client" -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol-Server" -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName TFTP -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root -NoRestart

reg add "HKLM\SYSTEM\CurrentControlSet\Services\mrxsmb10" /v Start /t REG_DWORD /d 4 /f
reg add "HKLM\SOFTWARE\MICROSOFT\.NETFramework\Security\TrustManager\PromptingLevel" /v MyComputer /t REG_SZ /d "Disabled" /f
reg add "HKLM\SOFTWARE\MICROSOFT\.NETFramework\Security\TrustManager\PromptingLevel" /v LocalIntranet /t REG_SZ /d "Disabled" /f
reg add "HKLM\SOFTWARE\MICROSOFT\.NETFramework\Security\TrustManager\PromptingLevel" /v Internet /t REG_SZ /d "Disabled" /f
reg add "HKLM\SOFTWARE\MICROSOFT\.NETFramework\Security\TrustManager\PromptingLevel" /v TrustedSites /t REG_SZ /d "Disabled" /f
reg add "HKLM\SOFTWARE\MICROSOFT\.NETFramework\Security\TrustManager\PromptingLevel" /v UntrustedSites /t REG_SZ /d "Disabled" /f

netsh int tcp set global timestamps=disabled
fsutil behavior set disable8dot3 1
fsutil behavior set disablelastaccess 0

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PushToInstall" /v "DisablePushToInstall" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\safer\codeidentifiers" /v "authenticodeenabled" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v "BlockDomainPicturePassword" /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecureBoot\State" /v UEFISecureBootEnabled /t REG_DWORD /d 1 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable drive quotas" -ForegroundColor white

$volumes = Get-Volume | Where-Object {$_.DriveType -eq 'Fixed'}

foreach($volume in $volumes) {
    if(!$volume.DriveLetter) { continue }
    fsutil.exe quota disable "$($volume.DriveLetter):"
    Write-Output "Quotas disabled on drive: $($volume.DriveLetter)"
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable SSL key logs in SCHANNEL" -ForegroundColor white

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Name 'KeyLogging' -Value '0'

bcdedit /set disableelamdrivers no
bcdedit /set testsigning off
bcdedit /bootdebug off
bcdedit /debug off
bcdedit /ems off
bcdedit /event on
bcdedit /set nx AlwaysOn

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths" /v "\\*\SYSVOL" /t REG_SZ /d "RequireMutualAuthentication=1, RequireIntegrity=1, RequirePrivacy=1" /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths" /v "\\*\NETLOGON" /t REG_SZ /d "RequireMutualAuthentication=1, RequireIntegrity=1, RequirePrivacy=1" /f
reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments" /v SaveZoneInformation /t REG_DWORD /d 2 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] More defender shit" -ForegroundColor white

$win10Server19Flags = @{
    "AllowSwitchToAsyncInspection" = $True
    "CheckForSignaturesBeforeRunningScan" = $True
    "CloudBlockLevel" = "ZeroTolerance"
    "DefinitionUpdatesChannel" = "NotConfigured"
    "DisableArchiveScanning" = $False
    "DisableAutoExclusions" = $True
    "DisableBehaviorMonitoring" = $False
    "DisableBlockAtFirstSeen" = $False
    "DisableCacheMaintenance" = 0
    "DisableCatchupFullScan" = $False
    "DisableCatchupQuickScan" = $False
    "DisableEmailScanning" = $False
    "DisableGradualRelease" = $False
    "DisableIOAVProtection" = $False
    "DisablePrivacyMode" = $False
    "DisableRealtimeMonitoring" = $False
    "DisableRemovableDriveScanning" = $False
    "DisableRestorePoint" = $False
    "DisableScanningMappedNetworkDrivesForFullScan" = $False
    "DisableScanningNetworkFiles" = $False
    "DisableScriptScanning" = $False
    "EngineUpdatesChannel" = "NotConfigured"
    "HighThreatDefaultAction" = "Remove"
    "LowThreatDefaultAction" = "Remove"
    "MAPSReporting" = "Advanced"
    "ModerateThreatDefaultAction" = "Remove"
    "OobeEnableRtpAndSigUpdate" = $True
    "PlatformUpdatesChannel" = "NotConfigured"
    "PUAProtection" = "Enabled"
    "RandomizeScheduleTaskTimes" = $False
    "RealTimeScanDirection" = "Both"
    "RemediationScheduleDay" = "Everyday"
    "ScanOnlyIfIdleEnabled" = $False
    "ScanParameters" = "QuickScan"
    "SevereThreatDefaultAction" = "Remove"
    "SignatureDisableUpdateOnStartupWithoutEngine" = $False
    "SubmitSamplesConsent" = "SendAllSamples"
    "UILockdown" = $False
    "UnknownThreatDefaultAction" = "Remove"
}

$win11Server22Flags = @{
    "AllowDatagramProcessingOnWinServer" = $True
    "AllowNetworkProtectionDownLevel" = $True
    "AllowNetworkProtectionOnWinServer" = $True
    "AllowSwitchToAsyncInspection" = $True
    "CheckForSignaturesBeforeRunningScan" = $True
    "CloudBlockLevel" = "ZeroTolerance"
    "DisableArchiveScanning" = $False
    "DisableAutoExclusions" = $True
    "DisableBehaviorMonitoring" = $False
    "DisableBlockAtFirstSeen" = $False
    "DisableCacheMaintenance" = 0
    "DisableCatchupFullScan" = $False
    "DisableCatchupQuickScan" = $False
    "DisableDatagramProcessing" = $False
    "DisableDnsOverTcpParsing" = $False
    "DisableDnsParsing" = $False
    "DisableEmailScanning" = $False
    "DisableFtpParsing" = $False
    "DisableGradualRelease" = $False
    "DisableHttpParsing" = $False
    "DisableInboundConnectionFiltering" = $False
    "DisableIOAVProtection" = $False
    "DisableNetworkProtectionPerfTelemetry" = $True
    "DisablePrivacyMode" = $False
    "DisableRdpParsing" = $False
    "DisableRealtimeMonitoring" = $False
    "DisableRemovableDriveScanning" = $False
    "DisableRestorePoint" = $False
    "DisableScanningMappedNetworkDrivesForFullScan" = $False
    "DisableScanningNetworkFiles" = $False
    "DisableScriptScanning" = $False
    "DisableSmtpParsing" = $False
    "DisableSshParsing" = $False
    "DisableTlsParsing" = $False
    "EnableUdpReceiveOffload" = 1
    "EnableUdpSegmentationOffload" = 1
    "EnableControlledFolderAccess" = "Enabled"
    "EnableConvertWarnToBlock" = 1
    "EnableDnsSinkhole" = $True
    "EnableFileHashComputation" = $True
    "EnableFullScanOnBatteryPower" = $True
    "EnableLowCpuPriority" = $True
    "EnableNetworkProtection" = "Enabled"
    "EngineUpdatesChannel" = "NotConfigured"
    "ForceUseProxyOnly" = $False
    "HighThreatDefaultAction" = "Remove"
    "IntelTDTEnabled" = 1
    "LowThreatDefaultAction" = "Remove"
    "MAPSReporting" = "Advanced"
    "MeteredConnectionUpdates" = $True
    "ModerateThreatDefaultAction" = "Remove"
    "OobeEnableRtpAndSigUpdate" = $True
    "PlatformUpdatesChannel" = "NotConfigured"
    "PUAProtection" = "Enabled"
    "RandomizeScheduleTaskTimes" = $False
    "RealTimeScanDirection" = "Both"
    "ScanOnlyIfIdleEnabled" = $False
    "ScanParameters" = "QuickScan"
    "ServiceHealthReportInterval" = 60
    "SevereThreatDefaultAction" = "Remove"
    "SignatureDisableUpdateOnStartupWithoutEngine" = $False
    "SignaturesUpdatesChannel" = "NotConfigured"
    "SubmitSamplesConsent" = "SendAllSamples"
    "UILockdown" = $False
    "UnknownThreatDefaultAction" = "Remove"
}

$flags = $win10Server19Flags

if($version -eq "11" -or $version -eq "22") {
    $flags = $win11Server22Flags
}

foreach($flag in $flags.Keys) {
    $value = $flags[$flag]
    if($value -eq $False) { $value = 0 }
    if($value -eq $True) { $value = 1 }
    Invoke-Command -ScriptBlock ([Scriptblock]::Create("Set-MpPreference -$flag $value"))
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] More SMB shit" -ForegroundColor white

$serverFlags = @{
    "AnnounceComment" = ""
    "AnnounceServer" = $False
    "AuditSmb1Access" = $True
    "AutoShareServer" = $False
    "AutoShareWorkstation" = $False
    "DisableCompression" = $True
    "DisableSmbEncryptionOnSecureConnection" = $False
    "EnableAuthenticateUserSharing" = $True
    "EnableDownlevelTimewarp" = $False
    "EnableForcedLogoff" = $True
    "EnableLeasing" = $False
    "EnableMultiChannel" = $True
    "EnableOplocks" = $False
    "EnableSecuritySignature" = $True
    "EnableSMB1Protocol" = $False
    "EnableSMB2Protocol" = $True
    "EnableSMBQUIC" = $True
    "EnableStrictNameChecking" = $True
    "EncryptData" = $True
    "EncryptionCiphers" = "AES_256_GCM"
    "RejectUnencryptedAccess" = $True
    "RequireSecuritySignature" = $True
    "RestrictNamedpipeAccessViaQuic" = $True
    "ServerHidden" = $True
}

$clientFlags = @{
    "DisableCompression" = $True
    "EnableInsecureGuestLogons" = $False
    "EnableLargeMtu" = $True
    "EnableMultiChannel" = $True
    "EnableSecuritySignature" = $True
    "EncryptionCiphers" = "AES_256_GCM"
    "ForceSMBEncryptionOverQuic" = $True
    "RequireSecuritySignature" = $True
    "SkipCertificateCheck" = $False
}

Set-SmbServerConfiguration -AnnounceComment "" -Confirm:0

foreach($flag in $serverFlags.Keys) {
    $value = $serverFlags[$flag]
    if($value -eq $False) { $value = 0 }
    if($value -eq $True) { $value = 1 }
    Invoke-Command -ScriptBlock ([Scriptblock]::Create("Set-SmbServerConfiguration -$flag $value -Confirm:0"))
}

foreach($flag in $clientFlags.Keys) {
    $value = $clientFlags[$flag]
    if($value -eq $False) { $value = 0 }
    if($value -eq $True) { $value = 1 }
    Invoke-Command -ScriptBlock ([Scriptblock]::Create("Set-SmbClientConfiguration -$flag $value -Confirm:0"))
}

$shares = Get-SmbShare

foreach($share in $shares) {
    Set-SmbShare "$($share.Name)" -EncryptData $true -Confirm:0
    Set-SmbShare "$($share.Name)" -FolderEnumerationMode AccessBased -Confirm:0
    Set-SmbShare "$($share.Name)" -LeasingMode Full -Confirm:0
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Harden FTP" -ForegroundColor white

reg add 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\FTP\Server' /v "AllowAnonymousTLS" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\FTP\Server' /v "MaxFailedAttempts" /t REG_DWORD /d 3 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable SSLv2, SSLv3, TLS 1.0, and TLS 1.1" -ForegroundColor white

reg add  'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' /v "Enabled" /t REG_DWORD /d 0 /f
reg add  'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server' /v "Enabled" /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable TLS 1.2" -ForegroundColor white

reg add  'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' /v "Enabled" /t REG_DWORD /d 1 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable NULL, DES, RC4, and AES 128 cipher suites" -ForegroundColor white

reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\NULL' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\DES 56/56' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 128/128' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 40/128' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\RC4 56/128' /v "Enabled" /t REG_DWORD /d 0 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\AES 128/128' /v "Enabled" /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable AES 256 cipher suite" -ForegroundColor white

reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\AES 256/256' /v "Enabled" /t REG_DWORD /d 1 /f
reg add 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' /v 'EnabledCipherSuites' /t REG_SZ /d "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_256_CBC_SHA256" /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enforce FIPS-compliant algorithms" -ForegroundColor white

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy" -Name "Enabled" -Value "1"

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Harden WinRM" -ForegroundColor white

Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false
Set-Item -Path WSMan:\localhost\Client\Auth\Kerberos -Value $true
Clear-Item -Path WSMan:\localhost\Client\TrustedHosts -Force
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
winrm create winrm/config/Listener?Address=*+Transport=HTTPS @{}

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v AllowUnencryptedTraffic /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" /v AllowUnencryptedTraffic /t REG_DWORD /d 0 /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v AllowBasic /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" /v AllowBasic /t REG_DWORD /d 0 /f

Disable-WSManCredSSP -Role Client
Disable-WSManCredSSP -Role Server

reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WinRM\Client" /v AllowDigest /t REG_DWORD /d 0 /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v AllowNegotiate /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" /v AllowNegotiate /t REG_DWORD /d 0 /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v AllowKerberos /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" /v AllowKerberos /t REG_DWORD /d 1 /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v DisableRunAs /t REG_DWORD /d 1 /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v CBTHardeningLevelStatus /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v CbtHardeningLevel /t REG_SZ /d "Strict" /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v HttpCompatibilityListener /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v HttpsCompatibilityListener /t REG_DWORD /d 0 /f

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v AllowAutoConfig /t REG_DWORD /d 0 /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v IPv4Filter /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" /v IPv6Filter /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate CVE-2022-0001" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverride /t REG_DWORD /d 0x00800000 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v FeatureSettingsOverrideMask /t REG_DWORD /d 0x00000003 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Bing Search" -ForegroundColor white

reg add "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate digital signature hijacking" -ForegroundColor white

# https://pentestlab.blog/2017/11/06/hijacking-digital-signatures/

reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg\{603BCC1F-4B59-4E08-B724-D2C6297EF351}" /v DLL /t REG_SZ /d "C:\Windows\System32\WindowsPowerShell\v1.0\pwrshsip.dll" /f
reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg\{603BCC1F-4B59-4E08-B724-D2C6297EF351}" /v FuncName /t REG_SZ /d "PsGetSignature" /f

reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg\{C689AAB8-8E78-11D0-8C47-00C04FC295EE}" /v DLL /t REG_SZ /d "C:\Windows\System32\ntdll.dll" /f
reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllGetSignedDataMsg\{C689AAB8-8E78-11D0-8C47-00C04FC295EE}" /v FuncName /t REG_SZ /d "CryptSIPGetSignedDataMsg" /f

reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllVerifyIndirectData\{603BCC1F-4B59-4E08-B724-D2C6297EF351}" /v DLL /t REG_SZ /d "C:\Windows\System32\WindowsPowerShell\v1.0\pwrshsip.dll" /f
reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllVerifyIndirectData\{603BCC1F-4B59-4E08-B724-D2C6297EF351}" /v FuncName /t REG_SZ /d "PsVerifyHash" /f

reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllVerifyIndirectData\{C689AAB8-8E78-11D0-8C47-00C04FC295EE}" /v DLL /t REG_SZ /d "C:\Windows\System32\WINTRUST.DLL" /f
reg add "HKLM\SOFTWARE\Microsoft\Cryptography\OID\EncodingType 0\CryptSIPDllVerifyIndirectData\{C689AAB8-8E78-11D0-8C47-00C04FC295EE}" /v FuncName /t REG_SZ /d "CryptSIPVerifyIndirectData" /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Windows Platform Binary Table" -ForegroundColor white

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v DisableWpbtExecution /t REG_DWORD /d 1 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate Disk Cleanup Persistence" -ForegroundColor white

.\tools\regjump.exe -accepteula HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches

reg delete HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches /f
Start-Sleep -Milliseconds 2500 # Here so that it has some time to "cool down" ig?? idk but doing the switching instantly caused errors
reg import .\files\RegistryDefaults\VolumeCacheKeys.reg

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate Credential Manager DLL Persistence" -ForegroundColor white

$services = (Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Control\NetworkProvider\Order").ProviderOrder.split(",")
$defaultServices = @("RDPNP", "P9NP", "LanmanWorkstation", "webclient")

foreach($service in $services) {
    if(!$defaultServices.Contains($service)) {
        Write-Host "Investigate the following service: $service" -ForegroundColor red
    } else {
        $provider = (Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Services\$service\NetworkProvider").ProviderPath
        if($service -eq "RDPNP" -and $provider -ne "C:\Windows\System32\drprov.dll") {
            Write-Host "$service ProviderPath compromised! Value: $provider"
            reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$service\NetworkProvider" /v ProviderPath /t REG_EXPAND_SZ /d "%SystemRoot%\System32\drprov.dll" /f
        }
        if($service -eq "P9NP" -and $provider -ne "C:\Windows\System32\p9np.dll") {
            Write-Host "$service ProviderPath compromised! Value: $provider"
            reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$service\NetworkProvider" /v ProviderPath /t REG_EXPAND_SZ /d "%SystemRoot%\System32\p9np.dll" /f
        }
        if($service -eq "LanmanWorkstation" -and $provider -ne "C:\Windows\System32\ntlanman.dll") {
            Write-Host "$service ProviderPath compromised! Value: $provider"
            reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$service\NetworkProvider" /v ProviderPath /t REG_EXPAND_SZ /d "%SystemRoot%\System32\ntlanman.dll" /f
        }
        if($service -eq "webclient" -and $provider -ne "C:\Windows\System32\davclnt.dll") {
            Write-Host "$service ProviderPath compromised! Value: $provider"
            reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$service\NetworkProvider" /v ProviderPath /t REG_EXPAND_SZ /d "%SystemRoot%\System32\davclnt.dll" /f
        }
    }
}

reg add HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order /v ProviderOrder /t REG_SZ /d "RDPNP,P9NP,LanmanWorkstation,webclient" /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate Print Monitor Persistence" -ForegroundColor white

reg delete HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Print\Monitors /f
reg import .\files\RegistryDefaults\PrintMonitors.reg

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Remote COM Debugging over RPC" -ForegroundColor white

$ErrorActionPreference = "SilentlyContinue"

$debugger = (Get-ItemProperty "HKLM://SOFTWARE\Microsoft\Windows NT\CurrentVersion\DebugObjectRPCEnabled\AeDebug").Debugger

if($debugger) {
    Write-Host "RPC COM Debugger is configured, investigate: $debugger" -ForegroundColor Yellow
    pause
}

reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DebugObjectRPCEnabled" /f

$ErrorActionPreference = "Continue"

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate HKCU Load Persistence" -ForegroundColor white

$loadKey = (Get-ItemProperty "HKCU://Software\Microsoft\Windows NT\CurrentVersion\Windows").Load

if($loadKey) {
    Write-Host "HKCU Load key is configured: $loadkey" -ForegroundColor Yellow
    pause
}

reg delete "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows" /v Load /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate Recycle Bin COM Extension Handler Persistence" -ForegroundColor white

$ErrorActionPreference = "SilentlyContinue"

$hkcrCommand = (Get-ItemProperty "HKCR://CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\open\command")."(default)"

if($hkcrCommand) {
    Write-Host "Recycle Bin COM Extension Handler Persistence Detected: $hkcrCommand" -ForegroundColor Red
    pause
}

reg delete "HKEY_CLASSES_ROOT\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\open" /f

$hklmCommand = (Get-ItemProperty "HKLM://SOFTWARE\Classes\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\open\command")."(default)"

if($hklmCommand) {
    Write-Host "Recycle Bin COM Extension Handler Persistence Detected: $hklmCommand" -ForegroundColor Red
    pause
}

reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\open" /f

$ErrorActionPreference = "Continue"

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate Desired State Configuration Persistence" -ForegroundColor white

Stop-DscConfiguration -Force
Disable-DscDebug

Remove-DscConfigurationDocument -Stage Current
Remove-DscConfigurationDocument -Stage Pending
Remove-DscConfigurationDocument -Stage Previous

# If there's a way to read these files (C:\Windows\System32\Configuration) then I'll add it, but for now, we're just going to remove them and that should remove the persistence

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate TXT File Association Persistence" -ForegroundColor white

$res = (cmd /c "ftype txtfile")

if($res -ne "txtfile=%SystemRoot%\system32\NOTEPAD.EXE %1") {
    Write-Host "TXT File Persistence detected: $($res.split("=")[1])" -ForegroundColor Red
    pause
}

reg add "HKEY_CLASSES_ROOT\txtfile\shell\open\command" /ve /t REG_EXPAND_SZ /d "%SystemRoot%\system32\NOTEPAD.EXE %1" /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Mitigate Netsh Extension Persistence" -ForegroundColor white

reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NetSh" /f
Start-Sleep -Milliseconds 2500
reg import .\files\RegistryDefaults\Netsh.reg

if($version -eq "19" -or $version -eq "22") {
    reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NetSh" /v p2pnetsh /f
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Detect LNK Keyboard Shortcut Persistence" -ForegroundColor white

$lnkFileDirectory = "C:\Users\$(Get-Content .\CURRENT_USER.txt)\AppData\Roaming\Microsoft\Windows\Start Menu"

Get-ChildItem $lnkFileDirectory | ForEach-Object {
    if($_.Name.EndsWith(".lnk")) {
        $name = $_.Name
        $target = (New-Object -ComObject WScript.Shell).CreateShortcut("$lnkFileDirectory\$name")
        Write-Host "Potential Persistence Found: $lnkFileDirectory\$name" -ForegroundColor Red
        Write-Output "Program: $($target.TargetPath)"
        Write-Output "Arguments: $($target.Arguments)"
        Write-Output "Hotkey: $($target.Hotkey)"
        Write-Output ""
    }
}

Write-Host "Check your desktop for any weird shortcuts as well as this can also apply there" -ForegroundColor Yellow

pause

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Detect Control Panel Persistence" -ForegroundColor white

$ErrorActionPreference = "SilentlyContinue"

$foundPersistence = $false

(Get-Item "HKCU://SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\CPLs").Property | ForEach-Object {
    $foundPersistence = $true
    $item = (Get-ItemProperty "HKCU://SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\CPLs\")."$_"
    Write-Host "Persistence Found: $item" -ForegroundColor Red
}

if($foundPersistence) {
    Read-Host "Press enter when you've investigated/deleted the above files, if any"
}

reg delete "HKU\$CURRENT_USER_SID\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel" /f

$ErrorActionPreference = "Continue"

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Delete Alternative Streams" -ForegroundColor white

.\tools\streams.exe -nobanner -accepteula -s -d C:

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Reset user and system path variables" -ForegroundColor white

$userPath = "%USERPROFILE%\AppData\Local\Microsoft\WindowsApps"
$systemPath = "%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem;%SystemRoot%\System32\WindowsPowerShell\v1.0\;%SystemRoot%\System32\OpenSSH\"

$currentUserPATH = (Get-ItemProperty -Path "HKCU://Environment").Path
$currentSystemPATH = (Get-ItemProperty -Path "HKLM://SYSTEM\CurrentControlSet\Control\Session Manager\Environment").Path

if($currentUserPATH -ne $userPath -or $currentSystemPATH -ne $systemPath) {
    Write-Host "Current User PATH: $currentUserPath" -ForegroundColor Yellow
    Write-Host "Current System PATH: $currentSystemPATH" -ForegroundColor Yellow
    Write-Host "Investigate any non-default directories in the aforementioned PATH variables" -ForegroundColor Yellow
    pause
}

reg add "HKU\$CURRENT_USER_SID\Environment" /v Path /t REG_EXPAND_SZ /d $userPath /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path /t REG_EXPAND_SZ /d $systemPath /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Reset HKLM\Security ACLs" -ForegroundColor white

$rootACL = Get-Acl "HKLM:\SECURITY"

$rootACL.SetOwner((New-Object System.Security.Principal.NTAccount("Builtin", "Administrators")))
$rootACL.SetSecurityDescriptorSddlForm("O:BAG:SYD:P(A;CI;KA;;;SY)(A;CI;RCWD;;;BA)")
$rootACL.SetAccessRuleProtection($true, $false) # Disables any inheritance

Set-Acl "HKLM:\SECURITY" -AclObject $rootACL

.\tools\regjump.exe -accepteula HKEY_LOCAL_MACHINE\SECURITY

Write-Output "Right Click highlighted key > Permissions > Advanced > Check 'Replace all child object permissions...' > OK > Yes"
pause

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Find LSA Notification Packages/Password Filters" -ForegroundColor white

$defaultFilters = @("scecli")
$filters = (Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Control\Lsa")."Notification Packages"

foreach($filter in $filters) {
    if(!$defaultFilters.Contains($filter)) {
        Write-Host "Investigate the following package filter (use everything to find the file ffs): $filter" -ForegroundColor Red
    }
}

$newFilters = ""

foreach($df in $defaultFilters) {
    $newFilters += "$df\0"
}

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa" /v "Notification Packages" /t REG_MULTI_SZ /d $newFilters /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Credential Delegation" -ForegroundColor white

reg delete HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Detect TimeProvider persistence" -ForegroundColor white

$ntpClient = (Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient").DllName
$ntpServer = (Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer").DllName
$vmicTimeProvider = (Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\VMICTimeProvider").DllName

$timePersistenceDetected = $false

if($ntpClient.ToLower() -ne "c:\windows\system32\w32time.dll") {
    Write-Host "Persistence Detected! Investigate the following DLL: $ntpClient" -ForegroundColor Red
    $timePersistenceDetected = $true
}

if($ntpServer.ToLower() -ne "c:\windows\system32\w32time.dll") {
    Write-Host "Persistence Detected! Investigate the following DLL: $ntpServer" -ForegroundColor Red
    $timePersistenceDetected = $true
}

if($vmicTimeProvider.ToLower() -ne "c:\windows\system32\vmictimeprovider.dll") {
    Write-Host "Persistence Detected! Investigate the following DLL: $ntpServer" -ForegroundColor Red
    $timePersistenceDetected = $true
}

if($timePersistenceDetected) { pause }

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient" /v DllName /t REG_EXPAND_SZ /d "C:\Windows\System32\w32time.dll" /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpServer" /v DllName /t REG_EXPAND_SZ /d "C:\Windows\System32\w32time.dll" /f | Out-Null
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\VMICTimeProvider" /v DllName /t REG_EXPAND_SZ /d "C:\Windows\System32\vmictimeprovider.dll" /f | Out-Null


Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Detect Powershell Profile persistence" -ForegroundColor white

$profilePaths = $PROFILE | Select-Object *

if(Test-Path $profilePaths.AllUsersAllHosts) {
    Write-Host "System Powershell profile found! Investigate the following file: $($profilePaths.AllUsersAllHosts)" -ForegroundColor Red
    pause
}

if(Test-Path $profilePaths.AllUsersCurrentHost) {
    Write-Host "System Powershell profile found! Investigate the following file: $($profilePaths.AllUsersCurrentHost)" -ForegroundColor Red
    pause
}

if(Test-Path $profilePaths.CurrentUserAllHosts) {
    Write-Host "User Powershell profile found! Investigate the following file: $($profilePaths.CurrentUserAllHosts)" -ForegroundColor Red
    pause
}

if(Test-Path $profilePaths.CurrentUserCurrentHost) {
    Write-Host "User Powershell profile found! Investigate the following file: $($profilePaths.CurrentUserCurrentHost)" -ForegroundColor Red
    pause
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Enable IE Security Prompts for Windows Installer" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Installer" /v SafeForScripting /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Delete ARP Cache" -ForegroundColor white

arp -d *

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Set OpenSSH shell to Command Prompt" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\OpenSSH" /v DefaultShell /t REG_SZ /d "C:\Windows\System32\cmd.exe" /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Delete RDP Bitmap Cache" -ForegroundColor white

Get-ChildItem -Path "C:\Users" -Force | ForEach-Object {
    if(Test-Path "C:\Users\$($_.Name)\AppData\Local\Microsoft\Terminal Server Client\Cache") {
        del "C:\Users\$($_.Name)\AppData\Local\Microsoft\Terminal Server Client\Cache\*"
    }
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable automatic administrative logon for the Recovery Console" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Setup\RecoveryConsole" /v SecurityLevel /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Reset Event Viewer ACLs" -ForegroundColor white

icacls.exe "C:\Windows\System32\eventvwr.exe" /setowner "NT SERVICE\TrustedInstaller" | Out-Null
icacls.exe "C:\Windows\System32\eventvwr.exe" /grant:r "ALL APPLICATION PACKAGES:(RX)" "ALL RESTRICTED APPLICATION PACKAGES:(RX)" "System:(RX)" "Administrators:(RX)" "Users:(RX)" "NT SERVICE\TrustedInstaller:F" | Out-Null
icacls.exe "C:\Windows\System32\eventvwr.exe" /inheritancelevel:r | Out-Null

icacls.exe "C:\Windows\System32\eventvwr.msc" /setowner "NT SERVICE\TrustedInstaller" | Out-Null
icacls.exe "C:\Windows\System32\eventvwr.msc" /grant:r "ALL APPLICATION PACKAGES:(RX)" "ALL RESTRICTED APPLICATION PACKAGES:(RX)" "System:(RX)" "Administrators:(RX)" "Users:(RX)" "NT SERVICE\TrustedInstaller:F" | Out-Null
icacls.exe "C:\Windows\System32\eventvwr.msc" /inheritancelevel:r | Out-Null

icacls.exe "C:\Windows\System32\winevt\Logs" /setowner "SYSTEM"
$folderACL = Get-Acl -Path "C:\Windows\System32\winevt\Logs"
$folderACL.SetSecurityDescriptorSddlForm("O:SYG:SYD:PAI(A;CI;FR;;;AU)(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;FA;;;S-1-5-80-880578595-1860270145-482643319-2788375705-1540778122)")
$folderACL.SetAccessRuleProtection($true, $false) # Disables any inheritance

Set-Acl -Path "C:\Windows\System32\winevt\Logs" -AclObject $folderACL

Get-ChildItem "C:\Windows\System32\winevt\Logs" -Force | ForEach-Object {
    $acl = (Get-Acl -Path "$($_.FullName)")
    $acl.SetOwner((New-Object System.Security.Principal.NTAccount("LOCAL SERVICE")))
    $acl.SetAccessRuleProtection($false, $false) # Allows any inheritance (shits tweaking and adds everyone perms to the object :sob:), set perms below just to be safe
    $acl.SetSecurityDescriptorSddlForm("O:LSG:LSD:AI(A;ID;FA;;;S-1-5-80-880578595-1860270145-482643319-2788375705-1540778122)(A;ID;FA;;;SY)(A;ID;FA;;;BA)")
    Set-Acl -Path "$($_.FullName)" -AclObject $acl
}

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Disable Keyboard Crashing" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\i8042prt\Parameters" /v CrashOnCtrlScroll /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters" /v CrashOnCtrlScroll /t REG_DWORD /d 0 /f

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Delete DebugFlags" -ForegroundColor white

reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CI" /v DebugFlags /f | Out-Null

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Turn on Windows Defender PPL" -ForegroundColor white

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WinDefend" /v LaunchProtected /t REG_DWORD /d 3 /f