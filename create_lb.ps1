# create_lb.ps1
# created by hyuk@microsoft.com
# PowerShell script to create Azure Basic Load Balancers at Disater Recovery Region

Param (
    [Parameter(Mandatory=$true)]
    $inputfile
)
Get-Date
$VMs = Import-CSV $inputfile 

$counter = 0

Foreach ($VM in $VMs){
    
    $vmssname = $VM.VMSS_NAME
    Write-Host "[($counter) $vmssname] Azure Load Balancer Creating ..."

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

    $lbname = $vmssname + "-lb"

    # Create the load balancer and health probe
    $lb = New-AzLoadBalancer `
    -ResourceGroupName $VM.TARGET_RESOURCE_GROUP `
    -Name $lbname `
    -Location $rg.Location `
    -FrontendIpConfiguration $frontendIP `
    -BackendAddressPool $backendPool `
    -InboundNatPool $inboundNATPool

    $lbprobename = $lbname + "-probe"
    Add-AzLoadBalancerProbeConfig -Name $lbprobename `
    -LoadBalancer $lb `
    -Protocol TCP `
    -Port 80 `
    -IntervalInSeconds 5 `
    -ProbeCount 2

    $lbrulename = $lbname + "-rule-default"

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

    Write-Host "($counter) Load Balancer creation for [$vmssname] completed."
    $counter++
}

Write-Host "Total $counter Azure Load Balancer(s) creation completed."
Get-Date
