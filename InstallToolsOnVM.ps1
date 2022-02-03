param
(
    [Parameter(Mandatory)]
    [string] $storageAccountName,
	[Parameter(Mandatory=$true)]
    [string] $storageAccountAccessKey,
    [Parameter(Mandatory)]
    [string] $fileShareName
)

# Connect to the file share in the storage account.
$connectTestResult = Test-NetConnection -ComputerName "$storageAccountName.file.core.windows.net" -Port 445

if (-Not $connectTestResult.TcpTestSucceeded) 
{
    Write-Error "Failed to reach the Azure storage account via port 445."
    return;
}

# Add the user credentials.
cmd.exe /C "cmdkey /add:`"$storageAccountName.file.core.windows.net`" /user:`"localhost\$storageAccountName`" /pass:`"$storageAccountAccessKey`""    

# Mount the (volatile) PS drive.
New-PSDrive -Name AzureFileShareFolder -PSProvider FileSystem -Root "\\$storageAccountName.file.core.windows.net\$fileShareName"

# Download the zip file from the file share.
$workingFolder = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName()))

Write-Host "Downloading zip file from file share..." -NoNewline
Copy-Item "AzureFileShareFolder:\zippedTools.zip" -Destination $workingFolder -Force
Write-Host "Done"

$areAllToolsInstalled = $true

try
{
	# Remove the user credentials.
	cmd.exe /C "cmdkey /delete:`"$storageAccountName.file.core.windows.net`""

	# Unzip the zip file.
	Write-Host "Unzipping file..." -NoNewline
	Expand-Archive -LiteralPath (Join-Path $workingFolder "zippedTools.zip") -DestinationPath $workingFolder
	Write-Host "Done"

	# Install tools

	$tools = Get-Content -Path (Join-Path $workingFolder "tools.json") | ConvertFrom-Json

	for ($i=0; $i -lt $tools.Length; $i++)
	{
		$name = $tools[$i].Name
		$exe = $tools[$i].Exe
		$arguments = $tools[$i].Args

		Write-Host "Installing tool: $name..." -NoNewline
		Start-Process -FilePath ([IO.Path]::Combine($workingFolder, $name, $exe)) -ArgumentList $arguments -Wait
		Write-Host "Done"
	}
}
catch
{
	$areAllToolsInstalled = $false
	throw;
}
finally
{
	# Clean up.
	Write-Host "Cleaning up..." -NoNewline
	Remove-Item $workingFolder -Recurse -Force
	Write-Host "Done"

	if ($true -eq $areAllToolsInstalled)
	{
		Write-Host "Installed tools successfully."
	}
	else
	{
		Write-Error "Failed to install tools."
	}
}