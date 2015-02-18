function Test-Xml {
    param (
    [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
        [string] $XmlFile,

        [Parameter(Mandatory=$true)]
        [string] $SchemaFile
    )

    [string[]]$Script:XmlValidationErrorLog = @()
    [scriptblock] $ValidationEventHandler = {
        $Script:XmlValidationErrorLog += $args[1].Exception.Message
    }

    $xml = New-Object System.Xml.XmlDocument
    $schemaReader = New-Object System.Xml.XmlTextReader $SchemaFile
    $schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $ValidationEventHandler)
    $xml.Schemas.Add($schema) | Out-Null
    $xml.Load($XmlFile)
    $xml.Validate($ValidationEventHandler)

    if ($Script:XmlValidationErrorLog) {
        Write-Warning "$($Script:XmlValidationErrorLog.Count) errors found"
        Write-Error "$Script:XmlValidationErrorLog"
        Exit
    }
    else {
        Write-Log "The script is valid"
        Return $xml
    }
}