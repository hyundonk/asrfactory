# cleanup_testfailover.ps1
# created by hyuk@microsoft.com
# This script was used for deleting test failovers that were were hanging at "initiating" state
# search for replication protected item in "Initiating" state and clean it up each

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

Write-Host "Reading Recovery Services Valut info from $inputfile ..."
$RSV = Import-CSV $inputfile 

$resourcegroupname = $RSV.VAULT_RESOURCE_GROUP
$vaultname = $RSV.VAULT_NAME
$primaryfabricname = $RSV.PRIMARY_FABRIC_NAME
$primaryprotectioncontainername = $RSV.PRIMARY_PROTECTION_CONTAINER_NAME

Write-Host "Vault resource group:  $resourcegroupname"
Write-Host "Fabric: $primaryfabricname" 
Write-Host "Protection container: $primaryprotectioncontainername"

Write-Host "Setting $vaultname as recovery services vault"

$vault = Get-AzRecoveryServicesVault -ResourceGroupName $resourcegroupname -Name $vaultname
Set-AsrVaultSettings -Vault $vault

$PrimaryFabric = Get-AsrFabric -Name $primaryfabricname
$PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $primaryprotectioncontainername

$ReplicationProtectedItems = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $PrimaryProtContainer 
$counter = 0

Foreach($ReplicationProtectedItem in $ReplicationProtectedItems){
    if($ReplicationProtectedItem.TestFailoverState -eq "Initiating"){
        Write-Host "[($counter) $ReplicationProtectedItem.RecoveryAzureVMName] Cleanup TestFailover ..."
        Start-AzRecoveryServicesAsrTestFailoverCleanupJob -ReplicationProtectedItem $ReplicationProtectedItem -Comments "testing done"
        #Start-ASRTestFailoverCleanupJob -ReplicationProtectedItem $ReplicationProtectedItem
        $counter++
    }
}
