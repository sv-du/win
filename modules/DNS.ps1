reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v DisableSmartNameResolution /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" /v DisableParallelAandAAAA /t REG_DWORD /d 1 /f

Set-DnsServerRRL -ResetToDefault -Force | Out-Null
Set-DnsServerRRL -Mode Enable -Force | Out-Null
Set-DnsServerResponseRateLimiting -ResetToDefault -Force | Out-Null

Set-DnsServerDiagnostics -All $True | Out-Null
Set-DnsServerDiagnostics -EventLogLevel 7 | Out-Null
Set-DnsServerDiagnostics -UseSystemEventLog $True | Out-Null
Set-DnsServerDiagnostics -EnableLogFileRollover $False | Out-Null
wevtutil set-log Microsoft-Windows-DNSServer/Analytical /e:true

Set-DnsServerRecursion -Enable $False | Out-Null
Set-DnsServerRecursion -SecureResponse $True | Out-Null

Set-MpPreference -DisableDnsOverTcpParsing $False | Out-Null
Set-MpPreference -DisableDnsParsing $False | Out-Null
Set-MpPreference -EnableDnsSinkhole $True | Out-Null

net stop DNS
net start DNS

dnscmd /clearcache

dnscmd /config /addressanswerlimit 5

dnscmd /config /bindsecondaries 0
dnscmd /config /bootmethod 3

dnscmd /config /defaultagingstate 1
dnscmd /config /defaultnorefreshinterval 0xA8
dnscmd /config /defaultrefreshinterval 0xA8
dnscmd /config /disableautoreversezones 1
dnscmd /config /disablensrecordsautocreation 1
dnscmd /config /dspollinginterval 30
dnscmd /config /dstombstoneinterval 0x278D00
dnscmd /config /DisableNSRecordsAutoCreation 1

dnscmd /config /ednscachetimeout 604,800
dnscmd /config /enableednsprobes 0
dnscmd /config /enablednssec 1
dnscmd /RetrieveRootTrustAnchors /f
dnscmd /config /enableglobalnamessupport 0
dnscmd /config /enableglobalqueryblocklist 1
dnscmd /config /eventloglevel 4
dnscmd /config /EnableVersionQuery 0

dnscmd /config /forwarddelegations 1
dnscmd /config /forwardingtimeout 0x5

dnscmd /config /globalneamesqueryorder 1
dnscmd /config /globalqueryblocklist isatap wpad # These are the default values

dnscmd /config /isslave 0

dnscmd /config /localnetpriority 0
dnscmd /config /logfilemaxsize 0xFFFFFFFF
dnscmd /config /loglevel 0xFFFF
dnscmd /config /localnetprioritynetmask 0x0000ffff

dnscmd /config /maxcachesize 10000
dnscmd /config /maxcachettl 0x15180
dnscmd /config /maxnegativecachettl 0x384
dnscmd /config /namecheckflag 2
dnscmd /config /norecursion 1
dnscmd /config /openaclonproxyupdates 1

dnscmd /config /recursionretry 0xF
dnscmd /config /roundrobin 1
dnscmd /config /retrieveroottrustanchors

dnscmd /config /scavenginginterval 0x2
dnscmd /config /secureresponses 1
dnscmd /config /sendport 0x0
dnscmd /config /strictfileparsing 1

dnscmd /config /updateoptions 0x30F

dnscmd /config /writeauthorityns 0
dnscmd /config /xfrconnecttimeout 0x1E

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] CVE-2020-1350 and CVE-2020-25705 mitigations" -ForegroundColor white
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters" /v TcpReceivePacketSize /t REG_DWORD /d 0xFF00 /f | Out-Null
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters" /v MaximumUdpPacketSize /t REG_DWORD /d 0x4C5 /f | Out-Null

Set-DnsServerCache -PollutionProtection $True

Write-Host "[" -ForegroundColor white -NoNewLine; Write-Host "SUCCESS" -ForegroundColor green -NoNewLine; Write-Host "] Checking for ServerLevelPluginDll DNS parameter" -ForegroundColor white

$keys = Get-ItemProperty "HKLM://SYSTEM\CurrentControlSet\Services\DNS\Parameters"

if($keys.ServerLevelPluginDll) {
    Write-Output "ServerLevelPluginDll Key Found; Value = $($keys.ServerLevelPluginDll)"
    $shouldDelete = (Read-Host "Delete? (should prob) (y/n)") -eq "y"
    if($shouldDelete) {
        reg delete "HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters" /v ServerLevelPluginDll /f | Out-Null
    }
}

net stop DNS
net start DNS

DNSMgmt.msc

Write-Output "For every zone, set dynamic updates to secure only, disable zone transfers, set zone replication to domain without compatibility, and sign the zones (use strongest encrption algos, might need to install the AD certificate services)"

Write-Output "If applicable, integrate all DNS zones with Active Directory (change zone type on a zone label and check the bottom checkbox). This must be done before signing"

Write-Output "In the DNS server properties, check all check marks, load data from AD and registry, and set the savaging period to 7 days"
