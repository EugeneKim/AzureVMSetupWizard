function Wait-AzureVMRunning
{
    param(
        [parameter(Mandatory)]
        [string]$resourceGroupName,
        [parameter(Mandatory)]
        [string]$vmName)

    $i = 0
    $repeat = 100

    do {
        $status = Get-AzVm -Status -ResourceGroupName $resourceGroupName -Name $vmName

        $isVmRunning = ($status.Statuses | Where-Object Code -eq "PowerState/running") ? $true : $false
        $isAgentReady = ($status.VMAgent.Statuses | Where-Object DisplayStatus -eq "Ready") ? $true : $false

        $i++
        Write-Host "Waiting for VM running... $($i)/$($repeat)"

        if ($isVmRunning -and $isAgentReady)
        {
            return $true
        }

        Start-Sleep -Seconds 5
    } while ($i -lt $repeat)

    return $false
}
    
Export-ModuleMember -Function Wait-AzureVMRunning