#requires -version 2.0

# -----------------------------------------------------------------------------
# Script: Write-Log.ps1
# Version: 1.0
# Author: Jeffery Hicks
#    http://jdhitsolutions.com/blog
#    http://twitter.com/JeffHicks
# Date: 3/3/2011
# Keywords: Verbose, Logging
# Comments:
#
# "Those who neglect to script are doomed to repeat their work."
#
#  ****************************************************************
#  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
#  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
#  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
#  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
#  ****************************************************************
# -----------------------------------------------------------------------------

Function Write-Log {

<#
   .Synopsis
    Write a message to a log file. 
    .Description
    Write-Log can be used to write text messages to a log file. It can be used like Write-Verbose,
    and looks for two variables that you can define in your scripts and functions. If the function
    finds $LoggingPreference with a value of "Continue", the message text will be written to the file.
    The default file is PowerShellLog.txt in your %TEMP% directory. You can specify a different file
    path by parameter or set the $LoggingFilePreference variable. See the help examples.
    
    This function also supports Write-Verbose which means if -Verbose is detected, the message text
    will be written to the Verbose pipeline. Thus if you call Write-Log with -Verbose and a the 
    $loggingPreference variable is set to continue, you will get verbose messages AND a log file.
    .Parameter Message
    The message string to write to the log file. It will be prepended with a date time stamp.
    .Parameter Path
    The filename and path for the log file. The default is $env:temp\PowerShellLog.txt, 
    unless the $loggingFilePreference variable is found. If so, then this value will be
    used.
   .Example
    PS C:\> . c:\scripts\write-log.ps1
    
    Here is a sample function that uses the Write-Log function after it has been dot sourced. Within the sample 
    function, the logging variables are defined.
    
Function TryMe {
    [cmdletbinding()]
    Param([string]$computername=$env:computername,
    [string]$Log
    )
    if ($log) 
    {
     $loggingPreference="Continue"
     $loggingFilePreference=$log
    }
    Write-log "Starting Command"
    Write-log "Connecting to $computername"
    $b=gwmi win32_bios -ComputerName $computername
    $b
    Write-log $b.version
    Write-Log "finished" $log
}

TryMe -log e:\logs\sample.txt -verbose

  
   .Notes
    NAME: Write-Log
    AUTHOR: Jeffery Hicks
    VERSION: 1.0
    LASTEDIT: 03/02/2011
    
    Learn more with a copy of Windows PowerShell 2.0: TFM (SAPIEN Press 2010)
    
   .Link
   http://jdhitsolutions.com/blog/2011/03/powershell-automatic-logging/
    
    .Link
    Write-Verbose
    .Inputs
    None
    
    .Outputs
    None
#>

    [cmdletbinding()]

    Param(
    [Parameter(Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,
    [Parameter(Position=1)]
    [string]$Path="$env:temp\PowerShellLog.txt"
    )
    
    #Pass on the message to Write-Verbose if -Verbose was detected
    Write-Verbose -Message $Message
    
    #only write to the log file if the $LoggingPreference variable is set to Continue
    if ($LoggingPreference -eq "Continue")
    {
    
        #if a $loggingFilePreference variable is found in the scope
        #hierarchy then use that value for the file, otherwise use the default
        #$path
        if ($loggingFilePreference)
        {
            $LogFile=$loggingFilePreference
        }
        else
        {
            $LogFile=$Path
        }
        
        Write-Output "$(Get-Date) $Message" | Out-File -FilePath $LogFile -Append
    }

} #end function