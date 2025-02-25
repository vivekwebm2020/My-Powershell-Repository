function Publish-AzureService
{
    <#
    .Synopsis
        Publishes one or more modules as azure services
    .Description
        Publishes one or more modules as azure services, according to the DomainSchematic found in the Pipeworks manifest
    .Example
        Get-Module Pipeworks | 
            Publish-AzureService
    .Link
        Out-AzureService
    #>
    [OutputType([IO.FileInfo])]
    param(
    # The name of the module
    [ValidateScript({
        if ($psVersionTable.psVersion -lt '3.0') {
            if (-not (Get-Module $_)) {
                throw "Module $_ must be loaded"            
            }
        }        
        return $true
    })]        
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='LoadedModule',ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [Alias('Module')]
    [string[]]
    $Name,
    
    # The VMSize of the deployment
    [ValidateSet('ExtraSmall','Small','Medium', 'Large', 'Extra-Large', 'XS', 'XL', 'S', 'M', 'L')]
    [string]
    $VMSize = 'ExtraSmall',
    
    # The name of the deployment   
    [string]
    $DeploymentName = 'MyPipeworksService',
    
    # If set, deletes local deployments after packaging.
    [Switch]
    $CleanupAfterDeployment,
    
    # The instance count
    [Uint32]
    $InstanceCount = 1,

    [Switch]
    $AsJob,

    [Switch]
    $Wait

    )
    
    begin {
        $progId = Get-Random
        $serviceDirectories = @()
        $azureServiceDefinition = New-AzureServiceDefinition -ServiceName $DeploymentName |
            Add-AzureRole -RoleName $DeploymentName -VMSize $vmSize
        $moduleNAmes = @()

        $jobs = @()
    }
    
    process {
        $moduleNAmes  += $name                        
    }
    
    end {
        $c = 0 
        foreach ($moduleName in $moduleNames) {
            if ($psVersionTable.PSVersion -ge '3.0') {
                $myModulePath = $env:PSModulePath -split ";" | Select-Object -First 1
                $moduleRoot = Join-Path $myModulePath $moduleName
            } else {
                $RealModule = Get-Module $moduleName
                $moduleList = @($RealModule.RequiredModules | 
                        Select-Object -ExpandProperty Name) + $realModule.Name

                $perc  =($c / $moduleNames.Count) * 100
                $c++
                Write-Progress "Publishing Modules" "$moduleName" -PercentComplete $perc -Id $progId 
                $module = Get-Module $moduleName
                if ($module.Path -like "*.ps1") {
                    continue
                }
                $moduleRoot = $module | Split-Path | Select-Object -First 1 
                
            }
            $manifestPath = "$moduleRoot\$($modulename).pipeworks.psd1"
            $pipeworksManifestPath = Join-Path $moduleRoot "$($moduleName).Pipeworks.psd1"
            
            
            $pipeworksManifest = 
                if (Test-Path $pipeworksManifestPath) {
                    try {                     
                        & ([ScriptBlock]::Create(
                            "data -SupportedCommand Add-Member, New-WebPage, New-Region, Write-CSS, Write-Ajax, Out-Html, Write-Link { $(
                                [ScriptBlock]::Create([IO.File]::ReadAllText($pipeworksManifestPath))                    
                            )}"))            
                    } catch {
                        Write-Error "Could not read pipeworks manifest for $moduleName" 
                    }                                                
                }


            if (-not $pipeworksManifest) {
                Write-Error "No Pipeworks manifest found for $moduleName"
                continue
            }
            
            
            
            if (-not $pipeworksManifest.DomainSchematics) {
                Write-Error "Domain Schematics not found for $moduleName"
                continue
            }

            $moduleServiceParameters = @{
                Name = $moduleName
            }

            
            if ($pipeworksManifest.PublishDirectory) {
                $baseName = $pipeworksManifest.PublishDirectory
            } else {
                $baseName = "${env:SystemDrive}\inetpub\wwwroot\$moduleName" 
            }
            
            
            
            
            foreach ($domainSchematic in $pipeworksManifest.DomainSchematics.GetEnumerator()) {
                if ($pipeworksManifest.AllowDownload) {
                    $moduleServiceParameters.AllowDownload = $true
                }                                
                $domains = $domainSchematic.Key -split "\|" | ForEach-Object { $_.Trim() }
                $schematics = $domainSchematic.Value
                
                if ($schematics -ne "Default") {
                    $moduleServiceParameters.OutputDirectory = "$baseName.$($schematics -join '.')"
                    $moduleServiceParameters.UseSchematic = $schematics                
                } else {
                    $moduleServiceParameters.OutputDirectory = "$baseName"
                    $moduleServiceParameters.Remove('UseSchematic')
                }                


                

                
                if ($AsJob) {
                    if ($psVersionTable.PSVersion -ge '3.0') {
                        $convertScript = "
Import-Module Pipeworks
Import-Module $ModuleName
"
                    } else {
                        $convertScript = "
Import-Module Pipeworks
Import-Module '$($moduleList -join "','")';"
                    }
                    
                $convertScript  += "
`$ModuleServiceParameters = "
                $convertScript  += $moduleServiceParameters | Write-PowerShellHashtable
                $convertScript  += "
ConvertTo-ModuleService @moduleServiceParameters -Force"
                
                    $convertScript = [ScriptBlock]::Create($convertScript)
                    Write-Progress "Launching Jobs" "$modulename"
                    $jobs += Start-Job -Name $moduleName -ScriptBlock $convertScript
                } else {
                    
                    ConvertTo-ModuleService @moduleServiceParameters -Force
                }
                


                $serviceDirectories += $moduleServiceParameters.OutputDirectory 
                $azureServiceDefinition = $azureServiceDefinition | 
                    Add-AzureWebSite -SiteName "$($moduleName).$($schematics -join '.')" -PhysicalDirectory $moduleServiceParameters.OutputDirectory -HostHeader $domains
            }   
            
            
            if ($pipeworksManifest.DomainCommands) {
                foreach ($domainCommands in $pipeworksManifest.DomainCommands.GetEnumerator()) {
                    $domains = $domainCommands.Key -split "\|" | ForEach-Object { $_.Trim() }
                    $cmdName = $domainCommands.Value
                    
                    $moduleServiceParameters.StartOnCommand = $cmdName
                    $moduleServiceParameters.OutputDirectory = "$baseName.$($cmdName)"
                    ConvertTo-ModuleService @moduleServiceParameters -Force
                    $serviceDirectories += $moduleServiceParameters.OutputDirectory 
                    $azureServiceDefinition = $azureServiceDefinition | 
                        Add-AzureWebSite -SiteName "$($moduleName).$($cmdName)" -PhysicalDirectory $moduleServiceParameters.OutputDirectory -HostHeader $domains
                }
            }
        }
        
                
        if ((-not $asJob) -or ($AsJob -and $Wait)) {

            $Activity = "Build $DeploymentName"
            $runningJobs = $jobs | 
                Where-Object { $_.State -eq "Running" }
        
            while ($runningJobs) {
                $runningJobs = @($jobs | 
                    Where-Object { $_.State -eq "Running" })
                $jobs | Wait-Job -Timeout 1 | Out-Null
                $jobs | 
                    Receive-Job             

                $percent = 100 - ($runningJobs.Count * 100 / $jobs.Count)
            
                Write-Progress "Waiting for $Activity to Complete" "$($Jobs.COunt - $runningJobs.Count) out of $($Jobs.Count) Completed" -PercentComplete $percent
            
                    
            }

            Write-Progress "Creating Deployment Package" "$DeploymentName" -Id $progId -PercentComplete 100
            if ($serviceDirectories) {
                $azureServiceDefinition |
                    Out-AzureService -OutputPath "$home\Documents\$DeploymentName" -InstanceCount $InstanceCount
            }
        
        
            if ($CleanupAfterDeployment) {
                foreach ($s in $serviceDirectories) {
                    Remove-Item -Path $s -Recurse -Force
                }
            } else {
                Write-Progress "Creating Deployment Package" "$DeploymentName" -Id $progId -Completed
            }

        }
                
        
        
        
    }
} 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrO1l6hGdw0ARqVCgrxHEZ62V
# /ZegggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFILa1rXuFtp2h5DF
# UUBp6TfLBB0aMA0GCSqGSIb3DQEBAQUABIIBAAg5tgNqVdhE1vKZv1y+4aNREX5I
# rABjMT5JYdt96nqqJEU3B7WHa8TllJrW7opqV19CbhHlVWX8TT+FS63JMkKkpVCX
# iqF1ut8NfY02utcB2nf/Bvtp8lIVpX79QnnZE+7QPoVlUDngbMzybxHPvTLrW6Zj
# T3zCZeLSpVFQ9IP+Jq8oEtIDodI3lwvYGzcHifbi8/sNK5DixZ1GUkrs1w5WWWLO
# Xn5BnsHIspUu8qKwTIYPIW7ssed6Gs2xrb8PLdTBStQVNrj8Opy43pq5O7rvuS76
# vx+hk9GbW4TTMvl0w3U0Uqx6/qySCT/sM70cMMTdGlDLu8LJdd5LDxAs0qY=
# SIG # End signature block
