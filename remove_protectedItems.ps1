# remove_protectedItems.ps1
# created by hyuk@microsoft.com
#

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

$RSV = Import-CSV $inputfile 

$resourcegroupname = $RSV.VAULT_RESOURCE_GROUP
$vaultname = $RSV.VAULT_NAME
$primaryfabricname = $RSV.PRIMARY_FABRIC_NAME
$primaryprotectioncontainername = $RSV.PRIMARY_PROTECTION_CONTAINER_NAME

Write-Host "Vault resource group:  $resourcegroupname"
Write-Host "Setting $vaultname as recovery services vault"
Write-Host "Fabric: $primaryfabricname" 
Write-Host "Protection container: $primaryprotectioncontainername"

$vault = Get-AzRecoveryServicesVault -ResourceGroupName $resourcegroupname -Name $vaultname
Set-AsrVaultSettings -Vault $vault

$PrimaryFabric = Get-AsrFabric -Name $primaryfabricname
$PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $primaryprotectioncontainername
$ReplicationProtectedItems = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $PrimaryProtContainer 

$counter = 0
Foreach ($ReplicationProtectedItem in $ReplicationProtectedItems){
    Write-Host "[$counter] Removing ... $($ReplicationProtectedItem.RecoveryAzureVMName)"
    Remove-AzRecoveryServicesAsrReplicationProtectedItem -ReplicationProtectedItem $ReplicationProtectedItem -Force
    $counter++
}

Write-Host "Total $counter protected items removed."
