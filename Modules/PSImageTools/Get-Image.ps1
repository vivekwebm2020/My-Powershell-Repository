function Get-Image {
    <#
    .Synopsis
        Gets information about images.

    .Description
        Get-Image gets an object that represents each image file. 
        The object has many properties and methods that you can use to edit images in Windows PowerShell. 

    .Notes
        Get-Image uses Wia.ImageFile, a Windows Image Acquisition COM object to get image data.
        Then it uses the Add-Member cmdlet to add note properties and script methods to the object. 

        The Resize script method uses the Add-ScaleFilter function. It has the following syntax:
        Resize ($width, $height, [switch]$DoNotPreserveAspectRation). 
        Width and Height can be specified in pixels or percentages. 
        For a description of these parameters, type "get-help Add-ScaleFilter –par *".

        The Crop script method uses the uses the Add-CropFilter function. It has the following syntax:
        Crop ([Double]$left, [Double]$top, [Double]$right, [Double]$bottom).
        All dimensions are measured in pixels.
        For a description of these parameters, type "get-help Add-CropFilter –par *".

        The FlipVertical, FlipHorizontal, RotateClockwise and RotateCounterClockwise script methods use the Add-RotateFlipFilter function.
        For a description of these parameters, type "get-help Add-RotateFlipFilter –par *".

    .Parameter File
        [Required] Specifies the image files. Enter the path and file name of an image file, such as $home\pictures\MyPhoto.jpg.
        You can also pipe one or more image files to Get-Image, such as those from Get-Item or Get-Childitem (dir). 

    .Example
        Get-Image –file C:\myPics\MyPhoto.jpg

    .Example
        Get-ChildItem $home\Pictures -Recurse | Get-Image        

    .Example
        (Get-Image –file C:\myPics\MyPhoto.jpg).resize(80, 120)

    .Example
        # Crops 8 pixels from the top of the image.
        $CatPhoto = Get-Image –file $home\Pictures\Cat.jpg
        $CatPhoto.crop(0,8,0,0)

    .Example
        $CatPhoto = Get-Image –file $home\Pictures\Cat.jpg
        $CatPhoto.flipvertical()

    .Example
        dir $home\pictures\Vacation*.jpg | get-image | format-table fullname, horizontalResolution, PixelDepth –autosize

    .Link
        "Image Manipulation in PowerShell": http://blogs.msdn.com/powershell/archive/2009/03/31/image-manipulation-in-powershell.aspx
    .Link
        Add-CropFilter
    .Link
        Add-ScaleFilter
    .Link
        Add-RotateFlipFilter
    .Link
        Get-ImageProperties
    #>
    param(    
    [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true)]
    [Alias('FullName')]
    [string]$file)
    
    process {
        $realItem = Get-Item $file -ErrorAction SilentlyContinue     
        if (-not $realItem) { return }
        $image  = New-Object -ComObject Wia.ImageFile        
        try {        
            $image.LoadFile($realItem.FullName)
            $image | 
                Add-Member NoteProperty FullName $realItem.FullName -PassThru | 
                Add-Member ScriptMethod Resize {
                    param($width, $height, [switch]$DoNotPreserveAspectRatio)                    
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-ScaleFilter @psBoundParameters -passThru -image $image
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru | 
                Add-Member ScriptMethod Crop {
                    param([Double]$left, [Double]$top, [Double]$right, [Double]$bottom)
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-CropFilter @psBoundParameters -passThru -image $image
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru | 
                Add-Member ScriptMethod FlipVertical {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -flipVertical -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru | 
                Add-Member ScriptMethod FlipHorizontal {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -flipHorizontal -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru |
                Add-Member ScriptMethod RotateClockwise {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -angle 90 -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru |
                Add-Member ScriptMethod RotateCounterClockwise {
                    $image = New-Object -ComObject Wia.ImageFile
                    $image.LoadFile($this.FullName)
                    $filter = Add-RotateFlipFilter -angle 270 -passThru 
                    $image = $image | Set-ImageFilter -filter $filter -passThru
                    Remove-Item $this.Fullname
                    $image.SaveFile($this.FullName)                    
                } -PassThru 
                
        } catch {
            Write-Verbose $_
        }
    }    
}  

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhPLjSVTutuSb5UclxVujVNLw
# xxugggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
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
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFJqkH2WO9zYZN8wF
# Jc9iPQGikqs6MA0GCSqGSIb3DQEBAQUABIIBAKT+5JXLjLNKME9H+z1ERcO61dmF
# rJJ37An6Mb5zjg5iNw4MvVtXg25eHXweTsewzogLezDymTbD0GXE+U+LcpamrQ4E
# DPE2AoxxrK7xjFXqNIPT8HsAwdmi055MpxP4RwmXvhu5OrNzXXaeYfBf7LKTs0rO
# EbASHk5HVPBSOyOZw+xymhPiSBQbe5x5EzXCAyP34RcDtMzmtVke4xa+lbyU4Qdl
# Cgex4xRz6xQrPYExwsDTIGZ+QAnuUcZfPT2LHDfg/lvOnvy0Gy+VsKtRq0iUAEqY
# g19jG8z4VfBWxJRh3G20srK7atKGfRSsGIqyglDXYngtbhVI4g4oKL7mCYE=
# SIG # End signature block
