function getAllServices() {
    $services = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Services"
    $parsedServices = [System.Collections.ArrayList]::new()
    foreach($service in $services) {
        $rawName = $service.Name.Split("\")
        $name = $rawName[$rawName.Count - 1]
        $binaryPath = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$name").ImagePath
        if(!$binaryPath) { $binaryPath = "No service binary path found" }
        (sc.exe sdshow "$name") > err.txt
        $serviceSddl = $null
        $content = Get-Content .\err.txt
        if($content.Length -gt 2) {
            $serviceSddl = "No SDDL found"
        } else {
            $serviceSddl = $content[1] + ""
        }
        $regSddl = (Get-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$name").GetSecurityDescriptorSddlForm("all")
        $parsedServices.Add(@{
            name = $name
            binPath = $binaryPath
            serviceSddl = $serviceSddl
            regSddl = $regSddl
        }) | Out-Null
    }
    Remove-Item -Path ".\err.txt"
    return $parsedServices
}

$adServices = @("LanmanServer", "Bowser", "WinRM", "LanmanWorkstation", "Browser")

$disabledServices = @(
    "ftpsvc",
    "msftpsvc",
    "w3svc",
    "iphlpsvc",
    "snmptrap",
    "SharedAccess",
    "simptcp",
    "RasAuto",
    "RasMan",
    "SessionEnv",
    "TermService",
    "UmRdpService",
    "RpcLocator",
    "RemoteRegistry",
    "RemoteAccess",
    "lpdsvc",
    "TapiSrv",
    "TlntSvr",
    "SNMP",
    "ssdpsrv",
    "HomeGroupProvider",
    "HomeGroupListener",
    "NetTcpPortSharing",
    "Spooler",
    "icssvc",
    "DiagTrack",
    "WbioSrvc",
    "RetailDemo",
    "Fax",
    "WinRM",
    "lfsvc",
    "lmhosts",
    "upnphost",
    "BTAGService",
    "bthserv",
    "MapsBroker",
    "irmon",
    "lltdsvc",
    "LxssManager",
    "MSiSCSI",
    "PNRPsvc",
    "p2psvc",
    "p2pimsvc",
    "PNRPAutoReg",
    "wercplsupport",
    "sacsvr",
    "WMSvc",
    "WerSvc",
    "WMPNetworkSvc",
    "WpnService",
    "PushToInstall",
    "XboxGipSvc",
    "XblAuthManager",
    "XblGameSave",
    "XboxNetApiSvc",
    "WalletService",
    "PhoneSvc",
    "PlugPlay",
    "xbgm",
    "spectrum",
    "wisvc",
    "StiSvc",
    "FrameServer",
    "DusmSvc",
    "DoSvc",
    "AJRouter",
    "SysMain",
    "WinHttpAutoProxySvc",
    "tzautoupdate",
    "AppVClient",
    "shpamsvc",
    "SCardSvr",
    "UevAgentService",
    "ALG",
    "PeerDistSvc",
    "WFDSConSvc",
    "WebClient",
    "UwfServcingSvc",
    "TabletInputService",
    "WiaRpc",
    "SharedRealitySvc",
    "SCPolicySvc",
    "ScDeviceEnum",
    "SensorService",
    "SensrSvc",
    "SensorDataService",
    "iprip",
    "RmSvc",
    "WpcMonSvc",
    "SEMgrSvc",
    "CscService",
    "NcbService",
    "NetTcpActivator",
    "NetMsmqActivator",
    "SmsRouter",
    "MsKeyboardFilter",
    "wlidsvc",
    "diagnosticshub.standardcollector.service",
    "MSMQTriggers",
    "MSMQ",
    "lpxlatCfgSvc",
    "TrkWks",
    "WdiSystemHost",
    "WdiServiceHost",
    "diagsvc",
    "CertPropSvc",
    "PeerDistSvc",
    "BluetoothUserService_*",
    "BTAGService",
    "BthAvctpSvc",
    "PcaSvc"
)

$enabledServices = @(
    "RpcSs",
    "BFE",
    "Sense",
    "mpsdrv",
    "mpssvc",
    "WinDefend",
    "ssh-agent",
    "AFD",
    "tdx",
    "Dhcp",
    "nlasvc",
    "http",
    "Wecsvc",
    "EventLog",
    "Dnscache",
    "W32Time",
    "wscsvc",
    "gpsvc",
    "Audiosrv",
    "sshd",
    "SecurityHealthService",
    "wuauserv",
    "WaaSMedicSvc",
    "BDESVC",
    "CryptSvc",
    "DcomLaunch",
    "nsi",
    "RpcEptMapper",
    "SamSs",
    "WdNisSvc",
    "WEPHOSTSVC",
    "WSearch",
    "TrustedInstaller",
    "msiserver",
    "FontCache",
    "AudioEndpointBuilder",
    "vds",
    "ProfSvc",
    "UserManager",
    "UsoSvc",
    "Schedule",
    "SgrmBroker",
    "SystemEventsBroker",
    "sppsvc",
    "WPDBusEnum",
    "LSM",
    "EFS",
    "DPS",
    "CoreMessagingRegistrar",
    "CDPUserSvc_*",
    "CDPSvc",
    "SENS",
    "EventSystem",
    "BrokerInfrastructure",
    "BITS",
    "winmgmt"
)

$isCreatingBaseline = (Read-Host "Are you generating a service baseline? (y/n)").ToLower() -eq "y"

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
    $services = getAllServices
    (ConvertTo-Json $services) > ".\baselines\services\$fileName"
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

if(!(Test-Path ".\baselines\services\$fileName.txt")) {
    Write-Output "Baseline file not found, stopping script"
    exit
}

$computerServices = [System.Collections.ArrayList](getAllServices)
$baselineServices = [System.Collections.ArrayList]((Get-Content ".\baselines\services\$fileName.txt") | ConvertFrom-Json)

function findService($arr, $name) {
    for($i = 0; $i -lt $arr.Count; $i++) {
        if($arr[$i].name -eq $name) { return $arr[$i] }
    }
    return $null
}

foreach($service in $baselineServices) {
    $computerServiceData = findService($computerServices) -name "$($service.name)"
    if(!$computerServiceData) { # Flag services that are in baseline but not installed
        Write-Host "Service '$($service.name)' is part of the baseline but not installed on the system" -ForegroundColor Red
    }
}

$fixBinaryPaths = (Read-Host "Do you want the script to try to automatically fix binary paths based on the baseline? (y/n)").ToLower() -eq "y"
$fixServiceSDDLs = (Read-Host "Do you want the script to try to automatically fix service SDDLs based on the baseline? (y/n)").ToLower() -eq "y"
$fixRegSDDLs = (Read-Host "Do you want the script to try to automatically fix registry SDDLs based on the baseline? (y/n)").ToLower() -eq "y"

foreach($service in $computerServices) {
    $baselineServiceData = findService($baselineServices) -name "$($service.name)"
    if(!$baselineServiceData) { # Flag services not in baseline but installed
        Write-Host "Service '$($service.name)' is not part of the baseline but installed on the system" -ForegroundColor Red
        Write-Host "Binary Path: $($service.binPath)" -ForegroundColor Red
        continue
    }
    if($baselineServiceData.binPath -ne "No service binary path found") {
        if($baselineServiceData.binPath -eq $service.binPath) { continue }
        Write-Host "Service '$($service.name)' has a different binary path than the one in the baseline" -ForegroundColor Yellow
        Write-Output "Current Binary Path: $($service.binPath)"
        Write-Output "Baseline Binary Path: $($baselineServiceData.binPath)"
        if($fixBinaryPaths) {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.name)" -Name ImagePath -Value "$($baselineServiceData.binPath)"
        }
    }
    if($baselineServiceData.serviceSddl -ne "No SDDL found") {
        if($baselineServiceData.serviceSddl -eq $service.serviceSddl) { continue }
        Write-Host "Service '$($service.name)' has a different SDDL than the one in the baseline" -ForegroundColor Yellow
        if($fixServiceSDDLs) {
            sc.exe sdset "$($service.name)" "$($baselineServiceData.serviceSddl)"
        }
    }
    $regAcl = Get-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.name)"
    if($baselineServiceData.regSddl -ne $regAcl.GetSecurityDescriptorSddlForm("all")) {
        Write-Host "Service '$($service.name)' has a different registry SDDL than the one in the baseline" -ForegroundColor Yellow
        if($fixRegSDDLs) {
            $regAcl.SetSecurityDescriptorSddlForm($baselineServiceData.regSddl)
            Set-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($service.name)" -AclObject $regAcl
        }
    }
}

pause

Write-Output "Disabling services`n"

foreach($service in $disabledServices) {
    $err = ((Get-Service "$service") 2>&1).ToString()
    if($err.Contains("Cannot find any service with service name")) {
        Write-Output "Skipped disabling $service because it is not installed"
    } else {
        net.exe stop "$service" /y
        sc.exe config "$service" start=disabled
    }
}

Write-Output "Enabling services`n"

foreach($service in $enabledServices) {
    $err = ((Get-Service "$service") 2>&1).ToString()
    if($err.Contains("Cannot find any service with service name")) {
        Write-Output "Skipped enabling $service because it is not installed"
    } else {
        sc.exe config "$service" start=auto
        net.exe start "$service" /y
    }
}

foreach($service in $enabledServices) { # Double pass in order to start services that might have not been started due to a dependency error (assuming the dependecy is further down the list)
    $err = ((Get-Service "$service") 2>&1).ToString()
    if(!$err.Contains("Cannot find any service with service name")) {
        net.exe start "$service"
    }
}

$isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"

if($isADInstalled) {
    foreach($service in $adServices) {
        sc.exe config "$service" start=auto
        net.exe start "$service"
    }
}

Write-Output "Setting failure actions for all services"

$services = getAllServices

foreach($service in $services) {
    sc.exe failure "$($service.name)" reset=432000 actions=restart/30000/restart/60000/restart/60000
}

Write-Output "Fetching unqouted image paths"

Get-WmiObject -class Win32_Service -Property Name,PathName | Where-Object {
    $_.PathName -ne $null -and # If a binary exists for the service (no binary = no vuln)
    $_.PathName -notlike "C:\Windows\System32\svchost.exe*" -and # Exclude svchost as this is all false positives
    $_.PathName -notlike '"*' -and # The string check to see if the path doesn't begin with a ", and if so, we can assume the path is not quoted
    $_.PathName.contains(" ") # This vuln only affects paths that have spaces
} | Select-Object Name,PathName

Write-Output "Fetching hidden services"

Compare-Object -ReferenceObject (Get-Service | Select-Object -ExpandProperty Name | % { $_ -replace "_[0-9a-f]{2,8}$" } ) -DifferenceObject (Get-ChildItem -path hklm:\system\currentcontrolset\services | % { $_.Name -Replace "HKEY_LOCAL_MACHINE\\","HKLM:\" } | Where-Object { Get-ItemProperty -Path "$_" -name objectname -erroraction 'ignore' } | % { $_.substring(40) }) -PassThru | Where-Object {$_.sideIndicator -eq "=>"}