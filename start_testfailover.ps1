# start_testfailover.ps1
# created by hyuk@microsoft.com
# Start Test Failover job on multiple Recovery Plans. Each plan name is $RPNAMEPREFIX + $idx
# In this example, there are 18 DPs with $RPNAMEPREFIX + $idx name each

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

$start = Get-Date


Write-Host "Reading Recovery Services Valut info from $inputfile ..."
$RSV = Import-CSV $inputfile 

$resourcegroupname = $RSV.VAULT_RESOURCE_GROUP
$vaultname = $RSV.VAULT_NAME
$vnetresourcegroupname = $RSV.TARGET_VNET_RESOURCE_GROUP
$vnetname = $RSV.TARGET_VNET_NAME

$recoveryplannameprefix = $RSV.RECOVERY_PLAN_NAME_PREFIX

Write-Host "Vault resource group:  $resourcegroupname"
Write-Host "Setting $vaultname as recovery services vault"
Write-Host "VNET resource group: $vnetresourcegroupname" 
Write-Host "VNET name: $vnetname"


$vault = Get-AzRecoveryServicesVault -ResourceGroupName $resourcegroupname -Name $vaultname
Set-AsrVaultSettings -Vault $vault

$idx = 0
while($idx -lt 18){
    $RPName = $recoveryplannameprefix + $idx
    $RP = Get-AzRecoveryServicesAsrRecoveryPlan -Name $RPName

    $Networks = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $vnetresourcegroupname 

    Write-Host "Starting Test fail-over on Recovery Plan [$RPName] ..."
    Start-AzRecoveryServicesAsrTestFailoverJob -RecoveryPlan $RP -Direction PrimaryToRecovery -AzureVMNetworkId $Networks.ID

    $idx++
}

$end = Get-Date

Write-Host "Start Time: $start"
Write-Host "End Time: $end"
