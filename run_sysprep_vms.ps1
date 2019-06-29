# run_sysprep_vms.ps1
# created by hyuk@microsoft.com
# This is to sysprep Azure VMs using Azure VM "Run command" extension.
# Use below line as "Run Command" ("./run_command_sysprep.ps1" contains below line)
# c:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown
# However, this script failed in VMs with old OS (Windows Server 2008 R2). In such cases, run sysprep directly on the VMs.


Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

$VMs = Import-CSV inputfile

Foreach ($VM in $VMs){
    $vmssName = $VM.VMSS_NAME
    $destRG = $VM.FACTORY_RESOURCE_GROUP

    Write-Host "Calling Invoke-AzVMRunCommand sysprep ..."

    $vmname = ($vmssname+'-factory-vm')
    Invoke-AzVMRunCommand -ResourceGroupName $destRG -Name $vmname -CommandId 'RunPowerShellScript' -ScriptPath './run_command_sysprep.ps1'

    Write-Host "Invoke-AzVMRunCommand sysprep Completed"
    Start-Sleep -Second 1
}
