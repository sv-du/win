function GetSettings() {
    if(!(Test-Path ".\settings.json")) {
        clear
        $version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
        while(!@("10", "11", "19", "22").Contains($version)) {
            clear
            $version = Read-Host "What version of Windows are you running? (10, 11, 19, 22)"
        }
        $isADInstalled = $False
        if($version -eq "19" -or $version -eq "22") {
            $isADInstalled = (Read-Host "Do you have AD installed? (y/n)").ToLower() -eq "y"
        }
        $CurrentUser = (Get-Content .\CURRENT_USER.txt).Trim()
        $settings = @{
            "Version" = $version
            "CurrentUser" = $CurrentUser
            "ADInstalled" = $isADInstalled
        }
        Remove-Item .\CURRENT_USER.txt
        ConvertTo-Json $settings | Out-File ".\settings.json"
    }
    $obj = Get-Content ".\settings.json" | ConvertFrom-Json
    return $obj
}

function GetBaselineFileName() {
    $settings = GetSettings
    if($settings.ADInstalled) {
        return $settings.Version + "-AD"
    } else {
        return $settings.Version
    }
}

function AddUsersRegistryValue([string]$Path, [string]$ValueName, [Microsoft.Win32.RegistryValueKind]$Type, $Data) {
    $CommandType
    if($Type.ToString().Equals("String")) {
        $CommandType = "REG_SZ";
    }
    if($Type.ToString().Equals("ExpandString")) {
        $CommandType = "REG_EXPAND_SZ";
    }
    if($Type.ToString().Equals("Binary")) {
        $CommandType = "REG_BINARY";
    }
    if($Type.ToString().Equals("DWord")) {
        $CommandType = "REG_DWORD";
    }
    if($Type.ToString().Equals("MultiString")) {
        $CommandType = "REG_MULTI_SZ";
    }
    if($Type.ToString().Equals("QWord")) {
        $CommandType = "REG_QWORD";
    }
    if($Path.StartsWith("HKCU") -or $Path.StartsWith("HKEY_CURRENT_USER")) {
        New-PSDrive -Name HU -PSProvider Registry -Root HKEY_USERS | Out-Null
        Get-ChildItem "HU:\\" | ForEach-Object {
            if(!([string]$_.Name).EndsWith("_Classes")) {
                $CommandPath = $_.Name + $Path.Substring($Path.IndexOf("\"))
                #Write-Output "Command: reg.exe add `"$($CommandPath)`" /v `"$($ValueName)`" /t $($CommandType) /d `"$($Data)`" /f | Out-Null"
                reg.exe add "$($CommandPath)" /v "$($ValueName)" /t $($CommandType) /d "$($Data)" /f | Out-Null
            }
        }
    }
}

function DeleteUsersRegistryValue([string]$Path, [string]$ValueName) {
    if($Path.StartsWith("HKCU") -or $Path.StartsWith("HKEY_CURRENT_USER")) {
        New-PSDrive -Name HU -PSProvider Registry -Root HKEY_USERS | Out-Null
        Get-ChildItem "HU:\\" | ForEach-Object {
            if(!([string]$_.Name).EndsWith("_Classes")) {
                $CommandPath = $_.Name + $Path.Substring($Path.IndexOf("\"))
                #Write-Output "Command: reg.exe delete `"$($CommandPath)`" /v `"$($ValueName)`" /f | Out-Null"
                reg.exe delete "$($CommandPath)" /v "$($ValueName)" /f | Out-Null
            }
        }
    }
}