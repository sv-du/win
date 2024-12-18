if(!(Test-Path .\tools\PersistenceSniper)) {
    mkdir .\tools\PersistenceSniper | Out-Null
    Invoke-WebRequest https://raw.githubusercontent.com/last-byte/PersistenceSniper/main/PersistenceSniper/PersistenceSniper.psd1 -OutFile .\tools\PersistenceSniper\PersistenceSniper.psd1
    Invoke-WebRequest https://raw.githubusercontent.com/last-byte/PersistenceSniper/main/PersistenceSniper/PersistenceSniper.psm1 -OutFile .\tools\PersistenceSniper\PersistenceSniper.psm1
}

Import-Module .\tools\PersistenceSniper\PersistenceSniper.psm1
Find-AllPersistence