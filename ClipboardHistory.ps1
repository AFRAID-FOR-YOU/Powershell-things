<#
.SYNOPSIS
    Enhanced clipboard history retrieval with better error handling and diagnostics
.DESCRIPTION
    Attempts to retrieve full clipboard history (Win+V), falls back to last item,
    and provides detailed information about why full history might not be available.
#>

function Get-EnhancedClipboardHistory {
    [CmdletBinding()]
    param()

    # Diagnostic information collection
    $diagnostics = @{
        WindowsVersion = [Environment]::OSVersion.Version
        ClipboardHistorySupported = $false
        ClipboardHistoryEnabled = $false
        HistoryAccessAttempted = $false
        HistoryAccessSuccessful = $false
        FallbackUsed = $false
        ErrorMessages = @()
    }

    # Check Windows version support
    $diagnostics.ClipboardHistorySupported = [Environment]::OSVersion.Version -ge [Version]"10.0.17763"

    if ($diagnostics.ClipboardHistorySupported) {
        try {
            # Check registry setting
            $clipboardSettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Clipboard" -ErrorAction SilentlyContinue
            $diagnostics.ClipboardHistoryEnabled = $clipboardSettings -and $clipboardSettings.EnableClipboardHistory -eq 1
            
            if ($diagnostics.ClipboardHistoryEnabled) {
                $diagnostics.HistoryAccessAttempted = $true
                
                # Load required assemblies
                try {
                    Add-Type -AssemblyName System.Runtime.WindowsRuntime
                    $null = [Windows.ApplicationModel.DataTransfer.Clipboard, Windows.ApplicationModel.DataTransfer, ContentType = WindowsRuntime]
                    
                    # Get history items
                    $clipboardHistory = [Windows.ApplicationModel.DataTransfer.Clipboard]::GetHistoryItemsAsync().GetAwaiter().GetResult()
                    $diagnostics.HistoryAccessSuccessful = $true
                    
                    if ($clipboardHistory.Items.Count -gt 0) {
                        $results = @()
                        $clipboardHistory.Items | ForEach-Object -Begin { $i = 1 } -Process {
                            $item = $_
                            try {
                                $content = $item.Content.GetTextAsync().GetAwaiter().GetResult()
                            } catch {
                                $content = "[Non-text content]"
                            }
                            
                            $results += [PSCustomObject]@{
                                Index = $i++
                                Timestamp = $item.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                                Content = $content
                                Source = "ClipboardHistory"
                            }
                        }
                        return [PSCustomObject]@{
                            Items = $results
                            Diagnostics = $diagnostics
                        }
                    }
                } catch {
                    $diagnostics.ErrorMessages += "History access failed: $_"
                }
            }
        } catch {
            $diagnostics.ErrorMessages += "Registry access failed: $_"
        }
    }

    # Fallback to standard clipboard
    $diagnostics.FallbackUsed = $true
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $content = if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            [System.Windows.Forms.Clipboard]::GetText()
        } else {
            "[Non-text content]"
        }
        
        $result = [PSCustomObject]@{
            Index = 1
            Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            Content = $content
            Source = "LastItemFallback"
        }
        
        return [PSCustomObject]@{
            Items = @($result)
            Diagnostics = $diagnostics
        }
    } catch {
        $diagnostics.ErrorMessages += "Fallback failed: $_"
        return [PSCustomObject]@{
            Items = $null
            Diagnostics = $diagnostics
        }
    }
}

# Retrieve and display results
$result = Get-EnhancedClipboardHistory

# Display diagnostics if only got last item or failed
if ($result.Items.Count -le 1 -or $result.Items[0].Source -eq "LastItemFallback") {
    Write-Host "`n[!] Could only retrieve last clipboard item. Diagnostics:" -ForegroundColor Yellow
    $result.Diagnostics.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0}: {1}" -f $_.Name.PadRight(25), $_.Value)
    }
    
    if ($result.Diagnostics.ErrorMessages) {
        Write-Host "`nError Details:" -ForegroundColor Red
        $result.Diagnostics.ErrorMessages | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
    }
    
    Write-Host "`nPossible Solutions:" -ForegroundColor Cyan
    Write-Host "1. Ensure you're running Windows 10 1809 or later"
    Write-Host "2. Enable Clipboard History in Settings > System > Clipboard"
    Write-Host "3. Run this in an elevated PowerShell session if registry access is blocked"
    Write-Host "4. Check if your organization has restricted clipboard access via policy"
}

# Display the actual content
if ($null -ne $result.Items) {
    Write-Host "`nClipboard Content:" -ForegroundColor Green
    $result.Items | Format-Table -AutoSize
}
