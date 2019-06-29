# create_asrplan.ps1
# created by hyuk@microsoft.com
# Get replication protected items in "Protected" state and create ASR recovery plans each for "50" protected items.
# Note that "50" is "recommended" maximum number of protected items in a ASR recovery plan


Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

Write-Host "Reading Recovery Services Valut info from $inputfile ..."
$RSV = Import-CSV $inputfile 

$resourcegroupname = $RSV.VAULT_RESOURCE_GROUP
$vaultname = $RSV.VAULT_NAME
$primaryfabricname = $RSV.PRIMARY_FABRIC_NAME
$recoveryfabricname = $RSV.RECOVERY_FABRIC_NAME
$primaryprotectioncontainername = $RSV.PRIMARY_PROTECTION_CONTAINER_NAME

$recoveryplannameprefix = $RSV.RECOVERY_PLAN_NAME_PREFIX

Write-Host "Get Recovery Service Vault ..."

$vault = Get-AzRecoveryServicesVault -ResourceGroupName $resourcegroupname -Name $vaultname
Set-AsrVaultSettings -Vault $vault

$PrimaryFabric = Get-AsrFabric -Name $primaryfabricname
$PrimaryProtContainer = Get-ASRProtectionContainer -Fabric $PrimaryFabric -Name $primaryprotectioncontainername

Write-Host "Get Replication Protected Items ..."
$ReplicationProtectedItems = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $PrimaryProtContainer 

$RecoveryFabric = Get-AsrFabric -Name $recoveryfabricname

[Object[]]$protectedItems = @()

$planindex = 0
$count = 0
Foreach($ReplicationProtectedItem in $ReplicationProtectedItems){
    if($ReplicationProtectedItem.ProtectionState -eq "Protected"){
        Write-Host "[$planindex/$count] $($ReplicationProtectedItem.RecoveryAzureVMName),$($ReplicationProtectedItem.ProtectionState)"
        $protectedItems += $ReplicationProtectedItem
        $count++

        if($count -eq 50){
            Write-Host "put 50 items...."
            $RPName = $recoveryplannameprefix + $planindex
            New-AzRecoveryServicesAsrRecoveryPlan -Name $RPName -PrimaryFabric $PrimaryFabric -RecoveryFabric $RecoveryFabric -ReplicationProtectedItem $protectedItems
            #$protectedItems.Clear()
            $protectedItems = @() # initialize $protectedItems
   
            $planindex++
            $count = 0
        }
    }
}

if($protectedItems.Count -gt 0){
    Write-Host "put $($protectedItems.Count) items...."
    $RPName = $recoveryplannameprefix + $planindex
    New-AzRecoveryServicesAsrRecoveryPlan -Name $RPName -PrimaryFabric $PrimaryFabric -RecoveryFabric $RecoveryFabric -ReplicationProtectedItem $protectedItems
}

