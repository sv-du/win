$folders = Get-ChildItem -Path "C:\Users"

foreach($folder in $folders) {
    $name = $folder.Name
    ((net.exe user "$name") 2>&1) > err.txt
    $err = (Get-Content .\err.txt)
    if($err.Contains("net.exe : The user name could not be found.")) { # If the account doesn't exist
        Write-Output "Deleting Directory: C:\Users\$name"
        Remove-Item -Path "C:\Users\$name" -Recurse -Force
    }
}

Remove-Item .\err.txt