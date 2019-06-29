# create_terraform_modules_vmss.ps1
# created by hyuk@microsoft.com
# This powershell script is used for generating terraform module files from input csv file.
# The terraform modules will be used to deploy VM Scale Set for each services using terraform

<# Sample module created in outputfile 
module "myservicename" {
    source = "../services/createvmss"
	servicename = "myservicename"
    location = "${var.location}"
    resourcegroup_name = "${var.service_resourcegroup_name}"
    subnet_id = module.network.subnet_mysubnet
    loadbalancer_ip = "xxx.xxx.xxx.xxx"
    instance_size = "Standard_F8s"
    instance_num = 5
    provision_vm_agent = true
	image_id = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myresourcegroup/providers/Microsoft.Compute/galleries/mysharedimagegallery/images/myservicename/versions/1.0.0"
}
#>

Param (
    [Parameter(Mandatory=$true)]
    $inputfile,
    [Parameter(Mandatory=$true)]
    $outputfile
)

$VMs = Import-CSV $inputfile 
"# Modules for image definitions" | Add-Content $outputfile

"# This file is auto-created by terraform_vmss_modules.ps1" | Add-Content $outputfile
"" | Add-Content $outputfile
"" | Add-Content $outputfile

Write-Host "Create terraform template for VMSS modules definition"

$counter = 0
Foreach ($VM in $VMs){
    $image_id = "/subscriptions/" + $VM.SUBSCRIPTION_ID + "/resourceGroups/" + $VM.IMAGE_RESOURCE_GROUP + "/providers/Microsoft.Compute/galleries/" + $VM.IMAGE_GALLERY_NAME + "/images/" + $VM.VMSS_NAME + "/versions/" + $VM.IMAGE_VERSION 
    $subnet_id = "module.network." + $VM.SUBNET_ID

    "module ""$($VM.VMSS_NAME)"" {" | Add-Content $outputfile
    "	source = ""../services/createvmss""" | Add-Content $outputfile
    "	servicename = ""$($VM.VMSS_NAME)""" | Add-Content $outputfile
    "   location = ""`${var.location}""" | Add-Content $outputfile
    "   resourcegroup_name = ""`${var.service_resourcegroup_name}""" | Add-Content $outputfile
    "   subnet_id = $subnet_id" | Add-Content $outputfile
 
    "   loadbalancer_ip = ""$($VM.LOADBALANCER_IP)""" | Add-Content $outputfile
    "   instance_size = ""$($VM.INSTANCE_SIZE)""" | Add-Content $outputfile
    "   instance_num = 5" | Add-Content $outputfile
    "   provision_vm_agent = true" | Add-Content $outputfile
    "	image_id = ""$image_id""" | Add-Content $outputfile
    "}" | Add-Content $outputfile
    "" | Add-Content $outputfile

    $counter++
}

Write-Host " $counter definition created."
