﻿#region setup
$WorkingDir = $psISE.CurrentFile.FullPath | Split-Path
Set-Location $WorkingDir
#Add-AzureRmAccount
$AAAccountName = "innovation-automation-001"
$RG = Get-AzureRmResourceGroup -Name "Kelly_002"
$AAAcct = Get-AzureRmAutomationAccount -Name $AAAccountName -ResourceGroupName $RG.ResourceGroupName
$Keys = $AAAcct | Get-AzureRmAutomationRegistrationInfo
$StorageAccountName = 'dgc01dscforlinux'
$Location = 'East US'
#endregion



#region ARM Template running Windows VM
$Node4 = $RG | Get-AzureRmVM -Name VKellyWIN002
$TemplateURI = 'https://raw.githubusercontent.com/bheymann58/DSC/master/WindowsDeploy.json'
Start-Process microsoft-edge:$TemplateURI

$RGDeployArgs1 = @{
    TemplateURI = 'https://raw.githubusercontent.com/bheymann58/DSC/master/WindowsDeploy.json'
    Mode = 'Incremental'
    ResourceGroupName = $RG.ResourceGroupName
    TemplateParameterObject = @{
        vmName = $Node4.Name
        registrationKey = $Keys.PrimaryKey
        registrationUrl = $Keys.Endpoint
        nodeConfigurationName = ''
        timestamp = [datetime]::Now.ToString()
    }
}

New-AzureRmResourceGroupDeployment @RGDeployArgs1 -Force
#endregion

#region ARM Template running Linux VM
$Node5 = $RG | Get-AzureRmVM -Name HeymannLinuxUBTest02
$TemplateURI = 'https://raw.githubusercontent.com/bheymann58/DSC/master/LinuxDeploy.json'
Start-Process microsoft-edge:$TemplateURI

$LinuxTemplateOnboard = @{
    ResourceGroupName = $RG.ResourceGroupName
    Mode = 'Incremental'
    TemplateParameterObject = @{
        registrationKey = $Keys.PrimaryKey
        registrationUrl = $Keys.Endpoint
    }
    TemplateUri = 'https://raw.githubusercontent.com/bheymann58/DSC/master/LinuxDeploy.json'
    vmName = $Node5.Name
}

New-AzureRmResourceGroupDeployment @LinuxTemplateOnboard
#endregion