# Azure VM Setup Wizard

## What is Azure VM Setup Wizard?
This creates an Azure VM, and installs the tools from the internet, network share or local storage on the Azure VM.

## What does Azure VM Setup Wizard want to show us?
This was written purely for the purpose of sharing knowledge about Azure PowerShell Script and ARM template.
- How to use the ARM template to create Azure resources.
- How to run a command on Azure VM and receive outputs.
- Some examples of Azure PowerShell usage.

## How to use

#### 1. Prepare the list of tools that will be installed on Azure VM.
The script refers to tools.json file. 
The JSON file is an array of the objects. The object contains the details of installer of a tool.
these are keys in an object.
* Name: Name of the tool. This name is also used for the folder name.
* Repository: Location of the installer of the tool
* Exe: File name of the installer.
* Args: Command-line arguments that the installer will use.

Example)  
This is the object for the Visual Studio Code installer.
```
{
    "Name": "Visual Studio Code x64 (v1.63.2)",
    "Repository": "https://go.microsoft.com/fwlink/?Linkid=852157",
    "Exe": "VSCodeUserSetup-x64-1.63.2.exe",
    "Args": "/VERYSILENT /NORESTART /MERGETASKS=!runcode"
}
```

#### 2. Run AzureVmSetupWizardRunner.ps1 in PowerShell command-line tool.
```
# .\RunMe.ps1
	-SubscriptionId <String>
	-ResourceGroupName <String>
	-Location <String>
	-AdminUserName <String>
	-VmSize <String>
```

Example)  
This example creates a new resource group (rg-vmsetup-dev) in Australia East region, then creates Azure VM (VM Size Standard B1s) with vm-user as admin account in your subscription (ID: 00000000-0000-0000-0000-000000000000)
```
.\RunMe.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -ResourceGroupName rg-vmsetup-dev -Location australiaeast -AdminUserName vm-user -VmSize Standard_B1s
```

### 3. Input the password of your admin user.
Password is a secure string that we don't pass in through a parameter.
>There are *password requirements* when creating a VM.  
>The supplied password must be between *8-123 characters long* and must satisfy *at least 3 of password complexity requirements* from the following:
> * Contains an uppercase character
> * Contains a lowercase character
> * Contains a numeric digit
> * Contains a special character
> * Control characters are not allowed

### 4. Wait until script is finished installing.
You should see *"All done. VM name is ..."* at the end of the output.
The you can use Remote Desktop to connect to the Azure VM and see if the tools are installed.

### Tips
* Gets available VM sizes in a location.
```
Get-AzVMSize -Location "southcentralus" | Out-GridView
```

[Sizes for virtual machines in Azure]([https://docs.microsoft.com/en-us/azure/virtual-machines/sizes]) is also quite useful for you to understand what VM size suits for your workloads.


* Get all Azure locations.
```
Get-AzLocation | Select-Object -Property Location, DisplayName | Out-GridView
```