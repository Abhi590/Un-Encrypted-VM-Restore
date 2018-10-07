# Un-Encrypted-VM-Restore
It will restore un-encrypted VM


Un-Encrypted Virtual Machine Recovery


# Objective
If the backup is configured the recovery service vault will take backup of VM. If the VM got crashed or any issue with the VM then a new VM need to be created with same configuration and data from the backup. We can select the restore point before the VM crashed to create new VM.The below script can restore if the VM is not encrypted.TO perform recovery you need to have storage account where restored config and vhd files will be stored.

The restoration of VM is two Phase activity

Phase I – Restoration of VM into storage account include config file, Template and Virtual Hard Disk – VHD. This process might take time around 40 - 45 mins depend on VM/Disk size

Phase II – A new VM will be created from files restored in phase I. Creation of VM, OS disk, data disk, NIC, Virtual IP (if applicable) with correct subnet. This process might take 15 – 20 mins
 

We will have option to create Managed and unmanaged disk type.

# Parameters Required for VM restoration 
We need to provide below parameters to run the script. 

Mandatory parameters is as below

SubscriptionName –  Name of subscription where the resources are available.
VM_Tobe_Restored  - Name of existing VM that need to be restored.
RecoveredVmName  - Name of new VM after recovery
VmRgName - Resource group name where new VM will be created
RecoveryVaultName - Recovery service vault name where backup is configured.
StorageRg - Resource group name of storage account
StorageAccName - Name of storage account where VM files will be restored


# Resoration Steps  are as below
1.	Open powershell and login to Azure using below command
Login-AzureRmAccount
2.	Download the file to local system and open file location.
3.	Run the powershell file using below command.
Pass the required parameters to the command and run.

.\Restore_VirtualMachine.ps1 -SubscriptionName '<Subscription Name>'
-VM_Tobe_Restored '<vm name>'
-RecoveredVmName '<new vm name>'
-VmRgName '<rg name>'
-RecoveryVaultName '<recovery vault name>'
-StorageRg '<storage accnt rg name>'
-StorageAccName '<storage accnt name>'


Example: 
.\Restore_VirtualMachine.ps1 -SubscriptionName 'Pay As you Go' `
-VM_Tobe_Restored 'VM1' `
-RecoveredVmName 'VM1-Restored' `
-VmRgName 'mytestrg' `
-RecoveryVaultName 'myvault' `
-StorageRg 'mytestrg' `
-StorageAccName 'teststgaccnt'

4.	The 1st phase of recovery has been started. While the process is running you need to provide some input.
Select the Recovery Point to Recover...
It will provide the list of recovery point available for VM that can be restored. Select the recovery point as required. ( Latest recovery point recommended.) and click on “OK”.
 
5.	Now the restore will start, that will take 30 – 45 mins to complete depend on VM or data size.
 

6.	Now the second phase will start .It will ask to select restore job to create VM.
Select the restore job created in 1st phase and click “OK”
 
7.	Next it will ask if the disk will be managed. 
Type Y if you want new disk to be managed disk or type N it you want new disk to be unmanaged. And “Enter”.
 
 
8.	Next it will ask to select the subnet where new VM need to be created.
Search for your subnet name and select the subnet and click “OK”.
 
9.	Now it will ask if you need a public IP for VM.
If you want to use old public IP : 
Select “N” And after VM creation you can attach old public IP to new VM or you can attach old NIC to new VM.
If you want to use new public IP :
Select “Y”  And after VM creation update the new public IP in DNS/loadbalancer and other configuration accordingly to connect with VM.
And Enter

10.	It will deploy the VM as per configuration selected. Monitor the progress. Once completed and successful,  verify it by checking VM in Azure portal.

