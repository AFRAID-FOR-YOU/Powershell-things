# Check if the process "controller.exe" is running
$process = Get-Process -Name "controller" -ErrorAction SilentlyContinue

if ($null -eq $process) {
    Write-Output "controller.exe is not running."
} else {
    # Get the process ID
    $pid = $process.Id

    # Get the process token to check if it has admin rights
    $hasAdminRights = (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$pid" |
        ForEach-Object {
            $procHandle = (Get-Process -Id $_.ProcessId).Handle
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
            $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        })

    if ($hasAdminRights) {
        Write-Output "controller.exe is running with administrator privileges."
    } else {
        Write-Output "controller.exe is running WITHOUT administrator privileges."
    }
}
