# create_terraform_modules_imagedefinition.ps1
# created by hyuk@microsoft.com
# This powershell script is used for generating terraform module files from input csv file.
# The terraform modules will be used to deploy VM Scale Set for each services using terraform

<# Sample module created in outputfile 
module "myservice1" {
    source = "./modules/shared_image"
    resourcegroup_name = "my-images"
    image_gallery_name = "my_image_gallery"
    image_name = "myservice1"
    sku = "mysku"
    publisher = "mypublisher"
}
#>

Param (
    [Parameter(Mandatory=$true)]
    $publishername,
    [Parameter(Mandatory=$true)]
    $skuname,
    [Parameter(Mandatory=$true)]
    $inputfile,
    [Parameter(Mandatory=$true)]
    $outputfile
)

$VMs = Import-CSV $inputfile 
"# Modules for image definitions" | Add-Content $outputfile

"# This file is auto-created by create_image_definitions.ps1" | Add-Content $outputfile
"# New-AzGalleryImageDefinition call takes several tens of seconds." | Add-Content $outputfile
"# Use terraform instead of New-AzGalleryImageDefinition to create tens of or hundreds of image definitions" | Add-Content $outputfile
Write-Host "Create terraform template for Image Definition modules"

$counter = 0
Foreach ($VM in $VMs){
    "module ""$($VM.VMSS_NAME)"" {" | Add-Content $outputfile
    "	source = ""./modules/shared_image""" | Add-Content $outputfile
    "	resourcegroup_name = ""$($VM.IMAGE_RESOURCE_GROUP)""" | Add-Content $outputfile
    "	image_gallery_name = ""$($VM.IMAGE_GALLERY_NAME)""" | Add-Content $outputfile
    "	image_name = ""$($VM.VMSS_NAME)""" | Add-Content $outputfile
    "	sku = ""$($VM.IMAGE_SKU)""" | Add-Content $outputfile
    "	publisher = ""$($VM.IMAGE_PUBLISHER)""" | Add-Content $outputfile
   
    "}" | Add-Content $outputfile
    
<# Also below powershell can be used to create Image definitions imperative way. However, using declarative way using terraform is much faster to create large number of image definitions.
    $rg = Get-AzResourceGroup -Name $VM.IMAGE_RESOURCE_GROUP
    $galleryImage = New-AzGalleryImageDefinition -GalleryName $VM.IMAGE_GALLERY_NAME `
    -ResourceGroupName $VM.IMAGE_RESOURCE_GROUP  `
    -Location $rg.Location  `
    -Name $VM.VMSS_NAME `
    -OsState generalized -OsType Windows `
    -Publisher $publishername -Offer $VM.VMSS_NAME -Sku $skuname
    Write-Host "Image Definition for $VM.VMSS_NAME created."
    if ($null -eq $galleryImage) {
        Write-Host -ForegroundColor Yellow "New-AzGalleryImageDefinition failed..."
        exit 0
    }
    $counter++
#>
}

Write-Host "$counter Image Definition creation completed."
