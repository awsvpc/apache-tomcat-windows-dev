$RegistryPath = "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat9\Parameters"
$OutputFile = "C:\Temp\RegistryExport.txt"

Get-ChildItem -Path $RegistryPath -Recurse | ForEach-Object {

    Add-Content $OutputFile "=================================================="
    Add-Content $OutputFile "Key: $($_.Name)"

    try {
        $props = Get-ItemProperty $_.PSPath

        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -notmatch '^PS') {
                Add-Content $OutputFile ("{0} = {1}" -f $prop.Name, $prop.Value)
            }
        }
    }
    catch {
        Add-Content $OutputFile "Unable to read values."
    }

    Add-Content $OutputFile ""
}
