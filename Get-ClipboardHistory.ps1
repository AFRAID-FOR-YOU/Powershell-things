<#
.SYNOPSIS
    Retrieves items from Windows Clipboard History (Win+V) or falls back to the last item.
.DESCRIPTION
    This script first tries to access the full Clipboard History (Win+V feature).
    If that fails, it falls back to returning just the last clipboard item.
.NOTES
    File Name      : Get-ClipboardContent.ps1
    Prerequisite   : PowerShell 5.1 or later
    Requires Admin : No
#>

function Get-ClipboardContent {
    [CmdletBinding()]
    param()

    # Try to get full clipboard history first
    try {
        # Check if Clipboard History is available (Windows 10 1809+)
        if ([Environment]::OSVersion.Version -ge [Version]"10.0.17763") {
            # Check if Clipboard History is enabled
            $clipboardSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -ErrorAction SilentlyContinue
            if ($clipboardSettings -and $clipboardSettings.EnableClipboardHistory -eq 1) {
                # Load required Windows Runtime assemblies
                Add-Type -AssemblyName System.Runtime.WindowsRuntime

                # Get the clipboard history
                $null = [Windows.ApplicationModel.DataTransfer.Clipboard, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime]
                $clipboardHistory = [Windows.ApplicationModel.DataTransfer.Clipboard]::GetHistoryItemsAsync().GetAwaiter().GetResult()

                if ($clipboardHistory.Items.Count -gt 0) {
                    $results = @()
                    $clipboardHistory.Items | ForEach-Object -Begin { $i = 1 } -Process {
                        $item = $_
                        
                        try {
                            $content = $item.Content.GetTextAsync().GetAwaiter().GetResult()
                        } catch {
                            $content = "[Non-text content]"
                        }
                        
                        $timestamp = $item.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                        
                        $results += [PSCustomObject]@{
                            "Index"     = $i++
                            "Timestamp" = $timestamp
                            "Content"   = $content
                        }
                    }
                    return $results
                }
            }
        }
    } catch {
        Write-Verbose "Failed to access clipboard history: $_"
    }

    # Fallback to getting just the last clipboard item
    try {
        Add-Type -AssemblyName System.Windows.Forms
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $lastItem = [System.Windows.Forms.Clipboard]::GetText()
            return [PSCustomObject]@{
                "Index"     = 1
                "Timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                "Content"   = $lastItem
            }
        } else {
            return [PSCustomObject]@{
                "Index"     = 1
                "Timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                "Content"   = "[Non-text content]"
            }
        }
    } catch {
        Write-Error "Failed to access clipboard content: $_"
        return $null
    }
}

# Call the function and display results
$clipboardItems = Get-ClipboardContent

if ($null -eq $clipboardItems) {
    Write-Output "Unable to access clipboard content."
} elseif ($clipboardItems.Count -eq 1) {
    Write-Output "Clipboard History unavailable. Showing last clipboard item:"
    $clipboardItems
} else {
    Write-Output "Clipboard History Items (Win+V):`n"
    $clipboardItems
}
