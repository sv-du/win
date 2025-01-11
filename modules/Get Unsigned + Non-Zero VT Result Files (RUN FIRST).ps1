$extensions = @(
    "exe",
    "dll",
    "ps1",
    "psm1"
)

foreach($ex in $extensions) {
    while(!(Test-Path ".\$ex.efu")) {
        clear
        Write-Output "Everything $ex files not found"
        Write-Output "1: Install Everything"
        Write-Output "2: Set the search filter to '*.$ex'"
        Write-Output "3: Save (CTRL+S) the results in a file called '$ex.efu' in the script root directory"
        pause
    }
}

foreach($ex in $extensions) {
    $files = Get-Content ".\$ex.efu" | ConvertFrom-Csv
    $count = 1
    foreach($file in $files) {
        Write-Output "$count/$($files.Count) $ex file check"
        $count++
        $path = $file.Filename
        $psSignResult = (Get-AuthenticodeSignature -LiteralPath "$path").Status -eq "Valid"
        $sigCheckResult = .\tools\sigcheck.exe -accepteula -nobanner -h -vr -vt "$path"
        $sigCheckSigned = $sigCheckResult[1].split(":")[1].trim() -eq "Signed"
        $sigCheckVT = $sigCheckResult[16].split(":")[1].trim().split("/")[0] -eq "0"
        if((!$psSignResult -or !$sigCheckSigned) -and !$sigCheckVT) {
            Write-Host "File, '$path', is not signed and has a non-zero VirusTotal detection result" -ForegroundColor Red
        }
    }
}