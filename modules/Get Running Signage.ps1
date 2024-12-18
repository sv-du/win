$running = Get-Process
$count = 1

foreach($process in $running) {
    Write-Output "$count/$($running.Count) process check"
    $count++
    $path = $process.Path
    if(!$path) { continue }
    $psSignResult = (Get-AuthenticodeSignature -LiteralPath "$path").Status -eq "Valid"
    $sigCheckResult = .\tools\sigcheck.exe -accepteula -nobanner -h -vr -vt "$path"
    $sigCheckSigned = $sigCheckResult[1].split(":")[1].trim() -eq "Signed"
    $sigCheckVT = $sigCheckResult[16].split(":")[1].trim().split("/")[0] -eq "0"
    if(!$psSignResult -or !$sigCheckSigned -or !$sigCheckVT) {
        Write-Output "Running process, '$path', is not signed and/or has a non-zero VirusTotal detection result"
        Write-Output ""
    }
}