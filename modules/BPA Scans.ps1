$models = Get-BpaModel
$successModels = [System.Collections.ArrayList]::new()

foreach($model in $models) {
    $id = $model.Id
    $invokeRes = Invoke-BpaModel -ModelId "$id"
    if(!$invokeRes.Success) { continue }
    $successModels.Add($model) | Out-Null
}

clear

foreach($model in $successModels) {
    $id = $model.Id
    $results = Get-BpaResult -ModelId "$id"
    foreach($res in $results) {
        if(!$res.Compliance) {
            Write-Output "Problem: $($res.Problem)"
            Write-Output "Resolution: $($res.Resolution)"
            Write-Output "Help Article: $($res.Help)"
            Write-Output ""
        }
    }
}