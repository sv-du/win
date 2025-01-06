function getGuestUser() {
    $users = Get-ADUser -Filter * -Properties *
    foreach($user in $users) {
        if($user.Description.Contains("Built-in account for guest access to the computer/domain")) {
            return $user
        }
    }
}

Write-Output "Fixing SAM ACLs in case they are broken"

$rootACL = Get-Acl "HKLM:\SAM\SAM"

if(-not $rootACL) {
    Write-Output "Holy shit something really fucked up happend here"
    Write-Output "If you see this you gonna have to somehow do this manually (windows PE maybe???)"
    exit
}

$rootACL.SetOwner((New-Object System.Security.Principal.NTAccount("Builtin", "Administrators"))) # Set Owner to Administrators group
$rootACL.SetSecurityDescriptorSddlForm("O:BAG:SYD:P(A;CI;KA;;;SY)(A;CI;RCWD;;;BA)") # Sets SSDL to default one
$rootACL.SetAccessRuleProtection($true, $false) # Disables any inheritance

Set-Acl "HKLM:\SAM\SAM" -AclObject $rootACL

.\tools\regjump.exe -accepteula HKEY_LOCAL_MACHINE\SAM\SAM

Write-Output "Right Click highlighted key > Permissions > Advanced > Check 'Replace all child object permissions...' > OK > Yes"

pause

Get-ChildItem -Path "HKLM:\SAM\SAM" -Recurse | ForEach-Object { # Reset the owner to the Administrators group since the above action does not do that
    $acl = Get-Acl $_.PsPath
    $acl.SetOwner((New-Object System.Security.Principal.NTAccount("Builtin", "Administrators")))
    Set-Acl -Path $_.PSPath -AclObject $acl
}

clear

$password = "k97(0HaZ8~9^QMcxsg15rX-z"

$currentUser = Get-Content .\CURRENT_USER.txt

while(!(Test-Path .\UserData.txt)) {
    clear
    Write-Output "User data file not found, make a file called UserData.txt in the main directory"
    Write-Output "Use the format in the README to see format"
    pause
}

clear

$userData = @{}

$lines = Get-Content .\UserData.txt

foreach($line in $lines) {
    $line = ([string]$line.ToString()).Trim()
    $index = $line.IndexOf("|")
    if($index -eq -1) {
        $groups = [System.Collections.ArrayList]::new()
        $groups.add("Domain Users") | Out-Null
        $userData[$line] = $groups # If no groups are provided, add user to Users group
    } else {
        $user = $line.Substring(0, $index).Trim()
        $rawGroups = $line.Substring($index + 1).Split(",")
        $groups = [System.Collections.ArrayList]::new()
        for($i = 0; $i -lt $rawGroups.Count; $i += 1) {
            $groups.add($rawGroups[$i].Trim()) | Out-Null
        }
        if(!$groups.Contains("Domain Users")) {
            $groups.add("Domain Users") | Out-Null
        }
        $userData[$user] = $groups
    }
}

if(!$userData.Contains($currentUser)) {
    $groups = [System.Collections.ArrayList]::new()
    $groups.Add("Administrators") | Out-Null
    $groups.Add("Domain Users") | Out-Null
    $userData[$currentUser] = $groups
}

Write-Output "Unlocking all accounts"

$users = Get-ADUser -Filter * -Properties *

foreach($user in $users) { Set-AdObject "$($user.ObjectGUID)" -ProtectedFromAccidentalDeletion $false -Confirm:$false }

Write-Output "Deleting unauthorized users"

$builtInAccounts = [System.Collections.ArrayList]::new()

$users = Get-ADUser -Filter * -Properties *

foreach($user in $users) {
    if($userData.Contains($user.Name)) { continue }
    Write-Output "Deleting User: $($user.Name)"
    ((net.exe user /delete "$($user.Name)") 2>&1) > err.txt
    $err = (Get-Content .\err.txt)
    if($err.Count -gt 5) { # Pretty much only reason why this would error would be if the requested deleted user is a built in account
        $builtInAccounts.Add($user) | Out-Null
    }
    Write-Output ""
}

Remove-Item .\err.txt

Write-Output "Disabling built in accounts"

foreach($user in $builtInAccounts) {
    Write-Output "Disabling User: $($user.Name)"
    Disable-ADAccount "$user"
    Write-Output ""
}

Write-Output "Creating any missing users"

$ErrorActionPreference = "SilentlyContinue"

foreach($user in $userData.Keys) {
    $adUser = Get-ADUser "$user"
    if(!$adUser) {
        Write-Output "Creating new user: $user"
        net.exe user /add "$user" $password /y
    }
    $adUser = $null # If the command fails, it doesn't set $adUser to null
}

$ErrorActionPreference = "Continue"

Write-Output "Enabling all non-builtin accounts"

$users = Get-ADUser -Filter * -Properties *

foreach($user in $users) { Enable-ADAccount "$user" }

Write-Output "Setting all users primary group to 'Domain Users'"

$users = Get-ADUser -Filter *
$domainUsersGroup = Get-ADGroup "Domain Users" -Properties @("primaryGroupToken")

foreach($user in $users) { Set-ADUser "$user" -replace @{primaryGroupID=$domainUsersGroup.primaryGroupToken} }

Write-Output "Removing the users in all the groups (besides Domain Users) to reset them"

$groups = Get-ADGroup -Filter *

foreach($group in $groups) {
    if($group.Name -eq "Domain Users") { continue }
    $members = Get-ADGroupMember "$group"
    foreach($member in $members) {
        if("$member".Length -ne 0) {
            Write-Output "Removing $($member.Name) from $($group.Name)"
            Remove-ADGroupMember "$group" "$member" -Confirm:$false
        }
    }
}

Write-Output "Adding users to their groups defined in user data file"

$ErrorActionPreference = "SilentlyContinue"

foreach($user in $userData.Keys) {
    $groups = $userData[$user]
    foreach($group in $groups) {
        $adGroup = Get-ADGroup "$group"
        if(!$adGroup) {
            Write-Output "Creating new group: $group"
            New-ADGroup "$group" -GroupScope Global | Out-Null
        }
        Add-ADGroupMember "$group" "$user"
        $adGroup = $null
    }
}

$guestUser = getGuestUser

Add-ADGroupMember "Domain Guests" $guestUser

$ErrorActionPreference = "Continue"

$renameAccounts = (Read-Host "Rename builtin accounts? (Might break some checks) (y/n)") -eq "y"

if($renameAccounts) {
    foreach($user in $builtInAccounts) {
        $newName = -join ((48..57) + (97..122) | Get-Random -Count 20 | % {[char]$_})
        Rename-LocalUser "$($user.Name)" "$newName"
        Rename-ADObject "$($user.ObjectGUID)" $newName
    }
}

Write-Output "Setting user passwords and properties"

$users = Get-ADUser -Filter *

foreach($user in $users) {
    if($user.Name -ne $currentUser) {
        net.exe user "$($user.SamAccountName)" $password /y
        Set-ADUser "$user" -TrustedForDelegation $False -AllowReversiblePasswordEncryption $False -CannotChangePassword $False -ChangePasswordAtLogon $True -CompoundIdentitySupported $True -KerberosEncryptionType AES256 -PasswordNeverExpires $False -PasswordNotRequired $False -Clear scriptPath -SmartcardLogonRequired $False -AccountNotDelegated $True
        Set-ADAccountControl "$user" -DoesNotRequirePreAuth $False -AllowReversiblePasswordEncryption $False -TrustedForDelegation $False -TrustedToAuthForDelegation $False -UseDESKeyOnly $False -AccountNotDelegated $True
    }
}

Write-Output "Mitigating RID Hijacking and deleting ResetData keys" # ResetData keys are security questions, which as of writing this, are stored IN PLAIN TEXT (wtf microsoft)

$items = Get-ChildItem -Path "HKLM:\SAM\SAM\Domains\Account\Users"

foreach($item in $items) {
    $rawName = $item.Name.ToString().Split("\")
    $name = $rawName[$rawName.Count - 1]
    $props = (Get-ItemProperty -Path "HKLM:\SAM\SAM\Domains\Account\Users\$name")
    if(!$props.F) { continue }
    $f = $props.F
    $f[48] = [convert]::ToInt32($name.SubString($name.Length - 2), 16)
    $f[49] = [convert]::ToInt32($name.SubString($name.Length - 4, 2), 16)
    Set-ItemProperty -Path "HKLM:\SAM\SAM\Domains\Account\Users\$name" -Name F -Value $f
    if(((Get-ItemProperty -Path "HKLM:\SAM\SAM\Domains\Account\Users\$name").ResetData)) {
        reg delete "HKLM\SAM\SAM\Domains\Account\Users\$name" /v ResetData /f | Out-Null
    }
}

Write-Output "Deleting SID Histories from users and groups"

$users = Get-ADUser -Filter *
$groups = Get-ADGroup -Filter *

foreach($user in $users) {
    if($user.SIDHistory) {
        Write-Output "Clearing SIDHistory value from the following user: $user"
        Set-ADUser "$user" -Remove @{SIDHistory=$user.SIDHistory.Value}
    }
    if($user.servicePrincipalName) {
        Write-Output "Clearing servicePrincipalName value from the following user: $user"
        Set-ADUser "$user" -Remove @{servicePrincipalName=$user.servicePrincipalName.Value}
    }
}

foreach($group in $groups) {
    if($group.SIDHistory) {
        Write-Output "Clearing SIDHistory value from the following group: $group"
        Set-ADGroup "$group" -Remove @{SIDHistory=$group.SIDHistory.Value}
    }
}