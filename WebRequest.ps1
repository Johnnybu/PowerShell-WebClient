<#
Downloads specified file from a web server
The certificate parameter is optional.
#>
function Get-FileFromServer
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$uri,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$destination,

        [Parameter(Mandatory=$true, Position=2)]
        [int]$numberOfRetries,

        [Parameter(Mandatory=$false, Position=3)]
        [System.Object[]]$cert
    )

    $http200 = 200
    $http400 = 400
    $http404 = 404
    $http500 = 500

    if($cert.Count -gt 1)
    {
        Write-Log "More than one matching certificate was found.  Attempting to download using each one.  Removing unused certificates from the Windows store is recommended."
        $numberOfRetries = $cert.Count
    }

    do
    {
        if ($cert.Count -gt 1)
        {
            [System.Security.Cryptography.X509Certificates.X509Certificate]$certifcate = $cert[$numberOfRetries - 1]
        }
        elseif ($cert.Count -eq 1)
        {
            [System.Security.Cryptography.X509Certificates.X509Certificate]$certifcate = $cert[0]
        }

        if ($certifcate -ne $null)
        {
            try {
                    
                    $result = Invoke-WebRequest -Uri $uri -Method "Get" -Certificate $certifcate
                    Set-Content $destination $result.Content
            }
            catch 
            {
                $serverErrorMessage = "Error:", $_.Exception, "Details:", $_.ErrorDetails.Message -join " "
                switch ($_.Exception.Response.StatusCode.value__)
                {
                
                    $http400 { if ($serverErrorMessage -like "*SSL certificate error*")
                               { Write-Log "Server returned SSL certificate error.  Retry attempts: $numberOfRetries"; $numberOfRetries--; Break; }
                               Write-Log "Bad web request.  Check the URL of the server supplied and try running the script again.  Server returned:$serverErrorMessage"
                               Write-Error "Bad web request.  Check the URL of the server supplied and try running the script again.  Server returned:$serverErrorMessage"
                               Exit; }

                    $http404 { Write-Log "Server returned status code 404.  Not Found.  Retry attempts: $numberOfRetries";
                               $numberOfRetries--;
                               Break; }

                    $http500 { Write-Log "Server returned status code 500.  Internal server error.  Retry attempts: $numberOfRetries";
                               $numberOfRetries--;
                               Break; }
                    default  { Write-Log "Web request error.  Server returned: $serverErrorMessage"
                               Write-Error "Web request error.  Server returned: $serverErrorMessage"
                               Exit; }

                }
            }
        } 
        else
        {
            try
            {
                $result = Invoke-WebRequest -Uri $uri -Method "Get"
                [io.file]::WriteAllBytes($destination,$result.Content)
            }
            catch
            {
                switch ($_.Exception.Response.StatusCode.value__)
                {
                
                    $http400 { Write-Log "Bad web request.  Check the URL of the server supplied and try running the script again.  Server returned:$serverErrorMessage"
                               Write-Error "Bad web request.  Check the URL of the server supplied and try running the script again.  Server returned:$serverErrorMessage"
                               Exit; }

                    $http404 { Write-Log "Server returned status code 404.  Not Found.  Retry attempts: $numberOfRetries";
                               $numberOfRetries--;
                               Break; }

                    $http500 { Write-Log "Server returned status code 500.  Internal server error.  Retry attempts: $numberOfRetries";
                               $numberOfRetries--;
                               Break; }
                    default  { Write-Log "Web request error.  Server returned: $serverErrorMessage"
                               Write-Error "Web request error.  Server returned: $serverErrorMessage"
                               Exit; }

                }
            }
        }
    }while(($numberOfRetries -gt 0) -and ($result.StatusCode -ne $http200))
}