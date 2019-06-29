# createimage_n_upload.ps1
# created by hyuk@microsoft.com
# input cvs file has list of "sysprep"ed VMs. Use this powershell script For each "sysprep"ed VM to generalized create image, and upload it to Shared Image Gallery as Image definition


Param (
    [Parameter(Mandatory=$true)]
    $inputfile,
    [Parameter(Mandatory=$true)]
    $version
)

$VMs = Import-CSV $inputfile 

$counter = 0
Foreach ($VM in $VMs){

    $rg = Get-AzResourceGroup -Name $VM.FACTORY_RESOURCE_GROUP
    $vmname = ($VM.VMSS_NAME +'-factory-vm')

    Write-Host "[$vmname] Stopping ..."
    Stop-AzVM  -ResourceGroupName $VM.FACTORY_RESOURCE_GROUP  -Name $vmname -Force

    Write-Host "[$vmname] Generalizing ..."
    Set-AzVM  -ResourceGroupName $VM.FACTORY_RESOURCE_GROUP  -Name $vmname -Generalized


    $vmObj = Get-AzVM -Name $vmname -ResourceGroupName $VM.FACTORY_RESOURCE_GROUP

    # Create the VM image configuration based on the source VM
    $image = New-AzImageConfig -Location $rg.Location -SourceVirtualMachineId $vmObj.ID 

    Write-Host "[$vmname] Create Azure Image ..."
    $myImage = New-AzImage -Image $image -ImageName $VM.VMSS_NAME -ResourceGroupName $VM.FACTORY_RESOURCE_GROUP

    $gallery = Get-AzGallery -GalleryName $VM.IMAGE_GALLERY_NAME -ResourceGroupName $VM.IMAGE_RESOURCE_GROUP

    $image_id = $myImage.Id
    $region1 = @{Name='Korea Central';ReplicaCount=1}
    $region2 = @{Name='Korea South';ReplicaCount=1}
    $targetRegions = @($region1,$region2)
    Write-Host "[$vmname] Creating Image Definition in the Image Gallery ..."
    New-AzGalleryImageVersion -GalleryImageDefinitionName $VM.VMSS_NAME -GalleryImageVersionName $version -GalleryName $gallery.Name -ResourceGroupName $VM.IMAGE_RESOURCE_GROUP -Location $gallery.Location  -TargetRegion $targetRegions  -Source $image_id -asJob 
    Write-Host "[$vmname] Creating Image Definition in the Image Gallery completed."
    $counter++
}

Write-Host "Total $counter Image Definition creation completed."
