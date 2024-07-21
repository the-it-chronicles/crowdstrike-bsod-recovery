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

foreach ($drive in $drives) {
    $fullFilePath = Join-Path -Path $drive.Root -ChildPath $csvFilename
    
    # Check if the file exists
    if (Test-Path -Path $fullFilePath -PathType Leaf) {
        $csvPath = $fullFilePath
        break;
    }

}

# Use CSV file on the USB drive, if one exists, otherwise use the one embedded in WinPE
# This allows us to override the file with a new one if needed
if ($csvPath.Length -gt 0) {
    Write-Host "Using CSV file found at '$csvPath'"
} else {
    $csvPath = "$Env:SystemDrive\Windows\bitlocker_keys.csv"
    Write-Host "Using CSV file at '$csvPath'"
}

Write-Host ""
Write-Host "Press Enter to continue." -ForegroundColor Yellow
Read-Host

# Read the CSV file. The CSV file should have columns: Id, Key
$bitlockerData = Import-Csv -Path $csvPath

Write-Host ""
Write-Host "Found $($bitlockerData.Count + 0) BitLocker keys in CSV file."
Write-Host ""

# Get the BitLocker volumes
$bitlockerVolumes = Get-BitLockerVolume

# Find the volume that matches the BitLocker ID
foreach ($volume in $bitlockerVolumes) {
	
    if ($volume.ProtectionStatus -eq "Off") {
        Write-Host "Skipping volume '$($volume.MountPoint)' as BitLocker is '$($volume.ProtectionStatus)'"
        continue;
    }

    Write-Host "Trying to unlock volume $($volume.MountPoint)"

    # Loop through each entry in the CSV
    $found = $false
    foreach ($entry in $bitlockerData) {
    
        $bitlockerId = $entry.Id
        $recoveryKey = $entry.Key
	
        foreach ($keyProtector in $volume.KeyProtector) {

            if ($keyProtector.KeyProtectorType -eq "RecoveryPassword" -and $keyProtector.KeyProtectorId -eq "{$bitlockerId}") {
                Write-Host "Found matching BitLocker key. Unlocking volume $($volume.MountPoint)"
                $found = $true
                # Unlock the BitLocker protected drive using the recovery key
                Unlock-BitLocker -MountPoint $volume.MountPoint -RecoveryPassword $recoveryKey | Out-Null
		# TODO: We assume it unlocks, should add a check here.
                break
            }
        }
		
        if ($found -eq $true) {
            break
        }
    }
    
    if ($found -eq $false) {
        Write-Host "Failed to find BitLocker key for volume $($volume.MountPoint)" -ForegroundColor Red
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
