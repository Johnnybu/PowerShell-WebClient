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
        [System.Security.Cryptography.X509Certificates.X509Certificate]$cert
    )

    $http200 = 200
    $http400 = 400
    $http404 = 404
    $http500 = 500

    do
    {
        if ($cert -ne $null)
        {
            try {
                    
                    $result = Invoke-WebRequest -Uri $uri -Method "Get" -Certificate $cert
                    Set-Content $destination $result.Content
            }
            catch 
            {
                $serverErrorMessage = "Error:", $_.Exception, "  Details:", $_.ErrorDetails.Message -join ""
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
    }while(($numberOfRetries -gt 0) -and ($result.Response.StatusCode -ne $http200))
}