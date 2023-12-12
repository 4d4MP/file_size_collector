function Get-Config {
    # Read the config.json file
    $configContent = Get-Content -Path "config.json" -Raw

    # Parse the JSON content
    $config = $configContent | ConvertFrom-Json

    # Store the folders and return
    return $config
    
}

# Get the folders from the config
$folders = Get-Config | Select-Object -ExpandProperty folders
# Output the folders
Write-Host "Processing folders: $folders"

$unit = Get-Config | Select-Object -ExpandProperty unit
# Validate the unit
$unit = $unit.ToUpper()
if ($unit -ne "KB" -and $unit -ne "MB" -and $unit -ne "GB" -and $unit -ne "TB") {
    Write-Host "Invalid unit: $unit"
    Write-Host "Valid units: KB, MB, GB, TB"
    exit
} else {
    Write-Host "Unit: $unit"
}

# Export the results to a CSV file if needed
$export = Get-Config | Select-Object -ExpandProperty generate_csv
$csvFileName = Get-Config | Select-Object -ExpandProperty csv_file_name
$createUniqueFileName = Get-Config | Select-Object -ExpandProperty create_unique_file_name

# Loop through the folders
function Get-SubfolderSizes {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$folders,
        [Parameter(Mandatory=$true)]
        [string[]]$unit
    )

    # Create an array to store the results
    $results = @()

    # Loop through the folders
    foreach ($folder in $folders) {

        Write-Host "Processing folder: $folder"

        # Get the subfolders
        $subfolders = Get-ChildItem -Path $folder -Directory

        Write-Host "Subfolders: $subfolders"

        # Loop through the subfolders
        foreach ($subfolder in $subfolders) {

            # If subfolder is not empty
            if ($null -ne $subfolder -and "" -ne $subfolder) {

                # Get the size of the folder in bytes
                $folderSizeInBytes = Get-ChildItem -Path $folder -Recurse -Force | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue

                # Convert the size to the specified unit
                switch ($unit) {
                    "KB" { $folderSize = $folderSizeInBytes.Sum / 1KB }
                    "MB" { $folderSize = $folderSizeInBytes.Sum / 1MB }
                    "GB" { $folderSize = $folderSizeInBytes.Sum / 1GB }
                    "TB" { $folderSize = $folderSizeInBytes.Sum / 1TB }
                    default { $folderSize = $folderSizeInBytes.Sum }
                }

                # Create folder object with the folder name and size
                $folderObject = New-Object -TypeName PSObject -Property @{
                    FolderName = $subfolder.FullName
                    FolderSize = $folderSize
                }

                # Add the folderObject to the results
                $results += $folderObject
            }
        }
    }

    # Return the results
    return $results
}



if ($export){

    if ($createUniqueFileName) {
    $csvFileName = $csvFileName.TrimEnd(".csv")

    # Add current date with second accuracy to make a unique filename
    $csvFileName = $csvFileName + "_" + (Get-Date -Format "yyyy-MM-dd_HH-mm-ss") + ".csv"

    }elseif (Test-Path $csvFileName) {
        Write-Host "CSV file already exists: $csvFileName"
        $overwrite = Read-Host "Do you want to overwrite it? (y/N)"
        if ($overwrite -eq "Y" -or $overwrite -eq "y") {
            Write-Host "Exporting to $csvFileName"
            $subfolderSizes | Export-Csv -Path $csvFileName -NoTypeInformation
        } else {
            Write-Host "Aborted exporting to $csvFileName"
        }
    } else {
        Write-Host "Exporting to $csvFileName"
        $subfolderSizes | Export-Csv -Path $csvFileName -NoTypeInformation
    }
}

# Usage
$subfolderSizes = Get-SubfolderSizes -folders $folders -unit $unit

# Output the results
$subfolderSizes


#$addToRegistry = Get-Config | Select-Object -ExpandProperty add_to_registry

if ($addToRegistry) {
    Add-ToRegistry -filename $csvFileName
}

