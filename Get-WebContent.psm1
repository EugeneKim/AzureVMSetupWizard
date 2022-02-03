function Get-WebContent
{
	param(
		[Parameter(Mandatory)]
		[string] $uri,
		[Parameter(Mandatory)]
		[string] $folder,
		[Parameter(Mandatory)]
		[string] $filename
	)

	if (-not (Test-Path -Path $folder))
	{
		New-Item -Path $folder -ItemType "Directory"
	}

	Invoke-WebRequest -Uri $uri -OutFile (Join-Path $folder $filename)
}

Export-ModuleMember -Function Get-WebContent