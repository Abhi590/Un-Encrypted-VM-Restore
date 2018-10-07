#########################################################################################
#                                                                                       #
#         Author: Abhishek Jaiswal                                                      #
#         .Synopsis                                                                     #
#         .Description                                                                  #
#       The script will restore un-encrypted virtual machine from                       #
#       recovery service vault in Azure.                                                #
#                                                                                       #
#########################################################################################

#Mandatory parameter
Param(
    
    [CmdletBinding()]

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VM_Tobe_Restored,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RecoveredVmName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VmRgName,

    [Parameter(Mandatory = $true)]                                                           ā
    [ValidateNotNullOrEmpty()]
    [string]$RecoveryVaultName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageRg,

    [Parameter(Mandatory = $true)]               ā
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccName
)

set-AzureRmContext -SubscriptionName $SubscriptionName

function Restore-EncryptedVMDisks {

    Param(
    
        [CmdletBinding()]
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VMName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageAccountName,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageResourceGroup,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RecoveryServicesVaultName
    )
    
    Write-Host -ForegroundColor Cyan "[Begin  ] Phase 1: Restoring Disks in storage account"
    
    ## Getting Restore Point ##
    try 
    {
        Get-AzureRmRecoveryServicesVault -Name $RecoveryServicesVaultName -ErrorAction Stop | Set-AzureRmRecoveryServicesVaultContext -ErrorAction Stop
        Write-Host -ForegroundColor Green "[Success] Set Recovery Services Vault Context"
    }
    catch 
    {
        Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
    } ## END SET RECOVERY SERVICES VAULT CONTEXT
    
    try 
    {
        $namedContainer = Get-AzureRmRecoveryServicesBackupContainer  -ContainerType "AzureVM" -Status "Registered" -FriendlyName $VMName -ErrorAction Stop
        Write-Host -ForegroundColor Green "[Success] Retrieved Backup Container"
    }
    catch 
    {
        Return Write-Host -ForegroundColor Red ("Error: Unable to return Backup Container - please check existing VM name")
    } ## END GET RECOVERY SERVICES BACKUP CONTAINER
    
    try 
    {
        $backupitem = Get-AzureRmRecoveryServicesBackupItem -Container $namedContainer  -WorkloadType "AzureVM" -ErrorAction Stop
        Write-Host -ForegroundColor Green "[Success] Retrieved Backup Item"
    }
    catch 
    {
        Return Write-Host -ForegroundColor Red ("Error: Unable to return Backup Item - please check backup has run for existing VM")
    } ## END GET RECOVERY SERVICES BACKUP ITEM
    
    try 
    {
        $StartDate = (Get-Date).AddDays(-15)
        $endDate = Get-Date
        $rp = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $backupitem -StartDate $startdate.ToUniversalTime() -EndDate $enddate.ToUniversalTime() -ErrorAction Stop
        Write-Host -ForegroundColor Green "[Success] Retrieved Recovery Points"
        Write-Host -ForegroundColor Magenta "[Prompt ] Select the Recovery Point to Recover..."
        $selectedrp = $rp | out-gridview -Title "Select the Recovery Point to Recover..." -OutputMode Single
        Write-Host -ForegroundColor Green "[Success] Selected Recovery Point"
        Write-Host ""
    }
    catch 
    {
        Return Write-Host -ForegroundColor Red ("Error: Unable to return Recovery Points - please check backup has run for existing VM since $($StartDate)")
    } ## END GET RECOVERY SERVICES RECOVERY POINT
    
    
    Write-Host -ForegroundColor Green ("Ready...")
    
    ## Beginning Restore ##
    
    try 
    {
        Write-Host -ForegroundColor Green "[Success] Restore Beginning - this may take 30-45 minutes...Depend on VM size(Disk)."
        $restorejob = Restore-AzureRmRecoveryServicesBackupItem `
            -RecoveryPoint $selectedrp `
            -StorageAccountName $StorageAccountName `
            -StorageAccountResourceGroupName $StorageResourceGroup `
            -ErrorAction Stop
    }
    catch 
    {
        Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
    } ## END RESTORE BACKUP ITEM
    
    if ($restorejob.status -eq 'Failed') 
    {
        Return Write-Host -ForegroundColor Red ("Error: Failed to Restore Disk - Another Restore Job may already be in progress")
    } ## END GET RECOVERY STATUS
    
    Write-Host -ForegroundColor Yellow "[Info   ] Restore Job Submitted: $($restorejob.StartTime)"
    
    while ((Get-AzureRmRecoveryServicesBackupJobDetails -Job $restorejob).Status -eq "InProgress") 
    {
        Write-Host -ForegroundColor Yellow "in progress - wait"
        Start-Sleep -Seconds 20
    } ## END WAIT FOR JOB TO COMPLETE
    
    $restorejobresult = Get-AzureRmRecoveryServicesBackupJobDetails -Job $restorejob
    Write-Host -ForegroundColor green "[Info   ] Restore Job Completed: $($restorejobresult.EndTime)"
    Write-Host -ForegroundColor green "[Info   ] Restore Job Duration: $($restorejobresult.Duration)"
    Write-Host -ForegroundColor green "[Info   ] Restore Job Result: $($restorejobresult.Status)"
    Write-Host -ForegroundColor green "[End    ] Phase 1: Restoring Disks Completed"
    
    
    } ## END FUNCTION Restore-EncryptedVMDisks


	
function New-EncryptedVmFromDisks {

Param(

    [CmdletBinding()]

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VMNameRecovered,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VMResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RecoveryServicesVaultName

)



Write-Host -ForegroundColor Cyan "[Begin  ] Phase 2: Deploy VM from Disks"

## Getting Completed Job Details to Build VM Config ##

try 
{
    Get-AzureRmRecoveryServicesVault -Name $RecoveryServicesVaultName -ErrorAction Stop | Set-AzureRmRecoveryServicesVaultContext -ErrorAction Stop
    Write-Host -ForegroundColor Green "[Success] Set Recovery Services Vault Context"
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
}

try 
{
    Write-Host -ForegroundColor Magenta "[Prompt ] Select the Recovery Services Backup Job..."
    $restorejob = Get-AzureRmRecoveryServicesBackupJob -ErrorAction Stop `
        | where-object {($_.Operation -eq "Restore") -and ($_.Status -eq "Completed")} `
        | Sort-Object -Property 'EndTime' -Descending `
        | Out-GridView `
        -Title "Select the Recovery Services Backup Job..." `
        -OutputMode Single
    Write-Host -ForegroundColor Green "[Success] Retrieved Recovery Services Backup Job"
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: Unable to return Recovery Services Backup Job - please make sure the disk has been restored")
}

try 
{
    Write-Host -ForegroundColor Yellow "[Info   ] Gathering Deployment Configuration from Backup Job..."
    $details = Get-AzureRmRecoveryServicesBackupJobDetails -Job $restorejob -ErrorAction Stop
    $properties = $details.properties
    $storageAccountName = $properties["Target Storage Account Name"]

    $containerName = $properties["Config Blob Container Name"]
    $blobName = $properties["Config Blob Name"]
    $vmname = $restorejob.WorkloadName
    Set-AzureRmCurrentStorageAccount -Name $storageaccountname -ResourceGroupName $StorageResourceGroup -ErrorAction Stop | Out-Null
    $destination_path = Join-Path (Split-Path $Profile) vmconfig.json
    Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $destination_path -Force -ErrorAction Stop | Out-Null
    $obj = ((Get-Content -Path $destination_path -Raw -Encoding Unicode)).TrimEnd([char]0x00) | ConvertFrom-Json

    Write-Host -ForegroundColor Green "[Success] Retrieved Deployment Configuration from Existing VM"
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
}

#Creating VM config with hardware profile

try 
{
    $vm = New-AzureRmVMConfig -VMSize $obj.'properties.hardwareProfile'.vmSize -VMName $VMNameRecovered -ErrorAction Stop
    Write-Host -ForegroundColor Green "[Success] Created new VM Config Object"
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
}

$osDiskName = $vm.Name + "_osdisk"
$osVhdUri = $obj.'properties.storageProfile'.osDisk.vhd.uri
$Location = $obj."location"
$caching = $obj.'properties.storageProfile'.osDisk.caching
$storageType = "Standard_LRS"

$yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Wait'
$no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Dont Wait'
$qoptions = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
$qresult = $host.ui.PromptForChoice('Waiting?', '[Prompt ] if the Restored Disk type will be Managed?', $qoptions, 0)
Switch ($qresult) {
    0 {
        Write-Host -ForegroundColor Yellow "[Info   ] Creating Profile for OS Disk..."
        try 
		{
	        $diskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $Location -CreateOption Import -SourceUri $osVhdUri
			Write-Host -ForegroundColor Green "[Success] VM OS Disk Configuration Created"
        }
        catch 
		{
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        }
        try 
		{
	        $osDisk = New-AzureRmDisk -DiskName $osDiskName -Disk $diskConfig -ResourceGroupName $VmRgName
            Write-Host -ForegroundColor Green "[Success] VM OS Disk Object Created"
        }
        catch 
		{
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        }
	    try 
		{
		    Set-AzureRmVMOSDisk -VM $vm -ManagedDiskId $osDisk.Id -CreateOption "Attach" -Windows
            Write-Host -ForegroundColor Green "[Success] OS disk added to VM config"
        }
        catch 
		{
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        }
		foreach($dd in $obj.'properties.storageProfile'.dataDisks)
        {
            Write-Host -ForegroundColor Yellow "[Info   ] Creating Profile(s) for Data Disk(s)..."
            $dataDiskName = $vm.Name + $dd.name ;
            $dataVhdUri = $dd.vhd.uri ;
            try
            {
                $dataDiskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $Location -CreateOption Import -SourceUri $dataVhdUri
                Write-Host -ForegroundColor Green "[Success] VM Data Disk Configuration Created: $($dataDiskName)"
            }
            catch 
		    {
                Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
            }
            try 
		    {
                $dataDisk2 = New-AzureRmDisk -DiskName $dataDiskName -Disk $dataDiskConfig -ResourceGroupName $VmRgName ;
                Write-Host -ForegroundColor Green "[Success] VM Data Disk Object Created: $($dataDiskName)"
            }
            catch 
		    {
                Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
            }
		    try 
		    {
                Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -ManagedDiskId $dataDisk2.Id -Lun $dd.Lun -CreateOption "Attach"
                Write-Host -ForegroundColor Green "[Success] Data Disk Set to VM config: $($dataDiskName)"
            }
            catch 
		    {
                Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
            }
		}
	}
    1 {
        $storageType = "Standard_LRS"
	    Write-Host -ForegroundColor Yellow "[Info   ] Creating Profile for OS Disk..."
	    try 
		{
		    Set-AzureRmVMOSDisk -VM $vm -Name $osDiskName -VhdUri $osVhdUri -Caching $caching -CreateOption "Attach" -Windows/Linux -StorageAccountType $storageType
			$vm.StorageProfile.OsDisk.OsType = $obj.'properties.storageProfile'.osDisk.osType
			Write-Host -ForegroundColor Green "[Success] OS Disk Set to VM config"				
		}
        catch 
		{
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        }
		foreach($dd in $obj.'properties.storageProfile'.dataDisks)
		{
		    $dataDiskName = $vm.Name + $dd.name ;
            $dataVhdUri = $dd.vhd.uri ;
	        Write-Host -ForegroundColor Yellow "[Info   ] Creating Profile(s) for Data Disk(s)..."
            try 
			{
				$vm = Add-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -VhdUri $dataVhdUri -Lun $dd.Lun -CreateOption "Attach"
				set-AzureRmVMDataDisk -VM $vm -Name $dataDiskName -StorageAccountType $storageType
                Write-Host -ForegroundColor Green "[Success] Data Disk Set to VM config: $($dd.name)"
			}
            catch 
			{
                Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
            }					
		}
    }
}


## Adding plan to azure VM config file
If($obj."plan" -ne "null")
{
try 
{
    Write-Host -ForegroundColor yellow "[Info ] Setting plan to VM config"
	$planname = $obj."plan".name
	$publishername = $obj."plan".publisher
	$productname = $obj."plan".product
    $plan = Set-AzureRmVMPlan -VM $vm -Name $planname -Product $productname -Publisher $publishername
    Write-Host -ForegroundColor Green "[Success] Plan has been set: $($planname)"
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
}
}


## Adding Network Profile to VM Config Object ##

try 
{
    Write-Host -ForegroundColor Magenta "[Prompt ] Select the Subnet the VM should be assigned to..."
    $subnet = (Get-AzureRmVirtualNetwork -ErrorAction Stop).subnets | Select-Object name, id | out-gridview -Title "Select the Subnet the VM should be assigned to..." -PassThru
    Write-Host -ForegroundColor Green "[Success] Retreived Subnet: $($subnet.name)"
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
} ## END GET SUBNET


$ch1 = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Wait'
$ch2 = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Dont Wait'
$options1 = [System.Management.Automation.Host.ChoiceDescription[]]($ch1, $ch2)
$qresult2 = $host.ui.PromptForChoice('Waiting?', '[Prompt ] if public IP required?', $options1, 0)

Switch ($qresult2) {
    0 {
        Write-Host -ForegroundColor Yellow "[Info   ] PIP Is Enabled"
        try 
        {
            $pip = New-AzureRmPublicIpAddress -Name "pip-$($VMNameRecovered)" -ResourceGroupName $VmRgName -Location $Location -AllocationMethod Dynamic -ErrorAction Stop
            Write-Host -ForegroundColor Green "[Success] Created PIP"
        }
        catch 
        {
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        }
        try 
        {
            $nic = New-AzureRmNetworkInterface -Name "nic-$($VMNameRecovered)" -ResourceGroupName $VmRgName -Location $Location -SubnetId $subnet.id -PublicIpAddressId $pip.Id -ErrorAction Stop
            Write-Host -ForegroundColor Green "[Success] Created NIC"
        }
        catch 
        {
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        } ## END NEW NIC WITH PIP

    }
    1 {
        try 
        {
            $nic = New-AzureRmNetworkInterface -Name "nic-$($VMNameRecovered)" -ResourceGroupName $VmRgName -Location $Location -SubnetId $subnet.id -ErrorAction Stop
            Write-Host -ForegroundColor Green "[Success] Created NIC"
        }
        catch 
        {
            Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
        } ## END NEW NIC WITHOUT PIP
    }
}

try 
{
    $vm = Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
}


## Deploying Resource from Config Object ##

try 
{
    Write-Host -ForegroundColor Yellow "[Info] VM Create started It may take 5-15 min based on VM size."
    $job = New-AzureRmVM -ResourceGroupName $VmRgName -Location $Location -VM $vm -Asjob -errorAction stop
}
catch 
{
    Return Write-Host -ForegroundColor Red ("Error: $($error[0].exception.message)")
}

while ((Get-Job $job.id).State -eq "Running") 
{
    Write-Host -ForegroundColor Yellow "in progress - wait"
    Start-Sleep -Seconds 20
}
if ((Get-Job $job.id).State -eq "Completed") 
{
    Write-Host -ForegroundColor Green "[Success] VM Created"
}
else 
{
    Return Write-Host -ForegroundColor Red ("Deploy Failed")
}


Write-Host -ForegroundColor Cyan "[End    ] Phase 2: Deployment of VM from Backup Completed"
}

Restore-EncryptedVMDisks -VMName $VM_Tobe_Restored -StorageAccountName $StorageAccName -StorageResourceGroup $StorageRg -RecoveryServicesVaultName $RecoveryVaultName
New-EncryptedVmFromDisks -VMNameRecovered $RecoveredVmName -VMResourceGroup $VmRgName -StorageResourceGroup $StorageRg -RecoveryServicesVaultName $RecoveryVaultName



