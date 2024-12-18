Set-DhcpServerv4DnsSetting -UpdateDnsRRForOlderClients $False
Set-DhcpServerv4DnsSetting -DeleteDnsRRonLeaseExpiry $True
Set-DhcpServerv4DnsSetting -DynamicUpdates "OnClientRequest"
Set-DhcpServerv4DnsSetting -DisableDnsPtrRRUpdate $True
Set-DhcpServerv4DnsSetting -NameProtection $True

Set-DhcpServerv6DnsSetting -DeleteDnsRRonLeaseExpiry $True
Set-DhcpServerv6DnsSetting -DynamicUpdates "OnClientRequest"
Set-DhcpServerv6DnsSetting -NameProtection $True

Set-DhcpServerAuditLog -Enable $True

net stop dhcpserver
net start dhcpserver