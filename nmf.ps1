# Configuration
$targetDirectory = "D:\Setups or somethin'"
$testlimitUrl = "https://live.sysinternals.com/notmyfaultc64.exe"
$testlimitPath = "$targetDirectory\notmyfault64.exe"
$testArgs = "hang 0x01 -accepteula"  # Added -accepteula to accept EULA automatically

# Ensure directory exists
if (-Not (Test-Path -Path $targetDirectory)) {
    Write-Host "Creating directory: $targetDirectory"
    try {
        New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
    } catch {
        Write-Error "Failed to create directory: $_"
        exit 1
    }
}

# Download
try {
    Write-Host "Downloading Testlimit from $testlimitUrl..."
    Invoke-WebRequest -Uri $testlimitUrl -OutFile $testlimitPath
    Write-Host "Downloaded successfully to $testlimitPath"
} catch {
    Write-Error "Failed to download: $_"
    exit 1
}

# Run with arguments
try {
    Write-Host "Running Testlimit with arguments: $testArgs"
    Start-Process -FilePath $testlimitPath -ArgumentList $testArgs -Wait -NoNewWindow
    Write-Host "Test completed."
} catch {
    Write-Error "Error during execution: $_"
}

# Cleanup
try {
    Write-Host "Cleaning up: deleting $testlimitPath"
    Remove-Item -Path $testlimitPath -Force
    Write-Host "Cleanup done."
} catch {
    Write-Error "Cleanup failed: $_"
}
