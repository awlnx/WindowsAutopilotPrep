. .\sources.ps1 
Try {
    Write-Host "Created Scratch Directories..."
    $Iso = Get-ChildItem -path .\windows -Filter "*.iso"
    $WorkingDirectory = "$env:TEMP\custimg"
    $WindowsFiles = "$env:TEMP\custimg\WindowsFiles"
    $MountedImage = "$env:TEMP\custimg\MountedImage"
    $MountedBoot = "$env:TEMP\custimg\MountedBoot"
    $MountedWimRe = "$env:TEMP\custimg\MountedWimRe"
    Write-Host "Getting Autopilot Profiles..."
    Connect-msgraph
    $Profiles = Get-AutopilotProfile
    $NoProfile = $Profiles[0]
    $NoProfile.PSObject.Properties |ForEach-Object {$_.value = "No Profile"}
    $SelectedProfile = (Get-AutopilotProfile) + $NoProfile |Out-GridView -PassThru
    if ($Iso -is [array]) {
        $Selection = Get-UserSelectionForArray -HelpMessage "Please select which Windows Iso you want to use" -Array $Iso -Property "Name"
        $Iso = $Iso[$Selection]
    }
    $WorkingDirectory,$MountedImage,$MountedBoot,$MountedWimRe |ForEach-Object {
        New-Item -ItemType Directory -Path $_ -Force
    }
    $DiskImage = Mount-DiskImage -ImagePath $Iso.FullName  
    $Volume= ($DiskImage |Get-Volume)
    $Path = $Volume.DriveLetter + ":\"
    Write-Host "Copying Files..." 
    $null = Robocopy.exe  /MT /MIR $Path "$WindowsFiles\" 
    (Get-Item "$WindowsFiles\sources\boot.wim").IsReadOnly = $False
    (Get-Item "$WindowsFiles\sources\install.wim").IsReadOnly = $False
    Write-Host "Removing Extra Images..."
    Get-WindowsImage -ImagePath "$WindowsFiles\sources\install.wim" |Where-Object {$_.ImageName -ne "Windows 10 Pro"}|ForEach-Object {
        $null = Remove-WindowsImage -Name $_.ImageName  -ImagePath  "$WindowsFiles\sources\install.wim" 
    }
    Write-Host "Mounting Images..." 
    Mount-WindowsImage -ImagePath "$WindowsFiles\sources\boot.wim" -Path $MountedBoot -Index 2
    Mount-WindowsImage -ImagePath "$WindowsFiles\sources\install.wim" -Path $MountedImage -Index 1 
    Mount-WindowsImage -ImagePath "$MountedImage\windows\system32\Recovery\Winre.wim" -Path $MountedWimRe -Index 1 
    Write-Host "Adding Drivers..."
    $null = Add-WindowsDriver -Driver .\drivers -Recurse  -Path "$MountedBoot"
    $null = Add-WindowsDriver -Driver .\drivers -Recurse  -Path "$MountedImage"
    $null = Add-WindowsDriver -Driver .\drivers -Recurse  -Path "$MountedWimRe" 
    if ($SelectedProfile.displayName -ne "No Profile") {
    Write-Host "Copying Autopilot Profile..."
    $SelectedProfile |ConvertTo-AutopilotConfigurationJSON|Out-File -Encoding ascii "$MountedImage\Windows\Provisioning\Autopilot\AutopilotConfigurationFile.json"
    }
    Write-Host "Dismounted Images..."
    $null = Dismount-WindowsImage -Path $MountedWimRe -Save
    $null = Dismount-WindowsImage -Path $MountedImage -Save
    $null = Dismount-WindowsImage -Path $MountedBoot -Save
    Write-Host "Creating ISO"
    New-Item -Path -ItemType Directory ".\completedImage"
    New-IsoFile -Path .\completedImage\windows.iso -Source (Get-ChildItem $WorkingDirectory).FullName -BootFile "$WindowsFiles/boot/boot.sdi"
    Dismount-DiskImage -ImagePath $Iso.FullName 
   
}
Catch { 
    Write-Error $_
    Get-WindowsImage -Mounted |Where-Object {$_.Path} -match "custimg"|ForEach-Object {
        Dismount-WindowsImage -path $_.Path -Discard
         Remove-Item -Path $WorkingDirectory -Force -Recurse
         Dismount-DiskImage -ImagePath $Iso.FullName 
    }
}
