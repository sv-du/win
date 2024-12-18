function IsSuspiciousPath($path) {
    return ($path -like "C:\Users\*")
}

function IsUnsigned($path) {
    $err = (Get-AuthenticodeSignature -FilePath $path) 2>&1
    if($err) { return $true }
    $Signatures = Get-AuthenticodeSignature -FilePath $path
    return ($Signatures.Status -ne "Valid")
}

function CalculateEntropy($str) {
    $inputChars = $str.ToCharArray()
    $charCount = $inputChars.Length
    $charFrequency = @{}

    foreach ($char in $inputChars) {
        $charFrequency[$char]++
    }

    [double]$entropy = 0

    foreach ($frequency in $charFrequency.Values) {
        $probability = $frequency / $charCount
        $entropy -= $probability * [Math]::Log($probability, 2)
    }

    return $entropy
}

function IsHighEntropyName($name) {
    $entropy = CalculateEntropy($name)
    return ($entropy -gt 3.5)
}

function HasSuspiciousExtension($path) {
    $suspiciousExtensions = @('.vbs', '.js', '.bat', '.cmd', '.scr')
    $extension = [IO.Path]::GetExtension($path)
    return ($suspiciousExtensions -contains $extension)
}

$enableExtraChecks = (Read-Host "Enable checks more likely to result in false positives? (y/n)") -eq "y"

$AllServices = Get-CimInstance -Class Win32_Service

$DetectedServices = New-Object System.Collections.ArrayList

foreach($Service in $AllServices) {
    $BinaryPathName = $Service.PathName.Trim('"')

    # Check for suspicious characteristics
    $PathSuspicious = IsSuspiciousPath($BinaryPathName)
    $LocalSystemAccount = ($Service.StartName -eq "LocalSystem")
    $NoDescription = ([string]::IsNullOrEmpty($Service.Description))
    $Unsigned = IsUnsigned($BinaryPathName)

    $ShortName = $false
    $ShortDisplayName = $false
    $HighEntropyName = $false
    $HighEntropyDisplayName = $false
    $SuspiciousExtension = $false

    if($enableExtraChecks) {
        $ShortName = ($Service.Name.Length -le 5)
        $ShortDisplayName = ($Service.DisplayName.Length -le 5)
        $HighEntropyName = IsHighEntropyName($Service.Name)
        $HighEntropyDisplayName = IsHighEntropyName($Service.DisplayName)
        $SuspiciousExtension = HasSuspiciousExtension($BinaryPathName)
    }

    if($PathSuspicious -or $LocalSystemAccount -or $NoDescription -or $Unsigned -or $ShortName -or $ShortDisplayName -or $HighEntropyName -or $HighEntropyDisplayName -or $SuspiciousExtension) {
        if(!$BinaryPathName.Contains("C:\Windows\system32\svchost.exe")) {
            $DetectedServices.Add($Service) | Out-Null
        }
    }
}

if($DetectedServices -eq 0) {
    Write-Output "No potentially suspicious services detected."
    exit
}

Write-Output "Potentially Suspicious Services Detected"
Write-Output "----------------------------------------"

foreach($Service in $DetectedServices) {
    Write-Output "Name: $($Service.Name) - Binary Path: $($Service.PathName.Trim('"'))"

    if($PathSuspicious) {
        Write-Output "`t- Running from a potentially suspicious path"
    }

    if($LocalSystemAccount) {
        Write-Output "`t- Running with a LocalSystem account"
    }

    if($NoDescription) {
        Write-Output "`t- No description provided"
    }

    if($Unsigned) {
        Write-Output "`t- Unsigned executable"
    }

    if($ShortName) {
        Write-Output "`t- Very short service name"
    }

    if($ShortDisplayName) {
        Write-Output "`t- Very short display name"
    }

    if($HighEntropyName) {
        Write-Output "`t- High entropy service name"
    }

    if($HighEntropyDisplayName) {
        Write-Output "`t- High entropy display name"
    }

    if($SuspiciousExtension) {
        Write-Output "`t- Suspicious file extension"
    }
}