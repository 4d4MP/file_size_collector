########################################
#             GOOD TO KNOW             #
########################################
# Some cases the folder names a displayed incorrectly due to the use of special characters
# In case of hungarian characters, the following command can be used to set the correct encoding:
# chcp 65001


# Get config options
$folders = Get-Config | Select-Object -ExpandProperty folders
$export = Get-Config | Select-Object -ExpandProperty generate_csv
$csvFileName = Get-Config | Select-Object -ExpandProperty csv_file_name
$createUniqueFileName = Get-Config | Select-Object -ExpandProperty create_unique_file_name
$registryFile = Get-Config | Select-Object -ExpandProperty registry_file
$addToRegistry = Get-Config | Select-Object -ExpandProperty add_to_registry
$loggingEnabled = Get-Config | Select-Object -ExpandProperty logging_enabled
$logFileName = Test-LogFile

function Get-Config {
    # Read the config.json file
    $configContent = Get-Content -Path "config.json" -Raw
    Write-Log -message "Read config.json file"

    # Parse the JSON content
    $config = $configContent | ConvertFrom-Json

    # Store the folders and return
    return $config
    
}

function Get-SubfolderSizes {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$folders,
        [Parameter(Mandatory=$true)]
        [string[]]$unit
    )

    Write-Log -message "Getting subfolder sizes"

    # Create an array to store the results
    $results = @()

    # Loop through the folders
    foreach ($folder in $folders) {

        Write-Log -message "Processing folder: $folder" -print $true

        # Get the subfolders
        $subfolders = Get-ChildItem -Path $folder -Directory

        Write-Host "          Subfolders: $subfolders."

        # Loop through the subfolders
        foreach ($subfolder in $subfolders) {
            Write-Log -message "Subfolders: $subfolder"

            # If subfolder is not empty
            if ($null -ne $subfolder -and "" -ne $subfolder) {

                # Get the size of the folder in bytes
                $folderSizeInBytes = Get-ChildItem -Path $subfolder.FullName -Recurse -Force | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
                
                # Convert the size to the specified unit
                switch ($unit) {
                    "KB" { $folderSize = $folderSizeInBytes.Sum / 1KB }
                    "MB" { $folderSize = $folderSizeInBytes.Sum / 1MB }
                    "GB" { $folderSize = $folderSizeInBytes.Sum / 1GB }
                    "TB" { $folderSize = $folderSizeInBytes.Sum / 1TB }
                }
                Write-Log -message "Folder size in $unit for $subfolder : $folderSize"

                # Round the size to 2 decimals
                $folderSize = [math]::Round($folderSize, 2)

                # Create folder object with the folder name and size
                $folderObject = New-Object -TypeName PSObject -Property @{
                    FolderName = $subfolder.FullName
                    FolderSize = $folderSize
                }

                # Add the folderObject to the results
                $results += $folderObject

                $folderObject = $null

            }
        }
    }

    # Return the results
    return $results
}


function Test-LogFile{
    # Create the log folder if it doesn't exist
    if (!(Test-Path "log")) {
        New-Item -Path "log" -ItemType Directory -Force | Out-Null
    }

    # Create a unique log file name
    $logFileName = "log_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".log"
    $logFileName = "log\" + $logFileName

    # Create the log file
    New-Item -Path $logFileName -ItemType File -Force | Out-Null

    return $logFileName
}

function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$message,
        [Parameter(Mandatory=$false)]
        [bool]$print
    )

    # Get the stack trace of the calling function
    $callingFunction = (Get-PSCallStack)[1]
    

    # Get the current date and time
    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Create the log message
    $logMessage = "$currentDateTime - $callingFunction - $message"

    if ($loggingEnabled){
        # Write the log message to the log file
        Add-Content -Path $logFileName -Value $logMessage
    }

    if ($print) {
        Write-Host $message
    }
}

function Add-ToRegistry {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$source,
        [Parameter(Mandatory=$true)]
        [string[]]$filename
    )

    #Check if the registry file exists
    if (Test-Path $filename){
         
    }
}

###############################################
#                 Main                        #
###############################################

function Main {
    Write-Log -message "Runtime started"
    if ($export){
        if ($createUniqueFileName) {
            $csvFileName = $csvFileName.TrimEnd(".csv")
            # Add current date with second accuracy to make a unique filename
            $csvFileName = $csvFileName + "_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".csv"
            Write-Log -message "Unique file name created: $csvFileName"
        
        } elseif (Test-Path $csvFileName) {
            Write-Host "CSV file already exists: $csvFileName"

            $overwrite = Read-Host "Do you want to overwrite it? (y/N)"
            if ($overwrite -eq "Y" -or $overwrite -eq "y") {
                $subfolderSizes | Export-Csv -Path $csvFileName -NoTypeInformation
                Write-Log -message "Overwriting to $csvFileName" -print $true
            } else {
                Write-Log -message "Aborted exporting to $csvFileName" -print $true
            }
        } else {
            $subfolderSizes | Export-Csv -Path $csvFileName -NoTypeInformation
            Write-Log -message "Exporting to $csvFileName" -print $true
        }
    }
    
    # Output the folders
    Write-Log -message "Processing folders: $folders" -print $true
    
    $unit = Get-Config | Select-Object -ExpandProperty unit
    # Validate the unit
    $unit = $unit.ToUpper()
    if ($unit -ne "KB" -and $unit -ne "MB" -and $unit -ne "GB" -and $unit -ne "TB") {
        Write-Log -message "Invalid unit: $unit" -print $true
        Write-Host "Valid units: KB, MB, GB, TB"
        exit
    } else {
        Write-Host "Unit: $unit"
    } 
    
    $subfolderSizes = Get-SubfolderSizes -folders $folders -unit $unit
    
    # Output the results
    $subfolderSizes
    
    if ($addToRegistry) {
        Add-ToRegistry -source $subfolderSizes -filename $registryFile
        Write-Log -message "Adding to registry: $registryFile"
    }
}

Main
