function getTaskFiles([string]$path, [System.Collections.ArrayList]$list) {
    if(!$path) { $path = "C:\Windows\System32\Tasks" }
    if(!$list) { $list = [System.Collections.ArrayList]::new() }
    $files = Get-ChildItem -Path "$path"
    foreach($file in $files) {
        if(Test-Path -Path "$path\$file" -PathType Container) {
            getTaskFiles -path "$path\$file" -list $list
        } else {
            $list.Add("$path\$file".Replace("C:\Windows\System32\Tasks", "")) | Out-Null
        }
    }
    return $list
}

function getAllTasks() {
    $parsedTasks = [System.Collections.ArrayList]::new()
    $taskFiles = getTaskFiles
    $ErrorActionPreference = "SilentlyContinue"
    foreach($task in $taskFiles) {
        $regData = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$task"
        if(!$regData) {
            $parsedTasks.Add(@{
                taskFilePath = $task
                taskFileHash = (Get-FileHash -Algorithm SHA256 -Path "C:\Windows\System32\Tasks\$task").Hash
                taskId = "Not found"
                taskIndex = "Not found"
                taskSD = "Not found"
                taskRegSDDL = "Not found"
            }) | Out-Null
        } else {
            $parsedTasks.Add(@{
                taskFilePath = $task
                taskFileHash = (Get-FileHash -Algorithm SHA256 -Path "C:\Windows\System32\Tasks\$task").Hash
                taskId = $regData.Id
                taskIndex = $regData.Index
                taskSD = $regData.SD
                taskRegSDDL = (Get-Acl -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\$task").GetSecurityDescriptorSddlForm("all")
            }) | Out-Null
        }
    }
    $ErrorActionPreference = "Continue"
    return $parsedTasks
}

#$isCreatingBaseline = (Read-Host "Are you generating a task baseline? (y/n)").ToLower() -eq "y"

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
    $tasks = getAllTasks
    (ConvertTo-Json $tasks) > ".\baselines\tasks\$fileName"
    Write-Output "Baseline has been generated"
    exit
}

function Get-TaskAction($taskid) {
    $actions = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tasks\$taskid" -Name "Actions"
    if($actions) {
        return [System.Text.Encoding]::Unicode.GetString($actions)
    }
    return "No actions found"
}

$tasks = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\" -Recurse

$ErrorActionPreference = "SilentlyContinue"

foreach($task in $tasks) {
    $taskID = (Get-Item -Path "REGISTRY::\$task").GetValue("Id")
    if($null -eq $taskID) { continue } # If this item represents a task folder, not a task itself
    if($null -eq (Get-Item -Path "REGISTRY::\$task").GetValue("SD")) {
        Write-Output "Suspicious task found - Missing SD value"
        Write-Output "Task Registry Path: $task"
        Write-Output "Task Actions: $(Get-TaskAction($taskID))"
        Write-Output ""
    }
    if((Get-Item -Path "REGISTRY::\$task").GetValue("SD").Length -eq 0) {
        Write-Output "Suspicious task found - Zero Length SD Value"
        Write-Output "Task Registry Path: $task"
        Write-Output "Task Actions: $(Get-TaskAction($taskID))"
        Write-Output ""
    }
    $SecDescBin = (Get-Item -Path "REGISTRY::\$task").GetValue("SD")
    $SecDesc = ([WMIClass]"Win32_SecurityDescriptorHelper").BinarySDToWin32SD($SecDescBin).Descriptor
    if(($SecDesc.Owner.Length -eq 0) -and ($SecDesc.Group.Length -eq 0)) {
        Write-Output "Suspicious task found - Invalid SDDL data in SD value"
        Write-Output "Task Registry Path: $task"
        Write-Output "Task Actions: $(Get-TaskAction($taskID))"
        Write-Output ""
    } elseif($SecDesc.DACL.Trustee.Name -notcontains "SYSTEM") {
        Write-Output "Suspicious task found - SYSTEM not listed in DACL"
        Write-Output "Task Registry Path: $task"
        Write-Output "Task Actions: $(Get-TaskAction($taskID))"
        Write-Output ""
    }
    $SecDesc.DACL | ForEach-Object {
        if((($_.Trustee.Name -eq "SYSTEM") -or ($_.Trustee.Name -eq "Administrators") ) -and ($_.AceType -eq 1)) {
            Write-Output "Suspicious task found - SYSTEM or Administrators explicity denied in DACL"
            Write-Output "Task Registry Path: $task"
            Write-Output "Task Actions: $(Get-TaskAction($taskID))"
            Write-Output ""
        }
    }
    if((Get-Item -Path "REGISTRY::\$task").GetValue("Index") -eq 0) {
        Write-Output "Suspicious task found - Task Index = 0"
        Write-Output "Task Registry Path: $task"
        Write-Output "Task Actions: $(Get-TaskAction($taskID))"
        Write-Output ""
    }
}

$ErrorActionPreference = "Continue"