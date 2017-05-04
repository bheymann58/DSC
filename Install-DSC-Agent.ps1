workflow install-dsc-agent
{
    Param
    (
        [Parameter(mandatory=$true)]
        [String] $AutomationAccountName,

        [Parameter(mandatory=$true)]
        [String] $AAResourceGroup,

        [Parameter(mandatory=$true)]
        [boolean] $DryRun
    )


    #region setup
#Add-AzureRmAccount
#$AAAccountName = "$AutomationAccountName"
#$AAAcct = Get-AzureRmAutomationAccount -Name $AAAccountName -ResourceGroupName $AAResourceGroup
#$Keys = $AAAcct | Get-AzureRmAutomationRegistrationInfo
#endregion

    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
    Select-AzureRmSubscription -SubscriptionId $Conn.SubscriptionID

$AAAccountName = "$AutomationAccountName"
$AAAcct = Get-AzureRmAutomationAccount -Name $AAAccountName -ResourceGroupName $AAResourceGroup
$Keys = $AAAcct | Get-AzureRmAutomationRegistrationInfo

    if ($DryRun -eq $true)
    {
        Write-Output("This script was executed in Dry Run mode.  DSC Extension will not be installed.")
    }

    $ResourceGroupList = Get-AzureRmResourceGroup -Verbose
    ForEach -Parallel ($ResourceGroupName in $ResourceGroupList.ResourceGroupName)
    {
        InlineScript 
        {
            $ResourceGroupName = $Using:ResourceGroupName
            $Keys = $Using:Keys
            $AAAcct = $Using:Acct

            $DryRun = $Using:DryRun

            $DSCNewInstallCount = 0

            $VMList = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -WarningAction SilentlyContinue -Verbose

            ForEach ($VM in $VMList)
            {
                $IsVMExtensionInstalled = Get-AzureRmVMExtension `
                                                -ResourceGroupName $ResourceGroupName `
                                                -VMName $VM.Name `
                                                -Name Microsoft.PowerShell.DSC `
                                                -ErrorAction SilentlyContinue `
                                                -WarningAction SilentlyContinue

                if ($IsVMExtensionInstalled -eq $null)
                {
                    $VMPowerState = $VM | Get-AzureRmVM -Status -WarningAction SilentlyContinue | Select -ExpandProperty Statuses | ?{ $_.Code -match "PowerState" } | Select -ExpandProperty DisplayStatus

                    if ($VMPowerState -eq "VM running")
                    {
                        if ($VM.StorageProfile.OsDisk.OsType -eq "Windows")
                        {
                            if ($DryRun -eq $false)
                            {
                                Write-Output("Installing DSC agent on Windows Server: " + $ResourceGroupName + " / " + $VM.Name)

                            $WindowsTemplateOnbaord = @{
                                    TemplateURI = 'https://raw.githubusercontent.com/bheymann58/DSC/master/WindowsDeploy.json'
                                    Mode = 'Incremental'
                                    ResourceGroupName = $ResourceGroupName
                                    TemplateParameterObject = @{
                                        vmName = $VM.Name
                                        registrationKey = $Keys.PrimaryKey
                                        registrationUrl = $Keys.Endpoint
                                        nodeConfigurationName = ''
                                        timestamp = [datetime]::Now.ToString()
                                    }
                                }

                                New-AzureRmResourceGroupDeployment @WindowsTemplateOnbaord -Force
                            }

                            $DSCNewInstallCount++
                        }
                        else
                        {
                            $IsLinuxVMExtensionInstalled = Get-AzureRmVMExtension `
                                                -ResourceGroupName $ResourceGroupName `
                                                -VMName $VM.Name `
                                                -Name MicrosoftAADSC `
                                                -ErrorAction SilentlyContinue `
                                                -WarningAction SilentlyContinue

                            if ($IsLinuxVMExtensionInstalled -eq $null)
                            {
                                if ($DryRun -eq $false)
                                {
                                    $LinuxTemplateOnboard = @{
                                        ResourceGroupName = $ResourceGroupName
                                        Mode = 'Incremental'
                                        TemplateParameterObject = @{
                                            registrationKey = $Keys.PrimaryKey
                                            registrationUrl = $Keys.Endpoint
                                        }
                                        TemplateUri = 'https://raw.githubusercontent.com/bheymann58/DSC/master/LinuxDeploy.json'
                                        vmName = $VM.Name
                                    }

                                    New-AzureRmResourceGroupDeployment @LinuxTemplateOnboard
                                }
                            }
                            
                            $DSCNewInstallCount++
                        }
                    }
                }
            }

            if ($DSCNewInstallCount -gt 0)
            {
                if ($DryRun -eq $true)
                {
                    Write-Output("Status for " + $ResourceGroupName + ": DSC Extension needed on " + $DSCNewInstallCount + " VM(s)")
                }
                else
                {
                    Write-Output("Status for " + $ResourceGroupName + ": DSC Extension installed on " + $DSCNewInstallCount + " VM(s)")
                }
            }
            else
            {
                Write-Output("Status for " + $ResourceGroupName + ": No changes")
            }
        }
    }

    Write-Output("Finished checking VMs")
}