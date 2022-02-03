function Copy-Folder
{
	param
	(
		[Parameter(Mandatory)]
		[string] $source,
		[Parameter(Mandatory)]
		[string] $destination
	)

	if (-not (Test-Path -Path $destination))
	{
		New-Item -Path $destination -ItemType "Directory"
	}

	Copy-Item (Join-Path $source "*") -Destination $destination -Recurse
}

function New-TempFolder 
{
	param
	(
		[Parameter(Mandatory=$false)]
		[string] $prefix
	)

    $subFolder = -Join ($prefix, [System.IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) $subFolder)
}

function Remove-Folder
{
	param
	(
		[Parameter(Mandatory=$true)]
		[string] $folder
	)

	Remove-Item $folder -Recurse -Force
}

function Open-Folder
{
	param
	(
		[Parameter(Mandatory)]
		[string] $folder
	)

	if ((Get-Item $folder) -is [System.IO.DirectoryInfo])
	{
		Invoke-Item $folder
	}
}

Export-ModuleMember -Function Copy-Folder, Open-Folder, New-TempFolder, Remove-Folder