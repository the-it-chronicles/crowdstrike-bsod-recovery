Clear-Host

Write-Host ""
Write-Host "CrowdStrike July 2024 BSOD Fix" -ForegroundColor Blue
Write-Host "Author: Anthony Myatt" -ForegroundColor Blue
Write-Host "Created: 20/07/2024" -ForegroundColor Blue
Write-Host ""

$csvFilename = "bitlocker_keys.csv"
$csvPath = ""

# Get a list of all drives
$drives = Get-PSDrive -PSProvider FileSystem

# Find which drive contains the CSV file
foreach ($drive in $drives) {
    $fullFilePath = Join-Path -Path $drive.Root -ChildPath $csvFilename
    
    # Check if the file exists
    if (Test-Path -Path $fullFilePath -PathType Leaf) {
        $csvPath = $fullFilePath
        break;
    }

}

# Let the user know which drive was picked, or report if the file could not be found.
if ($csvPath.Length -gt 0) {
    Write-Host "Using CSV file found at '$csvPath'"
} else {
    $csvPath = "$Env:SystemDrive\Windows\bitlocker_keys.csv"
	Write-Host "Could not find CSV file '$csvFilename'. Please place this file in the root of the USB drive." -ForegroundColor Red
    Write-Host "This script will continue, however you will need to manually enter the BitLocker key." -ForegroundColor Red
}

# Read the CSV file. The CSV file should have columns: Id, Key
$bitlockerData = Import-Csv -Path $csvPath

Write-Host ""
Write-Host "Found $($bitlockerData.Count + 0) BitLocker keys in CSV file."
Write-Host ""

# On some machines the internal System Drive does not have a drive letter when booted from WinPE
# We therefore check for this and assign a letter
$letters = @("Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z")
$i = 0
$partitions = Get-Partition
foreach ($part in $partitions) {
    if ($part.Type -notin @("System", "Reserved", "Recovery") -and [bool]$part.DriveLetter -eq $false) {
        Write-Host "Partition $($part.PartitionNumber) on disk $($part.DiskNumber) has no letter, assigning '$($letters[$i]):\'"
        Set-Partition -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -NewDriveLetter $letters[$i]
        $i++
    }
}

# Get the BitLocker encrypted volumes
$bitlockerVolumes = Get-BitLockerVolume

# Iterate through the volumes
foreach ($volume in $bitlockerVolumes) {
    
    # If the volume has BitLocker off, we skip it
    if ($volume.ProtectionStatus -eq "Off") {
        Write-Host "Skipping volume '$($volume.MountPoint)' as BitLocker is '$($volume.ProtectionStatus)'"
        continue;
    }

    Write-Host "Trying to unlock volume $($volume.MountPoint)"

    $found = $false
    # Loop through each entry in the CSV
    foreach ($entry in $bitlockerData) {
        
        $bitlockerId = $entry.Id
        $recoveryKey = $entry.Key
        
        # Each volume may have one or more KeyProtectors (i.e. Tpm and RecoveryPassword)
        foreach ($keyProtector in $volume.KeyProtector) {

            # If the KeyProtector is of type RecoveryPassword and matches the CSV file entry, we try to unlock the volume
            if ($keyProtector.KeyProtectorType -eq "RecoveryPassword" -and $keyProtector.KeyProtectorId -eq "{$bitlockerId}") {
                Write-Host "Found matching BitLocker key. Attempting to unlock volume $($volume.MountPoint)"
                $found = $true
                # Unlock the BitLocker protected drive using the recovery key
                $vol = Unlock-BitLocker -MountPoint $volume.MountPoint -RecoveryPassword $recoveryKey
                if ($vol.LockStatus -eq "Unlocked") {
                    Write-Host "Volume '$($volume.MountPoint)' successfuly unlocked." -ForegroundColor Green
                    break
                } else {
                    Write-Host "Volume '$($volume.MountPoint)' failed to unlock!" -ForegroundColor Red
                }
            }
        }
        
        if ($found -eq $true) {
            break
        }
    }
    
    if ($found -eq $false) {
        Write-Host "Failed to find BitLocker key for volume $($volume.MountPoint)" -ForegroundColor Red
		$key = $volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } | Select-Object -Property KeyProtectorId
		Write-Host "BitLocker ID is '$key'"
		$recoveryKey = Read-Host -Prompt "Manually enter BitLocker Key: "
        if ($recoveryKey.Length -eq 0) {
            Write-Host "No key provided. Press Enter to shutdown."
            Wpeutil Shutdown
        } else {
            $vol = Unlock-BitLocker -MountPoint $volume.MountPoint -RecoveryPassword $recoveryKey
            if ($vol.LockStatus -eq "Unlocked") {
                Write-Host "Volume '$($volume.MountPoint)' successfuly unlocked." -ForegroundColor Green
            } else {
                Write-Host "Volume '$($volume.MountPoint)' failed to unlock!" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "Getting list of drives"

# Get a list of all drives
$drives = Get-PSDrive -PSProvider FileSystem

Write-Host "Found $($drives.Count + 0) drives"
Write-Host ""

# Define the folder to check for and the file pattern to delete
$folderPath = "\Windows\System32\drivers\Crowdstrike"
$filePattern = "C-00000291*.sys"

foreach ($drive in $drives) {
    $fullFolderPath = Join-Path -Path $drive.Root -ChildPath $folderPath
    
    # Check if the folder exists
    if (Test-Path -Path $fullFolderPath) {
        Write-Host "Drive $($drive.Root) contains the CrowdStrike driver folder."
        # Get the files matching the pattern
        $filesToDelete = Get-ChildItem -Path $fullFolderPath -Filter $filePattern

        Write-Host "Attempting to delete files C-00000291*.sys in '$fullFolderPath'"
        # Delete the files
        foreach ($file in $filesToDelete) {
            if ($file.FullName.Length -gt 0) {
                Write-Host "Deleting file '$($file.FullName)'"
                Remove-Item -Path $file.FullName -Force
            }
        }
    }
}

Write-Host ""
Write-Host "Complete!"
Write-Host ""
Write-Host "Press Enter to continue" -ForegroundColor Yellow
Read-Host
Wpeutil Reboot