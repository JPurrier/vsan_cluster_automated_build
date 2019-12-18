Connect-viserver Vcenter.server.name -force

########## User Defiable Variables ############
$cluster =  'CLUSTER_NAME'
# Vsan Disk Selection
$cach_disk = 745 #Size of disk MB
$capacity_disk = 1490  #Size of disk MB
$create_vsan = $True
###############################################


# Name of the default storage policy to apply dependent on number of hosts
$vsan_default_storage_policy_raid_5 = 'vSAN-RAID-5-LIGHT'
$vsan_default_storage_policy_raid_1 = 'vSAN-RAID-1-LIGHT'

# Swtich Config Settings
$uplink_ports_number = 2
$LinkDiscoveryProtocol= 'LLDP'
$LinkDiscoveryProtocolOperation = 'Both'

# Vsan Switch config Variables
$pnic_name1 = 'vmnic2'
$uplink_name1 = "Uplink 1"
$pnic_name2 = 'vmnic3'
$uplink_name2 = "Uplink 2"
$search = "*Vsan*"

# VM Switch Config Variables
$pnic_vm_name1 = 'vmnic4'
$uplink_vm_name1 = "uplink1"
$pnic_vm_name2 = 'vmnic5'
$uplink_vm_name2 = "uplink2"
$search_vm = "*vm*"

# MGT Switch config
$search_mgt = "*MGT*"

# Host Network Settings
$domaing_name = 'your.domain'
$ntpServer = 'ntp.server','ntp.server'
$dns = '10.x.x.x','10.x.x.x'


# dSwitch Details
$vmhosts = get-cluster $cluster | Get-VMHost
$vds = $vmhosts[1] | Get-VDSwitch $search
$vds_vm = $vmhosts[1] | Get-VDSwitch $search_vm
$vds_mgt =  $vmhosts[1] | Get-VDSwitch $search_mgt

# Configure Swtich settings such as LLDP number of uplinks standard 2
Set-VDSwitch -VDSwitch $($vds.Name) -NumUplinkPorts  $uplink_ports_number
Set-VDSwitch -VDSwitch $($vds.Name) -LinkDiscoveryProtocol $LinkDiscoveryProtocol 
Set-VDSwitch -VDSwitch $($vds.Name) -LinkDiscoveryProtocolOperation $LinkDiscoveryProtocolOperation

Set-VDSwitch -VDSwitch $($vds_vm.Name) -NumUplinkPorts  $uplink_ports_number
Set-VDSwitch -VDSwitch $($vds_vm.Name) -LinkDiscoveryProtocol $LinkDiscoveryProtocol 
Set-VDSwitch -VDSwitch $($vds_vm.Name) -LinkDiscoveryProtocolOperation $LinkDiscoveryProtocolOperation

Set-VDSwitch -VDSwitch $($vds_mgt.Name) -NumUplinkPorts  $uplink_ports_number
Set-VDSwitch -VDSwitch $($vds_mgt.Name) -LinkDiscoveryProtocol $LinkDiscoveryProtocol 
Set-VDSwitch -VDSwitch $($vds_mgt.Name) -LinkDiscoveryProtocolOperation $LinkDiscoveryProtocolOperation





$code_vsan_switch = {
    foreach($Esx in $vmhosts) 
    { # Configures vSan Switch uplink ports

        $uplinks = ($Esx | Get-VDSwitch | where {$_.name -like $search}) | Get-VDPort -Uplink
        $config = New-Object VMware.Vim.HostNetworkConfig
        $config.proxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
        $config.proxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
        $config.proxySwitch[0].changeOperation = "edit"
        $config.proxySwitch[0].uuid = $vds.Key
        $config.proxySwitch[0].spec = New-Object VMware.Vim.HostProxySwitchSpec
        $config.proxySwitch[0].spec.backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
        $config.proxySwitch[0].spec.backing.pnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (2)
        $config.proxySwitch[0].spec.backing.pnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
        $config.proxySwitch[0].spec.backing.pnicSpec[0].pnicDevice = $pnic_name1
        $config.proxySwitch[0].spec.backing.pnicSpec[0].uplinkPortKey = ($uplinks | where {$_.Name -eq $uplink_name1 -and $_.Switch.name -like $search -and $_.proxyhost -like $esx.name }).key
        $config.proxySwitch[0].spec.backing.pnicSpec[1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
        $config.proxySwitch[0].spec.backing.pnicSpec[1].pnicDevice = $pnic_name2
        $config.proxySwitch[0].spec.backing.pnicSpec[1].uplinkPortKey = ($uplinks | where {$_.Name -eq $uplink_name2 -and $_.Switch.name -like $search -and $_.proxyhost -like $esx.name }).key
       
        
        $_this = Get-View (Get-View $Esx).ConfigManager.NetworkSystem
        $_this.UpdateNetworkConfig($config, "modify")

     
    }
}

$code_vm_switch = {
    foreach($Esx in $vmhosts) 
    { # configures vm switch uplink ports
 
        # $uplinks = $Esx | Get-VDSwitch | Get-VDPort -Uplink | where {$_.ProxyHost -like $Esx.Name}
        $uplinks = ($Esx | Get-VDSwitch | where {$_.name -like $search_vm}) | Get-VDPort -Uplink
        $config = New-Object VMware.Vim.HostNetworkConfig
        $config.proxySwitch = New-Object VMware.Vim.HostProxySwitchConfig[] (1)
        $config.proxySwitch[0] = New-Object VMware.Vim.HostProxySwitchConfig
        $config.proxySwitch[0].changeOperation = "edit"
        $config.proxySwitch[0].uuid = $vds_vm.Key
        $config.proxySwitch[0].spec = New-Object VMware.Vim.HostProxySwitchSpec
        $config.proxySwitch[0].spec.backing = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicBacking
        $config.proxySwitch[0].spec.backing.pnicSpec = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec[] (2)
        $config.proxySwitch[0].spec.backing.pnicSpec[0] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
        $config.proxySwitch[0].spec.backing.pnicSpec[0].pnicDevice = $pnic_vm_name1
        $config.proxySwitch[0].spec.backing.pnicSpec[0].uplinkPortKey = ($uplinks | where {$_.Name -eq $uplink_vm_name1 -and $_.Switch.name -like $search_vm -and $_.proxyhost -like $esx.name }).key
        $config.proxySwitch[0].spec.backing.pnicSpec[1] = New-Object VMware.Vim.DistributedVirtualSwitchHostMemberPnicSpec
        $config.proxySwitch[0].spec.backing.pnicSpec[1].pnicDevice = $pnic_vm_name2
        $config.proxySwitch[0].spec.backing.pnicSpec[1].uplinkPortKey = ($uplinks | where {$_.Name -eq $uplink_vm_name2 -and $_.Switch.name -like $search_vm -and $_.proxyhost -like $esx.name}).key
       
        
        $_this = Get-View (Get-View $Esx).ConfigManager.NetworkSystem
        $_this.UpdateNetworkConfig($config, "modify")

    }
}

$code_host_config = {
    foreach($Esx in $vmhosts) 
    { # Code defines standard host network settings like dns, ntp etc and disables and enables relivent services

       
        
        [string]$host_name = $esx.name
        $host_name = $host_name.replace('.domain.com','')

        $vmHostNetworkInfo = Get-VmHostNetwork -Host $esx
        Get-VMHostNetwork -VMHost $esx | Set-VMHostNetwork -DomainName $domaing_name -HostName $host_name -DnsAddress $dns
        $vmHostNetworkInfo | Set-VMHostNetwork -DomainName $domaing_name -HostName $host_name -DnsAddress $dns -SearchDomain $domaing_name

        Add-VMHostNTPServer -NtpServer $ntpServer -VMHost $Esx
        Get-VMHostService -VMHost $esx | where{$_.Key -eq "ntpd"} | Set-VMHostService -policy "on" -Confirm:$false
        Get-VMHostService -VMHost $esx | where{$_.Key -eq "ntpd"} | Restart-VMHostService -Confirm:$false

        Write-Host "Editing Security for $esx" -ForegroundColor Green
        Get-VMHost $esx | Get-VMHostService | where {$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false |  Set-VMHostService -policy "off" -Confirm:$false
        Get-VMHost $esx | Get-VMHostService | where {$_.Key -eq "ESXi Shell"} | Stop-VMHostService -Confirm:$false |  Set-VMHostService -policy "off" -Confirm:$false
        Get-VMHost $esx | Get-VMHostService | where {$_.Key -eq "TSM"} | Stop-VMHostService -Confirm:$false |  Set-VMHostService -policy "off" -Confirm:$false


    }
}


Write-Host "Ensuring Host has compliant Security and network settings"
Invoke-Command -ScriptBlock $code_vsan_switch
Invoke-Command -ScriptBlock $code_vm_switch
Invoke-Command -ScriptBlock $code_host_config



# Enable vSan on cluster
$code_configure_vsan = {
    get-cluster $cluster | Set-Cluster -VsanEnabled:$true -VsanDiskClaimMode Manual -Confirm:$false -ErrorAction SilentlyContinue
    foreach($Esx in $vmhosts) 
    { # Configure vSan

        # Check for Eligible Disks for vSan
        $VsanHostDisks = Get-VMHost -Name $ESX | Get-VMHostHba | Get-ScsiLun | Where-Object {$_.VsanStatus -eq “Eligible”}
        $CacheDisks = @()
        $CapacityDisks = @()
        Foreach ($VsanDisk in $VsanHostDisks)
        {# Add disks the same size as specified in user variables to either capcity or cache hash table
            If ($VsanDisk.IsSsd -eq $true -and [Math]::Truncate($VsanDisk.CapacityGB) -eq $capacity_disk)
            {
                $CapacityDisks += $VsanDisk
            }
            elseif ($VsanDisk.IsSsd -eq $true -and [Math]::Truncate($VsanDisk.CapacityGB) -eq $cach_disk)
            {
                $CacheDisks += $VsanDisk
                Write-Host "added Cachdisk $($CacheDisks.Count)"
            }

        }

        $counter = [pscustomobject] @{ Value = 0 }
        
        # Create Disk Groups 
        Switch ($CacheDisks.Count) 
        { 
            "1" {
                    Write-Host "Creating 1 Disk Group because there is only 1 cache device " 
            
                    $MaxGroup = 7
                }
        {($_ -gt 1) -and ($_ -lt 6)} {
                Write-Host "Creating 2 Disk Groups"
                $MaxGroup = [math]::floor($CapacityDisks.Count / $CacheDisks.Count)      
                $groupSize = [math]::floor($CapacityDisks.Count / $CacheDisks.Count)  }
      }
      
   
      $DiskGroups = $CapacityDisks | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }
    
      
      $i=0
      Foreach ($CacheDisk in $CacheDisks)
      {
          New-VsanDiskGroup  -VMHost $Esx -SsdCanonicalName $CacheDisk -DataDiskCanonicalName $DiskGroups[$i].Group
          $i = $i+1
          Write-Host "Adding Disk Group" $i
        
      }

    }
}

if($create_vsan)
{# Create vSan if option is set to $true
    Write-host 'Build vSan option is $true' -ForegroundColor Green
    Invoke-Command -ScriptBlock $code_configure_vsan
}

# Configure HA & DRS
$cluster_node = Get-Cluster $cluster 
$gateway_address = (Get-VMHost $vmhosts[0].name).ExtensionData.Config.Network.IpRouteConfig.DefaultGateway

if($cluster -like "*PO*")
{
    Write-Host "Playout Cluster Detected disabling DRS enabling HA, Setting Addmission control and host isolation"
    # Enable HA admission control and HA isolation
    Get-Cluster $cluster | Set-Cluster -HAEnabled:$True -DrsEnabled:$false -Confirm:$false
    Get-Cluster $cluster | Set-Cluster -HAAdmissionControlEnabled $true -Confirm:$false
    Get-Cluster $cluster | Set-Cluster -HAIsolationResponse "DoNothing" -Confirm:$false
    # Set up host isolation based on the Default Gateway of Managment nic on Host 1 of cluster
    New-AdvancedSetting -Entity $cluster_node -Type ClusterHA -Name "das.isolationaddress0" -Value $gateway_address -Confirm:$false -force
    # Enable Trim feature on vsan -Future proofing not part of U1
    Get-VsanClusterconfiguration -Cluster $cluster_node | Set-VsanClusterConfiguration -guestTrimUnmap $true
}
Else{
    Write-Host "Production Cluster detected Setting HA, DRS and Automation level. Configuring Host isolation and admission control"
    # Enable HA admission control and HA isolation
    Get-Cluster $cluster | Set-Cluster -HAEnabled:$True -DrsEnabled:$True -DrsAutomationLevel "FullyAutomated" -Confirm:$false
    Get-Cluster $cluster | Set-Cluster -HAAdmissionControlEnabled $true -Confirm:$false
    Get-Cluster $cluster | Set-Cluster -HAIsolationResponse "DoNothing" -Confirm:$false
    # Set up host isolation based on the Default Gateway of Managment nic on Host 1 of cluster
    New-AdvancedSetting -Entity $cluster_node -Type ClusterHA -Name "das.isolationaddress0" -Value $gateway_address -Confirm:$false -force
    # Enable Trim feature on vsan - Future proofing nbot part of U1
    Get-VsanClusterconfiguration -Cluster $cluster_node | Set-VsanClusterConfiguration -guestTrimUnmap $true
}

# Generate Vsan Name
$name_parts = $cluster.split('-')
$i = 0
foreach($part in $name_parts)
{
    if(($name_parts.count -1) -ne $i)
    {
        $vsan_name += $part + '-'
    }
    else {
       $vsan_name += 'VSAN-01'
       break
    }
 $i++
 $i
}

Write-Host "Renaming VSAN to: $vsan_name"

# Rename Vsan Datastore
Get-Cluster $cluster | Get-Datastore -Name 'vsanDatastore' | Set-Datastore -Name $vsan_name

# Enable vSan Compression and Deduplication
Get-VsanClusterConfiguration -Cluster $cluster | Set-VsanClusterConfiguration -SpaceEfficiencyEnabled $true -Confirm:$false
Get-VsanClusterConfiguration -Cluster $cluster | Select-Object Name, VsanEnabled, SpaceEfficiencyEnabled

# Enable Automatic Rebalancing of vSan Data
Get-VsanClusterConfiguration -Cluster $cluster | Set-VsanClusterConfiguration -ProactiveRebalanceEnabled $true -Confirm:$false

# Enable Storage Performance Service
Get-VsanClusterConfiguration -Cluster $cluster | Set-VsanClusterConfiguration -PerformanceServiceEnabled $true


  if((Get-Cluster $cluster | Get-VMHost).count -le 3)
  {# configure settings specific to clusters with 3 or less nodes 

    # If vSan Cluster has 3 or less hosts enable Allow Reduced Redundancy. This allows host to be placed in maintainenace mode, as per vmware recs
    Get-VsanClusterConfiguration -Cluster $cluster | Set-VsanClusterConfiguration -AllowReducedRedundanc $true -Confirm:$false

    # Configure Default Storage Policy for Raid 1 vSan Clusters
    $datastore = Get-Cluster $cluster | Get-Datastore $vsan_name | Get-SpbmEntityConfiguration
    $vsan_policy = Get-SpbmStoragePolicy -Name $vsan_default_storage_policy_raid_1

    $datastore | Set-SpbmEntityConfiguration -StoragePolicy $vsan_policy
    Write-host "less than 3 host detected applying appropriate vsan storage policies" -ForegroundColor Green

  }
  else 
  {# Configure Default Storage Policy for Raid 5 vSan Clusters with 4 or more hosts
    $datastore = Get-Cluster $cluster | Get-Datastore $vsan_name | Get-SpbmEntityConfiguration
    $vsan_policy = Get-SpbmStoragePolicy -Name $vsan_default_storage_policy_raid_5

    $datastore | Set-SpbmEntityConfiguration -StoragePolicy $vsan_policy
    Get-VsanClusterConfiguration -Cluster $cluster | Set-VsanClusterConfiguration -AllowReducedRedundanc $false -Confirm:$false
    Write-Host 'More than 3 host detected applying appropriate polices' -ForegroundColor Green
      
  }

# Remove standard switch

foreach($esx in $vmhosts)
{# Remove standard switch if present
        Get-VMHost $esx | Get-VirtualSwitch | Where {$_.name -eq 'vswitch0'} | Remove-VirtualSwitch -Confirm:$false
}




