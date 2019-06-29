# create_vms_from_vmss.ps1
# created by hyuk@microsoft.com
# This powershell script does below for each VM Scale Set
# 1) Creat snapshot from the 1st instance of the VM Scale Set
# 2) Create managed disk from the snapshot
# 3) Create VM from the managed disk

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

$VMs = Import-CSV inputfile

Write-Host "VM Creation Jobs are starting ..."
#$creds = Get-Credential

$jobs = @()
Foreach ($VM in $VMs) {
    $job = Start-Job -Name "$($VM.VMSS_NAME)-JOB" -ScriptBlock {
        param($vmssName, $sourceRG, $targetVNET, $destRG, $ctx) #, $vmadmin)

        Write-Host "##### VMSS Resource group $($sourceRG), vmss name: $($vmssName) "

        $vmss = Get-AzVmssVM -AzureRmContext $ctx -ResourceGroupName $sourceRG -VMScaleSetName $vmssName
        if ($null -ne $vmss) {
            Write-Host "Starting Create VM  instructions for item '$($vmssName)'"
    
            $rg = Get-AzResourceGroup -Name $sourceRG
    
            #snapshot configuration
            Write-Host "Entering snapshot process"
            $snapshotconfig = New-AzSnapshotConfig `
                -Location $rg.Location `
                -AccountType Standard_LRS `
                -OsType Windows `
                -SourceUri $vmss.StorageProfile.OsDisk.ManagedDisk.id[0] `
                -CreateOption Copy
            if ($null -eq $snapshotconfig) {
                Write-Host "New-AzSnapshotConfig failed exit..."
                exit 0
            }
    
            #Create a snapshot
            $snapshotname= ($vmssName +'-vmss-snapshot')
            $snapshot = New-AzSnapshot -ResourceGroupName $destRG `
                -SnapshotName $snapshotname `
                -Snapshot $snapshotconfig
            if ($null -eq $snapshot) {
                Write-Host "New-AzSnapshot failed exit..."
                exit 0
            }
    
            # Create a Managed Disk from the snapshot
            Write-Host "Entering managed disk process"
            #disk configuration
            $diskConfig = New-AzDiskConfig -AccountType Standard_LRS -Location $rg.Location -CreateOption Copy -SourceResourceId $snapshot.Id
            if ($null -eq $diskConfig) {
                Write-Host "New-AzDiskConfig failed exit..."
                exit 0
            }
    
            #disk creation
            $osDisk = New-AzDisk -ResourceGroupName $destRG -Disk $diskConfig -DiskName ($snapshotName+'_Disk')
            Write-Host "Finished managed disk process"
            if ($null -eq $osDisk) {
                Write-Host "New-AzDisk failed exit..."
                exit 0
            }
    
            $vnet = Get-AzVirtualNetwork -Name $targetVNET -ResourceGroupName $destRG
            if ($null -eq $vnet) {
                Write-Host "Get-AzVirtualNetwork failed exit..."
                exit 0
            }
    
            $vmname = ($vmssName+'-factory-vm')
            
            $nic = New-AzNetworkInterface -force -Name ($vmname.ToLower()+'_nic') -ResourceGroupName $destRG -Location $rg.Location `
            -SubnetId $vnet.Subnets[0].Id # -PublicIpAddressId $publicIp.Id
            if ($null -eq $nic) {
                Write-Host "New-AzNetworkInterface failed exit..."
                exit 0
            }
    
            Write-Host "vm configuration process.."
            $virtualMachineSize = 'Standard_D2_v3' # VM will be created to get VM Image resource. Doesn't need to use bigger VM size to create VM image.
            $VirtualMachine = New-AzVMConfig -VMName $vmname -VMSize $virtualMachineSize
            $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $osDisk.Id -CreateOption Attach -windows
            $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
    
            Write-Host "Creating VM..."
            New-AzVM -VM $VirtualMachine -ResourceGroupName $destRG -Location $rg.Location
                
            Write-Host "Will create VM '$($vmname)' from '$($vmssName)'  in '$($rg.Location)' "
            Get-Date
        }
    } -ArgumentList $VM.VMSS_NAME, $VM.VMSS_RESOURCE_GROUP, $VM.FACTORY_VNET, $VM.FACTORY_RESOURCE_GROUP , (Get-AzContext)
    $jobs = $jobs + $job
}

Get-Job | Wait-Job
Write-Host "All jobs completed"
