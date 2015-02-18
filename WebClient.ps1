
<# 
Script Name: WebClient.ps1
Version: 1.2

.Description
Iterates through a list of network appliances from the equipment.config file
and fetches update/upgrade manifests for each appliance.  Downloads each update/upgrade from the manifest.
Adds all updates/upgrades to an archive file and moves archive to IIS server so appliances can access them.

Author: Johnny Wagner
Date: 12/7/2014
Email: johnny@johnnybu.com
#>

# PARAMETERS
[CmdletBinding()]
Param
(
    #Use this paramater to override the default Cisco update server.
    [Parameter(Mandatory=$False,Position=0)]
    [String]$ciscoServer="update-manifests.sco.cisco.com",

    #Use this switch to run the script in upgrade mode rather than update mode.
    [Switch]$Upgrade,

    #User this switch to turn on logging
    [Switch]$Logging
)

#End PARAMETERS

# VARIABLES

$versionNumber = "1.2"

# End VARIABLES

# FUNCTIONS

<#
Gets current operating directory
to be used with base path variable
#>
function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value;
    if($Invocation.PSScriptRoot)
    {
        $Invocation.PSScriptRoot;
    }
    Elseif($Invocation.MyCommand.Path)
    {
        Split-Path $Invocation.MyCommand.Path
    }
    else
    {
        $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf("\"));
    }
}

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

    if ((Test-Path $destination))
    {
        if ($cert -ne $null)
        {
            try {
                    
                    $result = Invoke-WebRequest -Uri $uri -Method "Get" -Certificate $cert
                    Set-Content $destination $result
            }
            catch 
            {
                $httpStatusCode = $_.Exception.Response.StatusCode
                if ($httpStatusCode -eq $http400)
                {

                }

            }

<#            try
            {
                
            }
            catch [System.Exception]
            {
                Write-Error "Error attempting to download the file from the server.  Check the supplied or default cisco update server URL." -Category "ConnectionError" -ErrorVariable "myError"
                Write-Log $myError[0].ToString()
                Exit
            } #>
        } 
        else
        {
            try
            {
                Invoke-WebRequest -Uri $uri -Method Get -OutFile $destination
            }
            catch [System.Exception]
            {
                Write-Error "Error attempting to download the file." -Category "ConnectionError" -ErrorVariable "myError"
                Write-Log $myError[0].ToString()
                Exit
            }
        }
    }
    else
    {
        Write-Log "File: $destination already exists.  Skipping download."
    }      
}

<#
Gets the md5 hash of the file to check and compares it against the
hash supplied by the manifest xml file.  If the file matches,
it writes a host message saying so.  If the file does not match,
it deletes the file.
#>
function Check-FileHash
{
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$fileToCheck,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$md5
    )

    $fileHash = Get-FileHash $fileToCheck -Algorithm MD5

    Write-Log ("Matching the file hash: ", $fileHash.Hash," to the supplied hash: $md5" -join "")

    #Check the given md5 hash against the file hash.  Delete file if hash is not a match.
    if($fileHash.Hash.ToString() -eq $md5)
    {
        Write-Log "File successfully verified."
    }
    else
    {
        Write-Log "Hash not matched.  Deleteing File."
        if(Test-Path $fileToCheck)
        {
            Remove-Item $fileToCheck
        }
    } 
}

# Set the base script path
$basePath=Get-ScriptDirectory

# dot source Logging function
. "$basePath\Logging.ps1"

# dot source the xml validation function
. "$basePath\XmlValidate.ps1"

#End FUNCTIONS

#SCRIPT MAIN

#Set up Logging if switch is used
if ($Logging)
{
    $loggingFilePreference="$basePath\Log\WebClient_Log.txt"
    $loggingPreference="continue"

    New-Item -ItemType "directory" -Path "$basePath\Log" -ErrorAction "Ignore"

    Write-Log "Logging turned on.  Setting variables."

    Write-Log "loggingFilePreference is $loggingFilePreference."

    Write-Log "loggingPreference is $loggingPreference."

    Write-Log "Creating log directory; $loggingFilePreference, if it does not exist."
}

Write-Log "WebClient started.  Version: $versionNumber."

Write-Log "basePath is $basePath."

# Path for all files to transfer to offline webserver at conclusion of script
$httpdPath = $basePath, "httpd" -join "\"

Write-Log "httpdPath is $httpdPath."

#Configuration file used for run-time parameters
Write-Log "Loading xml config file and validating the Xml."
[xml]$configFile = Test-Xml ($basePath, "equipment.config" -join "\") ($basePath, "equipment.xsd" -join "\")

## Fetch Server Update Manifest
foreach ($device in $configFile.Devices.Device)
{
    #Generate URL for Manifest Fetch
    If ($upgrade) 
    {
        $manifestType = "upgrade"
        $apps = "asyncos"

        Write-Log "Application is $apps."
    } 
    else 
    {
        for($i=0; $i -lt $device.Applications.Application.Length; $i++)
        {
            if($i -eq 0)
            {
                $apps = $device.Applications.Application[$i]
            }
            else
            {
                $apps += "," + $device.Applications.Application[$i]
            }
        }

        $manifestType = "update"

        Write-Log "Applications are $apps."
    }

    Write-Log "Manifest type is $manifestType."

    #build the uri for the manifest download
    $uri = "https://", $ciscoServer, "/fetch_manifest?", "&", $device.Type, "=", $device.SerialNumber, "&model=", $device.Model, "&apps=", $apps, "&release_tag=", $device.Version -join ""
    Write-Log "Manifest uri is $uri."

    ## Load the Client Certificate from the LocalMachine (all users) Windows Certificate Store by Name
    Write-Log "Loading the client pfx certificate."
    $cert = Get-PfxCertificate ($basePath, "OPS-275461.pfx" -join "\")

    # force SSLv3, instead of TLS 1.0
    [Net.ServicePointManager]::SecurityProtocol = "ssl3"

    # Set the location of the manifest file
    $manifestLocation = $basePath, '\manifests\', $device.Model, ".", $device.Version, ".", $manifestType, "_manifest.xml" -join ""
    Write-Log "The manifest location is $manifestLocation."

    #Create the Manifest directory
    New-Item $basePath"\manifests\" -ItemType "directory" -ErrorAction "Ignore"

    [int]$numberOfRetries = 3

    # Invoke the web request only if the certificate variable is not null
    Write-Log "Downloading the server manifest file."
    Get-FileFromServer $uri $manifestLocation $numberOfRetries $cert

    #End Fetch Server Update Manifest

    # Parse Server Update Manifest

    #loads manifest xml file in to memory
    [xml]$manifest = Get-Content $manifestLocation

    #traverses xml tree for file information and calls the Get-FileFromServer method for each file
    foreach ($application in $manifest.server_manifest.applications.application)
    {
        foreach ($component in $application.components.component)
        {
            foreach ($file in $component.files.file)
            {
			   # remove the file name
			   $winpath = Split-Path ($file.path -replace "/","\") -Parent
			   # make full OS directory path
			   $winpath = $httpdPath, '\', $winpath -join ""
			   
			   # make directories (quietly) if needed
			   New-Item $winpath -ItemType "Directory" -ErrorAction "Ignore"
								   
               $source = $file.scheme, '://', $file.server, '/', $file.path -join ""

			   $destination = $httpdPath, '\', $winpath, $file.file_version -join ""
               
			   Write-Log "Attempting to download the file from $source."

               Get-FileFromServer $source $destination $numberOfRetries
               
               #Only check md5 hash if this is an update
               if (!($Upgrade))
               {
                    Check-FileHash $destination $file.md5 
               }
               else
               {
                    Write-Log "File hash not checked for Upgrade manifest type."
               }
            }    
        }
    }# End Parse Server Manifest 
	
	# copy manifest file to the httpd base directory with the update url replaced
	$newmanifestLocation = $httpdPath, "\", $device.SerialNumber , "_", $manifestType , ".xml" -join ""
	Get-Content $manifestLocation | ForEach-Object {$_ -replace "updates.ironport.com", "dc.chiefmx.com"} | Set-Content $newmanifestLocation

} # End Parse equipment Config file

Write-Log "Webclient script completed successfully."
Exit


# END SCRIPT MAIN