$script:Results = @()

function Add-Result {
    param(
        [string]$Task,
        [bool]$Passed,
        [string]$Details = ""
    )

    if ($Passed) {
        Write-Host "$Task - PASSED" -ForegroundColor Green
    }
    else {
        if ($Details) {
            Write-Host "$Task - FAILED - $Details" -ForegroundColor Red
        }
        else {
            Write-Host "$Task - FAILED" -ForegroundColor Red
        }
    }

    $script:Results += [PSCustomObject]@{
        Task   = $Task
        Status = if ($Passed) { "PASSED" } else { "FAILED" }
        Details = $Details
    }
}

#########################################################
# Task: Review Exports Folder
#########################################################

$ExportFolder = "D:\Programfiles\Apache\Tomcat 9.0\webapps\root\files\export"

try {
    Add-Result "Review Exports Folder" (Test-Path $ExportFolder) "Folder not found"
}
catch {
    Add-Result "Review Exports Folder" $false $_.Exception.Message
}

#########################################################
# Task: Apache (Tomcat9) Service
#########################################################

try {

    $svc = Get-Service -Name "Tomcat9" -ErrorAction Stop

    $startup = (Get-CimInstance Win32_Service -Filter "Name='Tomcat9'").StartMode

    $passed = ($svc.Status -eq "Running") -and ($startup -eq "Auto")

    Add-Result "Apache Service Running" $passed "Status=$($svc.Status), Startup=$startup"

}
catch {
    Add-Result "Apache Service Running" $false $_.Exception.Message
}

#########################################################
# Task: Amazon CloudWatch Agent
#########################################################

try {

    $svc = Get-Service -Name "AmazonCloudWatchAgent" -ErrorAction Stop

    Add-Result "CloudWatch Agent Running" ($svc.Status -eq "Running") "Status=$($svc.Status)"

}
catch {
    Add-Result "CloudWatch Agent Running" $false $_.Exception.Message
}

#########################################################
# Task: Review Tomcat Memory
#########################################################

try {

    $regPath = "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat9\Parameters\Java"

    if (!(Test-Path $regPath)) {
        throw "Tomcat registry not found."
    }

    $props = Get-ItemProperty $regPath

    $JvmMs = [int]$props.JvmMs
    $JvmMx = [int]$props.JvmMx

    $passed = ($JvmMs -ge 4096) -and ($JvmMx -ge 6144)

    Add-Result "Review Min/Max Memory" $passed "JvmMs=$JvmMs MB, JvmMx=$JvmMx MB"

}
catch {
    Add-Result "Review Min/Max Memory" $false $_.Exception.Message
}

#########################################################
# Task: Review Java Options
#########################################################

try {

    $regPath = "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat9\Parameters\Java"

    if (!(Test-Path $regPath)) {
        throw "Tomcat registry not found."
    }

    $props = Get-ItemProperty $regPath

    $options = @()

    if ($props.Options) {
        $options += $props.Options
    }

    if ($props.Options9) {
        $options += $props.Options9
    }

    $requiredOption = "-Ddeenv:env:test"

    $passed = $options -contains $requiredOption

    Add-Result "Review Java Options" $passed "Required option missing"

}
catch {
    Add-Result "Review Java Options" $false $_.Exception.Message
}

#########################################################
# Task: Check LOCAL SERVICE Permissions
#########################################################

try {

    $Folder = "D:\Programfiles\Apache\Tomcat 9.0\webapps\root"

    if (!(Test-Path $Folder)) {
        throw "Folder not found."
    }

    $acl = Get-Acl $Folder

    $found = $false

    foreach ($ace in $acl.Access) {

        if (
            $ace.IdentityReference.Value -match "LOCAL SERVICE" -and
            $ace.FileSystemRights.ToString().Contains("FullControl") -and
            $ace.InheritanceFlags.ToString().Contains("ContainerInherit") -and
            $ace.InheritanceFlags.ToString().Contains("ObjectInherit")
        ) {
            $found = $true
            break
        }
    }

    Add-Result "LOCAL SERVICE Permissions" $found "LOCAL SERVICE Full Control (OI)(CI) not found"

}
catch {
    Add-Result "LOCAL SERVICE Permissions" $false $_.Exception.Message
}

#########################################################
# Task: Check Required Log Files
#########################################################

try {

    $logChecks = @(
        "D:\Apache\Tomcat 9.0\logs\stdout*.log",
        "D:\Apache\Tomcat 9.0\logs\stderror*.log",
        "D:\Apache\Tomcat 9.0\logs\catalina.log",
        "D:\Apache\Tomcat 9.0\logs\localhost_access.log"
    )

    $missing = @()

    foreach ($pattern in $logChecks) {

        if (-not (Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue)) {
            $missing += $pattern
        }
    }

    if ($missing.Count -eq 0) {
        Add-Result "Check Log Files Exist" $true
    }
    else {
        Add-Result "Check Log Files Exist" $false ("Missing: " + ($missing -join ", "))
    }

}
catch {
    Add-Result "Check Log Files Exist" $false $_.Exception.Message
}

#########################################################
# Task: Review Logs for Errors
#########################################################

try {

    $logFolder = "D:\Apache\Tomcat 9.0\logs"

    $keywords = @(
        "access denied",
        "not found",
        "warning",
        "error",
        "failed",
        "runtime mismatch"
    )

    $matches = @()

    Get-ChildItem $logFolder -File | ForEach-Object {

        $found = Select-String `
            -Path $_.FullName `
            -Pattern $keywords `
            -SimpleMatch `
            -ErrorAction SilentlyContinue

        if ($found) {

            $matches += $_.FullName

            Write-Host ""
            Write-Host "Issues found in:" -ForegroundColor Yellow
            Write-Host $_.FullName -ForegroundColor Cyan

            $found |
                Select-Object -First 10 |
                ForEach-Object {
                    Write-Host ("Line {0}: {1}" -f $_.LineNumber, $_.Line.Trim())
                }
        }

    }

    if ($matches.Count -eq 0) {
        Add-Result "Review Log Errors" $true
    }
    else {
        Add-Result "Review Log Errors" $false ("Errors found in $($matches.Count) log(s)")
    }

}
catch {
    Add-Result "Review Log Errors" $false $_.Exception.Message
}

#########################################################
# Task: Validate Application URL
#########################################################

try {

    $hostname = $env:COMPUTERNAME.ToLower()

    if ($hostname.StartsWith("pd")) {
        $url = "http://prod.testdomain.org/index.html"
    }
    elseif ($hostname.StartsWith("ts")) {
        $url = "http://test.testdomain.org/index.html"
    }
    else {
        $url = "http://nonimpl.testdomain.org/index.html"
    }

    $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30

    $passed = ($response.StatusCode -eq 200) -and
              ($response.Headers.'Content-Type' -match 'text/html')

    if ($passed) {
        Add-Result "Validate Application URL" $true
    }
    else {
        Add-Result "Validate Application URL" $false `
            "URL=$url Status=$($response.StatusCode) ContentType=$($response.Headers.'Content-Type')"
    }

}
catch {
    Add-Result "Validate Application URL" $false $_.Exception.Message
}

#########################################################
# Summary
#########################################################

Write-Host ""
Write-Host "==================== Summary ====================" -ForegroundColor Cyan

$Results | Format-Table -AutoSize

$failed = @($Results | Where-Object Status -eq "FAILED")

Write-Host ""
Write-Host ("Passed : {0}" -f ($Results.Count - $failed.Count))
Write-Host ("Failed : {0}" -f $failed.Count)
