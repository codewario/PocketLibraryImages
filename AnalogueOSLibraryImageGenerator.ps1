[CmdletBinding()]
Param(

)
#Requires -PSEdition Desktop
#Requires -Version 5.1

# Variables
$ErrorActionPreference = 'Stop'

$tempWorkspace = if ( $env:USERPROFILE ) {
    "$env:USERPROFILE\.aostool"
}
else {
    "$env:HOME\.aostool"
}

$tempZipPath = "$tempWorkspace\console.zip"
$tempExtractionPath = "$tempWorkspace"
$tempConversionRootDir = "$tempWorkspace"
$tempConversionBoxArtsDir = "$tempConversionRootDir\conv\BoxArts"
$tempConversionSnapsDir = "$tempConversionRootDir\conv\Snaps"
$tempConversionTitlesDir = "$tempConversionRootDir\conv\Titles"

$libretro_repo = 'https://github.com/libretro-thumbnails/libretro-thumbnails'
$datomatic_site = 'https://datomatic.no-intro.org'

#Functions
Function Remove-CacheDir {
    Param(
        [switch]$Init
    )
    if ( Get-Item -EA Ignore $tempWorkspace\* ) {
        if ( $Init ) {
            Write-Warning "Removing stale temporary workspace files at $tempWorkspace"
        }
        Remove-Item $tempWorkspace\* -Force -Recurse 2> $null
    }
}

Function New-CacheDir {
    if ( !( Test-Path -PathType Container $tempWorkspace ) ) {
        New-Item -ItemType Directory $tempWorkspace > $null
    }
}

Function Initialize-CacheDir {
    Remove-CacheDir -Init
    New-CacheDir
}

Function Copy-ToClipboard {
    # This will work on Windows
    # Best effort for *nix. xclip must be present to work
    [CmdletBinding()]
    Param(
        [string]$String,
        [switch]$NoNewLines
    )

    if ( ( $clipBin = ( Get-Command -EA SilentlyContinue -CommandType Application clip.exe ).Source ) ) {
        $String | & $clipBin *> $null
    }
    elseif ( ( $clipBin = ( Get-Command -EA SilentlyContinue -CommandType Application xclip ).Source ) ) {
        $String | & $clipBin *> $null
    }
}

Function Show-Menu {
    Param(
        [string]$Title = 'Menu',
        [string]$InputPrompt = 'Enter the corresponding number to make a menu selection',
        [Parameter(Mandatory)]
        [string[]]$Options = @(),
        [string]$Message,
        [string]$CancelSelectionLabel = 'Cancel',
        [int]$CancelOptionValue = -1,
        [switch]$NoAutoCancel
    )

    $useOptions = if ( !$NoAutoCancel ) {
        $Options + $CancelSelectionLabel
    }
    else {
        $Options
    }

    Clear-Host

    Write-Host "===== $Title =====$([Environment]::NewLine)" -ForegroundColor Blue

    if ( $Message ) {
        Write-Host "$Message$([Environment]::NewLine)" -ForegroundColor Cyan
    }

    for ( $i = 0; $i -lt $useOptions.Count; $i++ ) {
        Write-Host "`t$($i+1): $(@($useOptions)[$i])" -ForegroundColor Green
    }

    Write-Host
    do {
        try {
            [int]$selection = Read-Host -Prompt $InputPrompt
        }
        catch {
            Write-Warning 'Numeric entries only'
        }
    } while ( ( $selection -lt 1 ) -or ( $selection -gt $useOptions.Count ) )

    if ( !$NoAutoCancel -and $selection -eq $useOptions.Count ) {
        $CancelOptionValue
    }
    else {
        $selection
    }
}

Function Show-OKMenu {
    Param(
        [string]$Title = 'Menu',
        [string]$Message
    )

    Show-Menu -Title $Title -Options 'OK' -Message $Message -NoAutoCancel > $null
}

Function Show-Instructions {
    Show-OKMenu -Title Instructions -Message @"
Workspace Folder: $tempWorkspace

This is an interactive tool to assist with downloading image libraries from the
libretro-thumbnail repositories available on Github at:

https://github.com/libretro-thumbnails/libretro-thumbnails

and converting them to Analogue OS' ``.bin`` format. Each step is meant to be
worked in order, but you can skip downloading the console library and DAT
file if you already have them from a previous run.

This tool can only download and convert images for one console at a time.
Downloading a new console's images or cleaning the working directory will erase
all working images along with the working diretory itself. Use the "Move"
options to move the converted libraries to a permanent location on disk.

At this time of writing only GBA, GB, GBC, and GG images are useful for
conversion, but any libretro-thumbnail repository should be compatible.
This ensures future compatibility as new cores are released and Library
images become supported on openFPGA cores.

The step ``How to copy to Analogue OS`` will have further details on installing
the image library to your SD card, but in a nutshell Library images should be
placed in the following folder, where CONSOLE is an identifier for the
target game console: ``/System/Library/Images/CONSOLE/``

This tool is only supported on Windows as it relies on .NET types which are
not available on MacOS or Linux.
"@
}

Function Show-GetConsoleImages {
    Copy-ToClipboard $libretro_repo

    Show-OKMenu -Title 'Download Console Image Library' -Message @"
Follow these steps, then select option 1 to continue:

1. Go to $libretro_repo in a web browser.
   **The URL has been copied to your clipboard for your convenience**
2. Find the folder for the system you want to generate an image pack for. Click its link
   to be taken to the repository for that console's images.
3. Obtain the URL to this repo's ZIP archive by clicking the "Code" button, then right click
   "Download ZIP" and select "Copy Link". Note that right click will paste in the terminal.
4. We will use this link in the next step. Select OK once you have copied the ZIP archive URL.
"@

    Write-Host
    $packUrl = Read-Host 'Please paste the libretro-thumbnail console repo ZIP link now'

    Write-Host 'Initializing working directory'
    Initialize-CacheDir

    Write-Host "Downloading $packUrl to $tempWorkspace"

    # Sidestep time-consuming byte-counting bug with the progress bar
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    try {
        Invoke-WebRequest -OutFile $tempZipPath -UseBasicParsing $packUrl
    }
    finally {
        $ProgressPreference = $oldProgressPreference
    }

    Write-Host "Unzipping $tempZipPath to $tempExtractionPath"
    Expand-ImageArchive -Path $tempZipPath -DestinationPath $tempExtractionPath

    Write-Host 'Done'
    Pause
}

Function Show-DatFileHowTo {
    Copy-ToClipboard $datomatic_site

    Show-OKMenu -Title 'Download DAT file from DAT-O-MATIC' -Message @"
Follow these instructions to obtain a suitable no-intro DAT file for use with
identifying each image:

1. Go to https://datomatic.no-intro.org in a web browser.
   **The URL has been copied to your clipboard for your convenience**
2. Click the "Download" button in the site header, then click "Standard DAT".
3. Pick the target system from the "System" dropdown.
   You should not need to change the defaults.
4. Click the "Prepare" button, then click the resulting "Download" button.
5. Extract the .dat file from the downloaded ZIP archive.
6. Make a note of the path to the downloaded ZIP file.
   You will need to provide the path to the DAT file for any of the "Create"
   selections from the main menu.

If you have obtained a DAT file from DAT-O-MATIC previously, you can skip this
step. Just remember to provide the path to the DAT file in the "Create" steps.

DAT-O-MATIC ``.dat`` files do not have records for every game available in
libratro-thumbnails and may be missing romhacks as well. However, you can add
additional entries to your DAT file if you know the cartridge ROM information
using any text editor.
"@
}

Function Show-ConvertPrompt {
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('BoxArts', 'Snaps', 'Titles')]
        [string]$LibraryType
    )

    $datPath = Read-Host 'Paste the path to your DAT file for the target console'
    $dat = Get-Dat -DatFile $datPath
    $outdir = Get-Variable -ValueOnly "tempConversion${LibraryType}Dir"
    Convert-Images -InputDirectory "$tempExtractionPath\$LibraryType" -OutputDirectory $outdir -Dat $dat
    Pause
}

Function Show-MovePrompt {
    Param(
        [ValidateSet('BoxArts', 'Snaps', 'Titles')]
        [string]$LibraryType
    )

    $path = if ( [string]::IsNullOrWhiteSpace($Library) ) {
        Read-Host 'Provide a directory to move your converted image library folders to'
    }
    else {
        Read-Host "Provide a directory to move your $LibraryType image library to"
    }

    if ( !( Test-Path -PathType Container $path ) ) {
        Write-Host "Creating directory: $path"
        try {
            New-Item -ItemType Directory -Force $path > $null
        }
        catch {
            Write-Warning "An error occurred creating the directory: $($_.Exception.Message)"
            return
        }
    }

    Write-Host "Moving $LibraryType library to $path"
    $source = switch ( $LibraryType ) {
        'BoxArts' {
            if ( ( Test-Path -PathType Container $tempConversionBoxArtsDir ) ) {
                "$tempConversionBoxArtsDir\*"
            }
            break
        }

        'Snaps' {
            if ( ( Test-Path -PathType Container $tempConversionSnapsDir ) ) {
                "$tempConversionSnapsDir\*"
            }
            break
        }

        'Titles' {
            if ( ( Test-Path -PathType Container $tempConversionTitlesDir ) ) {
                "$tempConversionTitlesDir\*"
            }  
            break
        }

        # All if no specified type
        { [string]::IsNullOrWhiteSpace($LibraryType) } {
            if ( ( Test-Path -PathType Container $tempConversionBoxArtsDir ) ) {
                $tempConversionBoxArtsDir
            }

            if ( ( Test-Path -PathType Container $tempConversionSnapsDir ) ) {
                $tempConversionSnapsDir
            }

            if ( ( Test-Path -PathType Container $tempConversionTitlesDir ) ) {
                $tempConversionTitlesDir
            }

            break
        }
    }

    if ( $source ) {
        Move-Item -Force -Path $source -Destination $path > $null
    }
    else {
        Write-Warning 'Could not find converted images (did you convert the images yet?)'
    }
    Pause
}

Function Show-HowToInstallMenu {
    Show-OKMenu -Title 'How to copy to Analogue OS' -Message @'
You can either use one of the "Move" steps to first copy your image library to
a location on your PC, or if your Analogue OS SD card is mounted, you can move
them directly to the image path for your console on the SD card.

The path is as follows from the root of the SD card:
/System/Library/Images/CONSOLE/*.bin

The only known console identifiers for the CONSOLE portion of the path at this
time of writing are:

- Gameboy Advance: GBA
- Gameboy/Gameboy Color: GB
- Game Gear: GG
'@
}

Function Convert-PngToAnalogueLibraryBmp {
    Param(
        [Parameter(Mandatory)]
        [string]$InFile,
        [Parameter(Mandatory)]
        [string]$OutFile,
        [byte[]]$ImageHeader = @( 0x20, 0x49, 0x50, 0x41 )
    )

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $success = $false
    $returnObject = @{
        Output = try {
            # Load required assemblies
            if ( !( 'System.Windows.Media.Imaging.BitmapDecoder' -as [type] ) ) {
                Add-Type -AssemblyName PresentationCore > $null
            }

            # Read in the initial image as FileStream
            [System.IO.FileStream]$imageStream = [System.IO.FileStream]::new(
                "$(Resolve-Path $InFile)",
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::Read
            )

            # Read image FileStream into BitmapSource
            $bitmapSource = [System.Windows.Media.Imaging.PngBitmapDecoder]::new(
                $imageStream,
                [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
                [System.Windows.Media.Imaging.BitmapCacheOption]::Default
            ).Frames[0]

            # Rotate -90 degrees per Analogue spec
            $rotatedBitmap = [System.Windows.Media.Imaging.TransformedBitmap]::new(
                $bitmapSource,
                [System.Windows.Media.RotateTransform]::new(-90)
            )

            # Determine aspect ratio for scaling
            # Only need height ratio as target canvas is landscape oriented
            $scale = 165 / $rotatedBitmap.PixelHeight

            $scaledBitmap = [System.Windows.Media.Imaging.TransformedBitmap]::new(
                $rotatedBitmap,
                [System.Windows.Media.ScaleTransform]::new($scale, $scale)
            )

            # Create new bitmap from rotated bitmap using BGRA32 pixel format
            $convertedBitmap = [System.Windows.Media.Imaging.FormatConvertedBitmap]::new()
            $convertedBitmap.BeginInit()
            $convertedBitmap.Source = $scaledBitmap
            $convertedBitmap.DestinationFormat = [System.Windows.Media.PixelFormats]::Bgra32
            $convertedBitmap.EndInit()

            # Open output stream. We will write the transformed image data along with the
            # Analogue header here.

            # Can't use Resolve-Path for non-existant files
            $fullOutfileName = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile)
            [System.IO.Stream]$imageStream2 = [System.IO.File]::OpenWrite($fullOutfileName)
            $bytesWritten = 0
            $imageStream2.Write($ImageHeader, 0, $ImageHeader.Length)
            $bytesWritten += $ImageHeader.Length

            # Dimensions as bytes, reverse order for little endian
            $h_bytes = [BitConverter]::GetBytes(( [int16]( $convertedBitmap.PixelHeight ) ))
            $w_bytes = [BitConverter]::GetBytes(( [int16]( $convertedBitmap.PixelWidth ) ))
            if ( !( [BitConverter]::IsLittleEndian ) ) {
                [array]::Reverse($h_bytes)
                [array]::Reverse($w_bytes)
            }

            # Write image dimensions in bytes
            $imageStream2.Write($h_bytes, 0, $h_bytes.Length)
            $bytesWritten += $h_bytes.Length
            $imageStream2.Write($w_bytes, 0, $w_bytes.Length)
            $bytesWritten += $w_bytes.Length

            # Create pixel buffer and calculate stride
            $pixels = [byte[]]::new(( $convertedBitmap.PixelWidth * $convertedBitmap.PixelHeight * 4 ))
            $stride = $convertedBitmap.PixelWidth * 4
            $convertedBitmap.CopyPixels($pixels, $stride, 0)

            # Write the image to the output file
            $imageStream2.Write($pixels, 0, $pixels.Length)
            $bytesWritten += $pixels.Length

            $success = $true
        }
        catch {
            $_.Exception.Message
        }
        finally {

            if ( $imageStream ) {
                $imageStream.Dispose()
                $imageStream = $null
            }

            if ( $imageStream2 ) {
                $imageStream2.Dispose()
                $imageStream2 = $null
            }

            $bitmapSource = $null
            $convertedBitmap = $null

            [System.GC]::Collect()

            $ErrorActionPreference = $oldErrorActionPreference
        }
    }

    $returnObject.Success = $success
    $returnObject
}

Function Get-Dat {
    Param(
        [string]$DatFile
    )

    [xml]$dat = Get-Content $DatFile
    foreach ( $game in $dat.datafile.game ) {
        @{
            Name = $game.name
            CRC  = $game.rom.crc
        }
    }

    $dat = $null
}

Function Convert-Images {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$InputDirectory,
        [Parameter(Mandatory)]
        [string]$OutputDirectory,
        [Parameter(Mandatory)]
        [hashtable[]]$Dat
    )

    # Bail on a bogus input directory
    if ( !( Test-Path -PathType Container $InputDirectory ) ) {
        Write-Warning 'Input directory does not exist (did you download the console images from step 1?)'
        return
    }

    # Create output directory if nonexistant
    if ( !( Test-Path -PathType Container $OutputDirectory ) ) {
        Write-Host "Creating output directory '$OutputDirectory'"
        New-Item -Force -ItemType Directory $OutputDirectory > $null
    }

    # Get list of files to convert
    # libretro-thumbnails standardizes on PNG format
    $filesToConvert = Get-ChildItem "$(Resolve-Path $InputDirectory)" -File | Where-Object {
        $_.Extension -match '^\.png$'
    }

    Write-Host 'Beginning conversion (this will take a while)'

    # Convert each file to the .bin format
    $results = $filesToConvert | ForEach-Object {
        $inFile = $_.FullName

        # Determine outfile name (skip if game not found)
        $found = $false
        foreach ( $game in $Dat ) {
            if ( $_.BaseName -eq $game.name ) {
                $found = $true
                $outFile = "$OutputDirectory\$($game.CRC).bin"

                $returnObj = Convert-PngToAnalogueLibraryBmp $inFile $outFile
                $returnObj.Name = $_.BaseName
                break
            }
        }

        if ( !$found ) {
            Write-Warning "Could not find a definition for $($_.BaseName) in the provided DAT, skipping..."
        }
    }

    $results | ForEach-Object {
        if ( !( $_.Success ) ) {
            Write-Warning ( "Failed to convert {0}: {1}" -f $_.Name, $_.Output )
        }
    }
}

# We need a function that will extract the files to short paths
Function Expand-ImageArchive {
    Param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    # Load required assemblies
    if ( !( 'System.IO.Compression.ZipFile' -as [type] ) ) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem > $null
    }

    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        $boxartEntries = $zip.Entries | Where-Object { $_.FullName -match '^.*/Named_BoxArts/.*\.png' }
        $titleEntries = $zip.Entries | Where-Object { $_.FullName -match '^.*/Named_Titles/.*\.png' }
        $snapEntries = $zip.Entries | Where-Object { $_.FullName -match '^.*/Named_Snaps/.*\.png' }

        if ( !( Test-Path -PathType Container "$DestinationPath\BoxArts" ) ) {
            New-Item -EA Stop -ItemType Directory "$DestinationPath\BoxArts" > $null
        }
        $boxartEntries | ForEach-Object {
            $entry = $_
            try {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$DestinationPath\BoxArts\$($entry.Name)", $true)
            }
            catch {
                Write-Warning "Boxart $($entry.Name) failed to extract: $($_.Exception.Message)"
            }
        }

        if ( !( Test-Path -PathType Container "$DestinationPath\Titles" ) ) {
            New-Item -EA Stop -ItemType Directory "$DestinationPath\Titles" > $null
        }
        $titleEntries | ForEach-Object {
            $entry = $_
            try {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$DestinationPath\Titles\$($entry.Name)", $true)
            }
            catch {
                Write-Warning "Title $($entry.Name) failed to extract: $($_.Exception.Message)"
            }
        }

        if ( !( Test-Path -PathType Container "$DestinationPath\Snaps" ) ) {
            New-Item -EA Stop -ItemType Directory "$DestinationPath\Snaps" > $null
        }
        $snapEntries | ForEach-Object {
            $entry = $_
            try {
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$DestinationPath\Snaps\$($entry.Name)", $true)
            }
            catch {
                Write-Warning "Snap $($entry.Name) failed to extract: $($_.Exception.Message)"
            }
        }
    }
    finally {
        if ( $zip ) {
            $zip.Dispose()
            $zip = $null
        }
    }
}


# Main Execution

$MainMenuOptions =
'Instructions', # 1
'Download Console Image Library', # 2
'Download No-Intro DAT file', # 3
'Create BoxArt Library', # 4
'Create Title Library', # 5
'Create Snaps Library', # 6
'Move BoxArt Library', # 7
'Move Title Library', # 8
'Move Snaps Library', # 9
'Move All Libraries', # 10
'Clean up working directory', # 11
'How to copy to Analogue OS' # 12

do {
    $selection = Show-Menu -Title 'Analogue OS Library Image Pack Generator' -Options $MainMenuOptions -CancelSelectionLabel Quit -Message @'
This tool will download and generate an AnalogueOS-compliant
Library image pack from the libretro-thumbnails repositories.

    **This script may copy information to the clipboard.**
**Please ensure sure you have NOTHING IMPORTANT stored in the**
               **clipboard before continuing**

Press Ctrl+C at any time to quit this script.
'@
    try {
        switch ( $selection ) {

            1 {
                Clear-Host
                Show-Instructions
                break
            }

            # Generate new image pack
            2 {
                Clear-Host
                Show-GetConsoleImages
                break
            }

            # Display steps to obtaining the DAT file
            # Unsure if dat-o-matic has an API of any sort
            3 {
                Clear-Host
                Show-DatFileHowTo
                break
            }

            # Create BoxArt Library
            4 {
                Clear-Host
                Show-ConvertPrompt -LibraryType BoxArts
                break
            }

            # Create Titles Library
            5 {
                Clear-Host
                Show-ConvertPrompt -LibraryType Titles
                break
            }

            # Create Snaps Library
            6 {
                Clear-Host
                Show-ConvertPrompt -LibraryType Snaps
                break
            }

            # Move BoxArt Library 
            7 {
                Clear-Host
                Show-MovePrompt -LibraryType BoxArts
                break
            }

            # Move Titles Library
            8 {
                Clear-Host
                Show-MovePrompt -LibraryType Titles
                break
            }

            # Move Snaps Library
            9 {
                Clear-Host
                Show-MovePrompt -LibraryType Snaps
                break
            }

            # Move All
            10 {
                Clear-Host
                Show-MovePrompt
                break
            }

            # Clean up working directory
            11 {
                Write-Host 'Cleaning Up'
                Remove-CacheDir
                break
            }

            # How to install instructions
            12 {
                Clear-Host
                Show-HowToInstallMenu
                break
            }
        }
    } catch {
        Write-Warning 'An error occurred and the current operation has been aborted.'
        Write-Error -EA -ErrorRecord Continue $_
        Pause
    }
} while ( $selection -ne -1 )

Write-Host -ForegroundColor Yellow 'Thank you, good bye!'