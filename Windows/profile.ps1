oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\my-themes.omp.json" | Invoke-Expression

function bundle_sst {
	mkdir $HOME\AppData\Local\Temp\SST_Build\
	Robocopy .\src-tauri\target\release\Redistributables $HOME\AppData\Local\Temp\SST_Build\Redistributables /E
	cp .\src-tauri\target\release\service-support-tool.exe $HOME\AppData\Local\Temp\SST_Build\
	Compress-Archive $HOME\AppData\Local\Temp\SST_Build\* C:\Dev\SST_Build.zip -Force
	Remove-Item $HOME\AppData\Local\Temp\SST_Build -Recurse
}

function Invoke-MyCustomCD {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$InputArgs
    )

    # --- CONFIGURATION: Define your shortcuts here ---
    # Add as many shortcuts as you like in the format:
    # "keyword" = "C:\path\to\your\directory"
    # Ensure keywords are lowercase for case-insensitive matching.
    $shortcutMappings = @{
        "sst"  = "C:\Dev\service-support-tool"
        "sscada" = "C:\Dev\sscada"
        "dev" = "C:\Dev"
    }
    # --- END CONFIGURATION ---

    if ($InputArgs.Count -eq 1) {
        $potentialShortcut = $InputArgs[0].ToLower() # Convert input to lowercase for matching

        if ($shortcutMappings.ContainsKey($potentialShortcut)) {
            $targetPath = $shortcutMappings[$potentialShortcut]
            try {
                Set-Location -Path $targetPath -ErrorAction Stop
            }
            catch {
                Write-Warning "Error navigating to '$targetPath': $($_.Exception.Message)"
                Write-Warning "Please ensure the path is correct and you have access permissions."
            }
            return # Exit the function after handling the shortcut
        }
    }

    # If not a recognized shortcut, or if there are other arguments,
    # or no arguments, pass them to the original Set-Location cmdlet.
    # We use the fully qualified name to avoid recursion.
    if ($InputArgs.Count -gt 0) {
        Microsoft.PowerShell.Management\Set-Location @InputArgs
    }
    else {
        # Handle 'cd' with no arguments (goes to home directory)
        Microsoft.PowerShell.Management\Set-Location
    }
}


# --- ALIAS SETUP ---
# Ensure the function above is defined before these alias commands.

# Forcefully remove the existing 'cd' alias if it exists.
if (Get-Alias -Name cd -ErrorAction SilentlyContinue) {
    Remove-Alias -Name cd -Force
}

# Create the new alias for 'cd' to point to your custom function.
Set-Alias -Name cd -Value Invoke-MyCustomCD -Option AllScope -Force -Description "Custom CD handler with multiple shortcuts"
# --- END ALIAS SETUP ---

# Helper function to convert bytes to a human-readable string
function Convert-BytesToHumanReadable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [long]$Bytes
    )

    if ($Bytes -lt 0) { return "N/A" }
    if ($Bytes -eq 0) { return "0 B" } # Simplified output for 0 Bytes

    $suffixes = "B ", "KB", "MB", "GB", "TB", "PB", "EB"
    $place = 0
    if ($Bytes -gt 0) {
        $place = [Math]::Floor([Math]::Log($Bytes, 1024))
    }
    $place = [Math]::Max(0, [Math]::Min($place, $suffixes.Length - 1))
    $num = $Bytes / [Math]::Pow(1024, $place)

    if ($place -eq 0) { # Bytes
        # Format as number with locale-specific thousands separator (if any), no decimal places
        return "{0:N0} {1}" -f $num, $suffixes[$place]
    } else { # KB, MB, etc.
        # Format as number with locale-specific thousands separator (if any), 1 decimal place
        return "{0:N1} {1}" -f $num, $suffixes[$place]
    }
}

# Custom function to handle 'ls' with an '-lha' like argument
function Invoke-MyCustomLS {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
        [string[]]$InputArgs
    )

    $linuxStyleArgument = "-lha"
    $useCustomFormatting = $false
    $remainingArgsFromInput = [System.Collections.Generic.List[string]]::new()

    if ($InputArgs) {
        foreach ($arg in $InputArgs) {
            if ($arg.ToLower() -eq $linuxStyleArgument.ToLower()) {
                $useCustomFormatting = $true
            } else {
                $remainingArgsFromInput.Add($arg)
            }
        }
    }

    if ($useCustomFormatting) {
        #Write-Verbose "Using custom '$linuxStyleArgument' style formatting."
        $gciSplatParams = @{
            Force = $true; # Key for -lha (show all/hidden)
            ErrorAction = 'Stop'
        }
        $pathsForGCI = [System.Collections.Generic.List[string]]::new()

        try {
            if ($remainingArgsFromInput.Count -eq 0) {
                # Case: Only 'ls -lha' was typed (no path, implies current directory)
                #Write-Host "DEBUG: Executing 'ls -lha' for current directory." -ForegroundColor Cyan
                # No specific path, Get-ChildItem @gciSplatParams will use current directory
            } else {
                # Case: 'ls -lha <path_or_other_switches>'
                # Separate paths from other known switches
                foreach ($remArg in $remainingArgsFromInput) {
                    # Simple check for common GCI switches, extend as needed
                    if ($remArg.ToLower() -eq '-recurse') {
                        $gciSplatParams['Recurse'] = $true
                    } elseif ($remArg.ToLower() -eq '-file') {
                        $gciSplatParams['File'] = $true
                    } elseif ($remArg.ToLower() -eq '-directory') {
                        $gciSplatParams['Directory'] = $true
                    } elseif ($remArg.ToLower() -eq '-hidden') {
                        $gciSplatParams['Hidden'] = $true # Though -Force usually covers this
                    } elseif ($remArg.ToLower() -match '^-filter$' -and ($remainingArgsFromInput.IndexOf($remArg) + 1) -lt $remainingArgsFromInput.Count) {
                        # Example for a parameter that takes a value (simplistic)
                        # $gciSplatParams['Filter'] = $remainingArgsFromInput[$remainingArgsFromInput.IndexOf($remArg) + 1]
                        # This part needs more robust parsing if you want to support all GCI params this way.
                        # For now, unhandled switches/params will be treated as potential paths.
                        $pathsForGCI.Add($remArg) # Or handle more switches
                    }
                    elseif (!$remArg.StartsWith("-")) {
                        $pathsForGCI.Add($remArg)
                    } else {
                        # Argument starts with '-' but is not a recognized switch above.
                        # It might be a GCI switch we haven't explicitly handled or a typo.
                        # For now, let's add it as a path and let GCI decide. Or, error.
                        # Adding to pathsForGCI is safer for now to see if GCI can take it.
                        # A more advanced version would parse all GCI parameters.
                        $pathsForGCI.Add($remArg)
                        #Write-Warning "DEBUG: Unhandled switch-like argument '$remArg' treated as potential path/arg."
                    }
                }

                if ($pathsForGCI.Count -gt 0) {
                    $gciSplatParams['Path'] = $pathsForGCI.ToArray()
                }
                # If $pathsForGCI is empty, GCI will use the current directory by default.
            }

            #Write-Host "DEBUG: GCI Splat Parameters prepared:" -ForegroundColor Cyan
            #$gciSplatParams.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Name) = $($_.Value)" -ForegroundColor Cyan }

            Get-ChildItem @gciSplatParams |
		Select-Object @{Name="Mode"; Expression={$_.Mode.PadRight(6)}}, # Adjust padding as needed
                	@{Name="LastWriteTime"; Expression={$_.LastWriteTime.ToString("MM/dd/yyyy HH:mm:ss").PadRight(10)}}, # Adjust padding
                	@{Name="Size"; Expression={(Convert-BytesToHumanReadable -Bytes $_.Length).PadLeft(10)}}, # PadLeft for right alignment
                	@{Name="Name"; Expression={$_.Name}} |
		Format-Table -AutoSize -Property @{Expression={$_.Mode}; Label="Mode"},
                	@{Expression={$_.LastWriteTime}; Label="LastWriteTime"},
			@{Expression={$_.Size}; Label="Size"; Alignment="Right"},
			@{Expression={$_.Name}; Label="Name"}
        }
        catch {
            Write-Warning "ERROR executing custom ls with '$linuxStyleArgument': $($_.Exception.Message)"
            #Write-Warning "DEBUG: Failed GCI call was attempted with splat params:"
            $gciSplatParams.GetEnumerator() | ForEach-Object { Write-Warning "  $($_.Name) = $($_.Value)" }
        }
    }
    else {
        # Standard Get-ChildItem behavior
        #Write-Verbose "Using standard Get-ChildItem behavior."
        if ($InputArgs.Count -gt 0) {
            Microsoft.PowerShell.Management\Get-ChildItem @InputArgs
        }
        else {
            Microsoft.PowerShell.Management\Get-ChildItem
        }
    }
}
# --- ALIAS SETUP for ls ---
# The helper function and Invoke-MyCustomLS must be defined above this line.

# Forcefully remove the existing 'ls' alias if it exists.
if (Get-Alias -Name ls -ErrorAction SilentlyContinue) {
    Remove-Alias -Name ls -Force
}

# Create the new alias for 'ls' to point to your custom function.
Set-Alias -Name ls -Value Invoke-MyCustomLS -Option AllScope -Force -Description "Custom LS handler for -lha argument"
# --- END ALIAS SETUP ---