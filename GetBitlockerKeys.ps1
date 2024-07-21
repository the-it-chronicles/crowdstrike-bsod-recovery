# Install the Microsoft Graph SDK
Install-Module Microsoft.Graph -Scope AllUsers

# Connect to MS Graph
Connect-MgGraph -Scopes BitLockerKey.Read.All

# Export Ids and Keys
Get-MgInformationProtectionBitlockerRecoveryKey -All | select Id,@{n="Key";e={(Get-MgInformationProtectionBitlockerRecoveryKey -BitlockerRecoveryKeyId $_.Id -Property key).key}} | Export-CSV -nti "bitlocker_keys.csv