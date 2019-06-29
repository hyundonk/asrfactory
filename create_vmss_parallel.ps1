# create_vmss_parallel.ps1
# created by hyuk@microsoft.com
#

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)

$cred = Get-Credential

$VMs = Import-CSV $inputfile 

$counter = 0

Foreach ($VM in $VMs){
    $job = Start-Job -Name "$($VM.VMSS_NAME)-JOB" -ScriptBlock {
        $vmssname = $VM.VMSS_NAME
        Write-Host "[($counter) $vmssname] Creating ..."

        $vnet = Get-AzVirtualNetwork -Name $VM.TARGET_VNET_NAME -ResourceGroupName $VM.TARGET_VNET_RESOURCE_GROUP
        $subnet = Get-AzVirtualNetworkSubnetConfig -Name $VM.TARGET_SUBNET_NAME -VirtualNetwork $vnet

        $frontendIP_name = $VM.VMSS_NAME + "-lb-frontend"
        Write-Host "[($counter) $vmssname] New-AzLoadBalancerFrontendIpConfig ..."
        $frontendIP = New-AzLoadBalancerFrontendIpConfig -Name $frontendIP_name -PrivateIpAddress $VM.LOADBALANCER_IP -Subnet $subnet

        $backend_address_pool_name = $VM.VMSS_NAME + "-lb-backend-pool"
        Write-Host "[($counter) $vmssname] New-AzLoadBalancerBackendAddressPoolConfig ..."
        $backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name $backend_address_pool_name

        Write-Host "[($counter) $vmssname] New-AzLoadBalancerInboundNatPoolConfig ..."
        $inboundNATPool = New-AzLoadBalancerInboundNatPoolConfig `
        -Name "RDPRule" `
        -FrontendIpConfigurationId $frontendIP.Id `
        -Protocol TCP `
        -FrontendPortRangeStart 50001 `
        -FrontendPortRangeEnd 50010 `
        -BackendPort 3389

        $rg = Get-AzResourceGroup -Name $VM.TARGET_RESOURCE_GROUP
        Write-Host "[($counter) $vmssname] Creating Load Balancer ..."
        # Create the load balancer and health probe
        $lb = New-AzLoadBalancer `
        -ResourceGroupName $VM.TARGET_RESOURCE_GROUP `
        -Name $VM.VMSS_NAME `
        -Location $rg.Location `
        -FrontendIpConfiguration $frontendIP `
        -BackendAddressPool $backendPool `
        -InboundNatPool $inboundNATPool

        $lbprobename = $VM.VMSS_NAME + "-lb-probe"
        Add-AzLoadBalancerProbeConfig -Name $lbprobename `
        -LoadBalancer $lb `
        -Protocol TCP `
        -Port 80 `
        -IntervalInSeconds 5 `
        -ProbeCount 2

        $lbrulename = $VM.VMSS_NAME + "-lb-rule-default"

        Add-AzLoadBalancerRuleConfig `
        -Name $lbrulename `
        -LoadBalancer $lb `
        -FrontendIpConfiguration $lb.FrontendIpConfigurations[0] `
        -BackendAddressPool $lb.BackendAddressPools[0] `
        -Protocol TCP `
        -FrontendPort 80 `
        -BackendPort 80 `
        -Probe (Get-AzLoadBalancerProbeConfig -Name $lbprobename -LoadBalancer $lb)

        Set-AzLoadBalancer -LoadBalancer $lb

        # Create IP address configurations
        Write-Host "[($counter) $vmssname] New-AzVmssIpConfig ..."
        $ipConfig = New-AzVmssIpConfig `
        -Name "IPConfig" `
        -LoadBalancerBackendAddressPoolsId $lb.BackendAddressPools[0].Id `
        -LoadBalancerInboundNatPoolsId $inboundNATPool.Id `
        -SubnetId $subnet.Id

        # Create a configuration 
        $vmssConfig = New-AzVmssConfig `
            -Location $rg.Location `
            -SkuCapacity $VM.CAPACITY `
            -SkuName $VM.INSTANCE_SIZE `
            -UpgradePolicyMode "Manual"
    
        $imageVersion = Get-AzGalleryImageVersion -ResourceGroupName $VM.IMAGE_RESOURCE_GROUP -GalleryName $VM.IMAGE_GALLERY_NAME -GalleryImageDefinitionName $VM.VMSS_NAME -GalleryImageVersionName $VM.IMAGE_VERSION

        Write-Host "[($counter) $vmssname] Set-AzVmssStorageProfile ..."
        # Reference the image version
        Set-AzVmssStorageProfile $vmssConfig `
        -OsDiskCreateOption "FromImage" `
        -ImageReferenceId $imageVersion.Id

        $ComputerNamePrefix = $($VM.VMSS_NAME).Substring(6)

        Write-Host "[($counter) $ComputerNamePrefix] Set-AzVmssStorageProfile ..."
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
        -VirtualMachineScaleSet $vmssConfig

        Write-Host "($counter) [$vmssname] VMSS creation completed."
    }
    
    $counter++
    
    $jobs = $jobs + $job

    if(($counter % 10) -eq 0 ){
        Start-Sleep -s 10
    }
}

Get-Job | Wait-Job

Write-Host "Total $counter VMSS creation completed."
