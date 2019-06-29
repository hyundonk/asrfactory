
Param (
    [Parameter(Mandatory=$true)]
    $rgname,
    [Parameter(Mandatory=$true)]
    $vmname,
    [Parameter(Mandatory=$true)]
    $Username,
    [Parameter(Mandatory=$true)]
    $Password
)

$vm = Get-AzVM -ResourceGroupName $rgname -Name $vmname
$nic = Get-AzNetworkInterface -ResourceGroupName $rgname  -Name $(Split-Path -Leaf $vm.NetworkProfile.NetworkInterfaces[0].Id)
$privateip = (Get-AzNetworkInterface -Name $nic.Name -ResourceGroupName $rgname).IpConfigurations.PrivateIpAddress

<#
#get the public ip address of the Azure VM
$nic = $vm.NetworkProfile.NetworkInterfaces[0].Id.Split('/') | select -Last 1
$publicIpName =  (Get-AzNetworkInterface -ResourceGroupName $rgname -Name $nic).IpConfigurations.PublicIpAddress.Id.Split('/') | select -Last 1
$publicIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $rgname -Name $publicIpName).IpAddress

Write-Output $vmName IP: $publicIpAddress
#>

#sysprep
$Connection = Test-Connection $privateip -Count 1 -Quiet
    if($Connection -eq $false) { 
        Write-Host -ForegroundColor Yellow " $privateip skip. (Ping-Connection failed)"
        exit 
    }

try {
<#
        $CimOption = New-CimSessionOption -Protocol Dcom
        $CimSession = New-CimSession -ComputerName $ComputerName -SessionOption $CimOption
        if ($CimSession -eq $null) { 
            LOG "$_ skip. (CimSession is null)"
            return
        }
#>
        # non-blockking process
        .\PsExec.exe -accepteula \\$privateip -u $Username -p $Password -d cmd /c "c:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown"
        Write-Host -ForegroundColor Yellow " $privateip executed."
} catch {
        $e = $_.Exception
        $msg = $e.Message

        Write-Host -ForegroundColor Yellow "$privateip skip. $msg" 
}

Write-Host "finished sysprep process.."

exit 