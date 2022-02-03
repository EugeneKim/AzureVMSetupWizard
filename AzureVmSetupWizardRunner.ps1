param(
	[parameter(Mandatory)]
	[string]$subscriptionId,
	[parameter(Mandatory)]
	[string]$resourceGroupName,
	[parameter(Mandatory)]
	[string]$location,
	[parameter(Mandatory)]
	[string]$adminUsername,
	[parameter(Mandatory)]
	[SecureString] $adminPassword,
	[parameter(Mandatory)]
	[string]$vmSize
)

Set-StrictMode -Version 3.0

Import-Module "$PSScriptRoot\Get-WebContent.psm1" -Force
Import-Module "$PSScriptRoot\Manage-Folder.psm1" -Force
Import-Module "$PSScriptRoot\Wait-AzureVMRunning.psm1" -Force

$toolsJsonFile = Join-Path $PSScriptRoot "tools.json"

# Ensure the tools JSON file exists in this script folder.
if (-not (Test-Path -Path $toolsJsonFile -PathType Leaf))
{
	Write-Error "JSON file not found: $toolsJsonFile"
	return
}

$fileShareName = "tools"
$tools = Get-Content -Path $toolsJsonFile | ConvertFrom-Json -AsHashtable
$workingFolder = New-TempFolder

try
{
	foreach ($tool in $tools)
	{
		$name = $tool["Name"]
		$repository = $tool["Repository"]
		
		if ($repository -match "^(http://|https://)")
		{
			# Download the tool from web.
			Write-Host "Web downloading $name... $repository"
			Get-WebContent -Uri $repository -Folder (Join-Path $workingFolder $name) -Filename $tool["Exe"]
			Write-Host "Done."
		}
		elseif ($repository -match "^([a-z]:\\|\\\\)")
		{
			# Copy the tool to the working folder.
			Write-Host "Local copying $name... $repository"
			Copy-Folder -Source $repository -Destination (Join-Path $workingFolder $name)
			Write-Host "Done."
		}
		else
		{
			Write-Error "Cannot handle $name from $repository"
		}
	}

	# Copy the JSON file to the working folder.
	Copy-Item -Path $toolsJsonFile -Destination $workingFolder

	# Pack up the tools files.
	Write-Host "Zipping files..."
	$toolsZipFile = Join-Path $workingFolder "zippedTools.zip"
	Compress-Archive -Path (Join-Path $workingFolder "*") -DestinationPath $toolsZipFile
	
	Connect-AzAccount
	Set-AzContext -SubscriptionId $subscriptionId

	#Create a resource group.
	New-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop

	# Create a new VM, VM resources and file share to the storage account.
	Write-Host "Creating VM and resources..."
	$results = New-AzResourceGroupDeployment `
		-ResourceGroupName $resourceGroupName  `
		-TemplateFile ".\azuredeploy.json" `
		-ErrorAction SilentlyContinue `
		-ErrorVariable errorDetails `
		-adminUsername $adminUsername `
		-adminPassword $adminPassword `
		-location $location `
		-vmSize $vmSize `
		-fileShareName $fileShareName

	if ($errorDetails)
	{
		throw $errorDetails
	}

	# Retrieve the template outputs to use later.
	$vmName = $results.Outputs["vmName"].Value
	$fileShareName = $results.Outputs["filesharename"].Value
	$storageAccountName = $results.Outputs["storageAccountName"].Value
	$storageAccountAccessKey = $results.Outputs["storageAccountAccessKey"].Value

	Write-Host "Uploading the zip file to Azure file share..."
	$storageAccountContext = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName).Context
	$fileShare = Get-AzStorageShare -Context $storageAccountContext -Name $fileShareName
	Set-AzStorageFileContent `
		-Sharename $fileShareName `
		-Context $fileShare.Context `
		-Source $toolsZipFile `
		-Path "/" `
		-Force

	# Start VM.
	Write-Host "Starting VM..."
    $isVMStarted = Wait-AzureVMRunning $resourceGroupName $vmName
    if (-not $isVMStarted)
    {
        throw "Failed to start VM. Check the VM status from Azure Portal."
    }

	# Install tools on VM.
	Write-Host "Installing tools on VM..."
    $result = Invoke-AzVMRunCommand `
        -ResourceGroupName $resourceGroupName `
        -Name $vmName `
        -CommandId "RunPowerShellScript" `
        -ScriptPath "./InstallToolsOnVM.ps1" `
        -Parameter @{ storageAccountName="$storageAccountName"; fileShareName="$fileShareName"; storageAccountAccessKey="$storageAccountAccessKey" }

	# Show the result of the command on VM.
	Write-Host "Installation result:"
	Write-Host $result.value.Message

	Write-Host ""
	Write-Host "All done. VM name is $vmName" -ForegroundColor White -BackgroundColor DarkBlue

	# Remove the file share.
    Write-Host "Removing Azure file share..."
	Remove-AzStorageShare -Name $fileShareName -Context $storageAccountContext -Force
}
catch
{
	# Sweep away the resources because they are not available due to the error.
	Remove-AzResourceGroup $resourceGroupName -Force -ErrorAction SilentlyContinue
	throw
}
finally
{
	Disconnect-AzAccount

	# Remove working folder.
	Write-Host "Removing working folder ..."
	Remove-Folder $workingFolder
}