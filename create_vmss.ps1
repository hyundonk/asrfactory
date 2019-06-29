# create_vmss.ps1
# created by hyuk@microsoft.com
# Script to create multiple (hundreds) VM scale sets in a row from image versions in Azure Image Gallary.
# This is to test DR scenario. Load Balancers for each VM Scale Set must have been created in advance to make RTO short.

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

$cred = Get-Credential
$start = Get-Date

$VMs = Import-CSV $inputfile 

$counter = 0

Foreach ($VM in $VMs){
    $vmssname = $VM.VMSS_NAME
    Write-Host "[($counter) $vmssname] VMSS Creating ..."

    $lbname = $vmssname + "-lb"
    $lb = Get-AzLoadBalancer -ResourceGroupName $VM.TARGET_RESOURCE_GROUP -Name $lbname

    # Create IP address configurations
    $ipConfig = New-AzVmssIpConfig `
    -Name "IPConfig" `
    -LoadBalancerBackendAddressPoolsId $lb.BackendAddressPools[0].Id `
    -LoadBalancerInboundNatPoolsId $lb.InboundNatPools[0].Id `
    -SubnetId $lb.FrontendIpConfigurations.Subnet.Id

    # Create a configuration 
    $vmssConfig = New-AzVmssConfig `
        -Location "koreasouth" `
        -SkuCapacity $VM.CAPACITY `
        -SkuName $VM.INSTANCE_SIZE `
        -UpgradePolicyMode "Manual"
 
    $imageVersion = Get-AzGalleryImageVersion -ResourceGroupName $VM.IMAGE_RESOURCE_GROUP -GalleryName $VM.IMAGE_GALLERY_NAME -GalleryImageDefinitionName $VM.VMSS_NAME -GalleryImageVersionName $VM.IMAGE_VERSION

    # Reference the image version
    Set-AzVmssStorageProfile $vmssConfig `
    -OsDiskCreateOption "FromImage" `
    -ImageReferenceId $imageVersion.Id

    $ComputerNamePrefix = $VM.VMSS_NAME
    if($ComputerNamePrefix.length -gt 6){
        $ComputerNamePrefix = $ComputerNamePrefix.Substring(0, 6)
    }

    # Complete the configuration
    Set-AzVmssOsProfile $vmssConfig `
    -AdminUsername $cred.UserName `
    -AdminPassword $cred.Password `
    -ComputerNamePrefix $ComputerNamePrefix -WindowsConfigurationProvisionVMAgent $true

    Add-AzVmssNetworkInterfaceConfiguration `
    -VirtualMachineScaleSet $vmssConfig `
    -Name "network-config" `
    -Primary $true `
    -IPConfiguration $ipConfig -EnableAcceleratedNetworking

    Write-Host "($counter) [$vmssname] New-AzVmss ..."
    # Create the scale set 
    New-AzVmss `
    -ResourceGroupName $VM.TARGET_RESOURCE_GROUP `
    -Name $VM.VMSS_NAME `
    -VirtualMachineScaleSet $vmssConfig -AsJob

    Write-Host "($counter) [$vmssname] VMSS creation completed."
    $counter++
}
$end = Get-Date
Write-Host "Total $counter VMSS creation completed."
Write-Host "Start Time: $start"
Write-Host "End Time: $end"
