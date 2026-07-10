$regPath = "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\Tomcat9\Parameters\Java"

if (!(Test-Path $regPath)) {
    Write-Host "Tomcat registry not found." -ForegroundColor Red
    exit 1
}

$props = Get-ItemProperty -Path $regPath

$JvmMs = [int]$props.JvmMs
$JvmMx = [int]$props.JvmMx

Write-Host "Current JvmMs: $JvmMs"
Write-Host "Current JvmMx: $JvmMx"

$updated = $false

if ($JvmMs -lt 4096) {
    Set-ItemProperty -Path $regPath -Name JvmMs -Value 4096
    Write-Host "Updated JvmMs to 4096" -ForegroundColor Yellow
    $updated = $true
}

if ($JvmMx -lt 6144) {
    Set-ItemProperty -Path $regPath -Name JvmMx -Value 6144
    Write-Host "Updated JvmMx to 6144" -ForegroundColor Yellow
    $updated = $true
}

if (-not $updated) {
    Write-Host "Memory settings already meet the required values." -ForegroundColor Green
}
else {
    Write-Host "Memory settings updated successfully." -ForegroundColor Green
}

# Display final values
$props = Get-ItemProperty -Path $regPath
Write-Host ""
Write-Host "Final JvmMs: $($props.JvmMs)"
Write-Host "Final JvmMx: $($props.JvmMx)"
