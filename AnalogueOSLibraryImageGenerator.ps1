[CmdletBinding()]
Param(
    [switch]$OutputConvertedFiles,
    [ValidateSet('Minimal', 'Extra', 'Noisy')]
    [string]$Verbosity = 'Minimal' # Dev note: don't bother writing checks for 'Minimal'
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

$libretro_base = 'https://github.com/libretro-thumbnails'
$libretro_repo = "$libretro_base/libretro-thumbnails"
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
        [string[]]$Options = @(),
        [string]$Message,
        [string]$CancelSelectionLabel = 'Cancel',
        [int]$CancelOptionValue = -1,
        [switch]$NoAutoCancel
    )

    [string[]]$useOptions = if ( !$NoAutoCancel ) {
        $Options + $CancelSelectionLabel
    }
    else {
        $Options
    }

    # Keep track of empty lines
    [int[]]$subtractAtIndices = for ( $o = 0; $o -lt $useOptions.Count; $o++ ) {
        $option = $useOptions[$o]
        if ( [string]::IsNullOrWhiteSpace($option) ) {
            $o
        }
    }

    Clear-Host

    Write-Host "===== $Title =====$([Environment]::NewLine)" -ForegroundColor Blue

    if ( $Message ) {
        Write-Host "$Message$([Environment]::NewLine)" -ForegroundColor Cyan
    }

    # Don't increase the input counter for empty lines
    $offset = 1
    for ( $i = 0; $i -lt $useOptions.Count; $i++ ) {
        $option = $useOptions[$i]
        if ( $i -in $subtractAtIndices ) {
            $offset -= 1
            Write-Host
        }
        else {
            Write-Host "`t$($i+$offset): $($useOptions[$i])" -ForegroundColor Green
        }
    }

    Write-Host
    do {
        try {
            [int]$selection = Read-Host -Prompt $InputPrompt
        }
        catch {
            Write-Warning 'Numeric entries only'
        }
    } while ( ( $selection -lt 1 ) -or ( $selection -gt ( $useOptions.Count - $subtractAtIndices.Count ) ) )

    if ( !$NoAutoCancel -and $selection -eq ( $useOptions.Count - $subtractAtIndices.Count ) ) {
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

The "Download Console Image Library" step now enumerates the available image
libraries so you don't have to go to Github and get the archive link yourself.
However, if the site parsing breaks at any time, the old method of obtaining
the ZIP link yourself is still supported with the legacy step
"Download Console Image Library (Manual)". Use this if you have problems with
the new download step.

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
    Param(
        [switch]$Manual
    )
    if ( $Manual ) {
        Copy-ToClipboard $libretro_repo

        Show-OKMenu -Title 'Download Console Image Library' -Message @"
Follow these steps, then select option 1 to continue:

0. If you already have the image archive downloaded, you may simply provide the path to the archive
   rather than the URL to skip the download. Otherwise, follow the instructions below. Note that
   an alternative archive location will not be cleaned up when the working directory initializes,
   unless you have saved the archive under "$tempWorkspace".

1. Go to $libretro_repo in a web browser.

   **The URL has been copied to your clipboard for your convenience**

2. Find the folder for the system you want to generate an image pack for. Click its link
   to be taken to the repository for that console's images.

3. Obtain the URL to this repo's ZIP archive by clicking the "Code" button, then right click
   "Download ZIP" and select "Copy Link" or "Copy Link Address".

   **Note that right clicking will paste in the terminal**

4. We will use this link in the next step. Select OK once you have copied the ZIP archive URL.
"@

        Write-Host
        $packUrl = Read-Host 'Please paste the libretro-thumbnail console repo ZIP link now'
    }
    else {
        Write-Host @'
A picker will open up with consoles to select from. Please select a console you wish to
generate an Analogue OS image library for. You can use the search filter to narrow down the
selection list.
'@
        do {
            $packUrl = ( Get-LibretroThumbnailConsoleImageLinks | Out-GridView -Title 'Select a console' -OutputMode Single ).ZipLink
            if ( !$packUrl ) {
                Write-Warning 'No console was selected. Please select a console using the picker.'
                Pause
            }
        } while ( !$packUrl )
    }
    Write-Host 'Initializing working directory'
    Initialize-CacheDir

    # Download the file if it's a URL
    if ( [uri]::IsWellFormedUriString($packUrl, 'Absolute') ) {
        Write-Host "Downloading $packUrl to $tempWorkspace"

        # Sidestep time-consuming byte-counting bug with the progress bar
        $oldProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'

        $startTime = Get-Date
        try {
            Invoke-WebRequest -OutFile $tempZipPath -UseBasicParsing $packUrl
        
        }
        finally {
            $ProgressPreference = $oldProgressPreference
            Write-Host "Download finished in $(( Get-Date ) - $startTime)"
        }
    }
    else {
        # Otherwise assume it's a path to the archive on disk
        $tempZipPath = ( ( $packUrl ) -replace '^["'']' ) -replace '["'']$'
        if ( Test-Path -LiteralPath $tempZipPath -PathType Leaf ) {
            Write-Host "Using provided archive location on disk: $tempZipPath"
        }
        else {
            Write-Warning "A URL was not provided and the value of ""$packUrl"" does not appear to be an existing file. Aborting."
            Pause
            return
        }
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

    # Make sure to remove any surrounding quotes from the input string
    $datPath = ( ( Read-Host 'Paste the path to your DAT file for the target console' ) -replace '^["'']' ) -replace '["'']$'
    $dat = Get-Dat -DatFile $datPath
    $outdir = Get-Variable -ValueOnly "tempConversion${LibraryType}Dir"

    # Determine scaling mode to use
    $scaleMode = if ( $LibraryType -eq 'BoxArts' ) {
        'BoxArts'
    }
    else {
        'Original'
    }
    Convert-Images -InputDirectory "$tempExtractionPath\$LibraryType" -OutputDirectory $outdir -Dat $dat -ScaleMode $scaleMode
    Pause
}

Function Show-MovePrompt {
    Param(
        [ValidateSet('BoxArts', 'Snaps', 'Titles')]
        [string]$LibraryType
    )

    # Make sure any surrounding quotes are removed
    $path = if ( [string]::IsNullOrWhiteSpace($LibraryType) ) {
        ( ( Read-Host 'Provide a directory to move your converted image library folders to' ) -replace '^["'']' ) -replace '["'']$'
    }
    else {
        ( ( Read-Host "Provide a directory to move your $LibraryType image library to" ) -replace '^["'']' ) -replace '["'']$'
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
You can use one of the "Move" steps to either copy your image library to a
location on your PC, or if your Analogue OS SD card is mounted you can move
them directly to the image path for your console on the SD card.

The path is as follows from the root of the SD card:
/System/Library/Images/CONSOLE/*.bin

The only known console identifiers for the CONSOLE portion of the path at this
time of writing are:

- Gameboy Advance: GBA
- Gameboy/Gameboy Color: GB
- Game Gear: GG

If you use the "Move All Libraries" step it will create subfolders for any
library type you previously converted to `.bin` format. This is not
compatible with the Analogue OS Library image layout, so you should not
"Move All Libraries" directly to the SD card.

Instead, "Move All Libraries" to a location on your PC, then using File
Explorer copy the subfolder contents for the Library image type you want
to the SD card using the layout above.
'@
}

Function Get-LibretroThumbnailConsoleImageLinks {
    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        [array]$consoleLinks = ( Invoke-WebRequest -UseBasicParsing $libretro_repo ).Links | Where-Object {
            # Submodule links don't have a class
            !$_.class -and
            $_.href -match 'libretro-thumbnails/.+/tree'
        }
    }
    finally {
        $ProgressPreference = $oldProgressPreference
    }

    foreach ( $link in $consoleLinks ) {
        $Name = [regex]::Match($link.outerHTML, '(?<=\<a\s+.*\>).+(?=\<\/a\>)').Value -replace '\s+@.*$'
        $linkPath = $link.href
        $targetZipName = "$([regex]::Match($linkPath, '(?<=tree/)\S+$')).zip"
        $targetRepoName = "$([regex]::Match($linkPath, '(?<=libretro-thumbnails\/)\S+?(?=\/)'))"
        # Write-Warning "ZipName: $targetZipName"
        # Write-Warning "RepoName: $targetRepoName"
        [PSCustomObject]@{
            # Remove submodule commit ref from the text
            Name    = $Name
            ZipLink = "$libretro_base/$targetRepoName/archive/$targetZipName"
        }
    }
}

function Confirm-Png {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    try {
        # Signature for PNG files
        [byte[]]$pngHeader = 137, 80, 78, 71, 13, 10, 26, 10
        
        # Read the first 8 bytes
        [System.IO.FileStream]$fStream = [System.IO.FileStream]::new($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
        [byte[]]$actualHeader = [byte[]]::new(8)
        $fStream.Read($actualHeader, 0, 8) > $null

        if ( $Verbosity -eq 'Noisy' ) {
            Write-Verbose "Actual Header: $actualHeader"
            Write-Verbose "   PNG Header: $pngHeader"
        }

        # Check that the bytes match the expected signature for PNG files
        # Return false on first mismatch
        for ( $i = 0; $i -lt 8; $i++ ) {
            if ( $actualHeader[$i] -ne $pngHeader[$i] ) {
                return $false
            }
        }

        # Return true by default
        $true
    }
    finally {
        if ( $fStream ) {
            $fStream.Dispose()
        }
    }
}

# So far only a handful of box arts have been jpegs with a .png extension
# that I've noticed, and none of the titles are ones I own. Unable to confirm
# if this script is generating useful images for the Pocket to display in the
# cases where JPEGs are masquerading as PNGs.
function Confirm-Jpeg {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    # Signature for PNG files
    [byte[]]$jpgHeader = 255, 216
    [byte[]]$jpgFooter = 255, 217
        
    # For JPEG detection we really need to look at the first and last two bytes, so read the whole thing
    [byte[]]$fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    [byte[]]$headerBytes = $fileBytes[0, 1]
    [byte[]]$footerBytes = $fileBytes[-2, -1]

    # Free up bytes read for signature detection
    $fileBytes = $null
    [System.GC]::Collect()

    # Super noisy even for verbose output. Uncomment if debugging image headers
    if ( $Verbosity -eq 'Noisy' ) {
        Write-Verbose "`tActual Header: $headerBytes"
        Write-Verbose "`t  JPEG Header: $jpgHeader"
        Write-Verbose "`tActual Footer: $footerBytes"
        Write-Verbose "`t  JPEG Footer: $jpgFooter"
    }

    # Check that the bytes match the expected signature for JPG files
    for ( $i = 0; $i -lt 2; $i++ ) {
        if ( ( $headerBytes[$i] -ne $jpgHeader[$i] ) -and ( $footerBytes[$i] -ne $jpgFooter[$i] ) ) {
            return $false
        }
    }

    # Return true by default
    if ( $FilePath -notmatch '\.(jpg|jpeg)$' ) {
        Write-Warning "JPEG masquerading: ""$FilePath"""
    }
    $true
}

function Confirm-Image {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    # Check if the file is an expected image format
    ( Confirm-Png $FilePath ) -or ( Confirm-Jpeg $FilePath )
}

Function Convert-PngToAnalogueLibraryBmp {
    Param(
        [Parameter(Mandatory)]
        [string]$InFile,
        [Parameter(Mandatory)]
        [string]$OutFile,
        [byte[]]$ImageHeader = @( 0x20, 0x49, 0x50, 0x41 ),
        [Parameter(Mandatory)]
        [ValidateSet('Original', 'BoxArts')]
        [string]$ScaleMode
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
            $scaledBitmap = switch ( $ScaleMode ) {
                'Original' {
                    # Don't scale at all, just use the rotated bitmap
                    $rotatedBitmap
                    break
                }

                'BoxArts' {
                    $scale = 165 / $rotatedBitmap.PixelHeight

                    [System.Windows.Media.Imaging.TransformedBitmap]::new(
                        $rotatedBitmap,
                        [System.Windows.Media.ScaleTransform]::new($scale, $scale)
                    )
                    break
                }
            }

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
            $scaledBitmap = $null

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
        [hashtable[]]$Dat,
        [Parameter(Mandatory)]
        [ValidateSet('Original', 'BoxArts')]
        [string]$ScaleMode
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
    $filesToConvert = Get-ChildItem -LiteralPath "$(Resolve-Path $InputDirectory)" -File | Where-Object {
        ( $_.Extension -match '^\.png$' ) -and

        # Ignore e-reader card entries, e-card names are usually suffixed with `-e` before the region
        ( $_.BaseName -notmatch '^.*(-e|e\+).*\(' ) -and

        # Detect and remove romhacks of all types. Useless as Game Details won't show for these.
        # Some hacks have no indication in the file name and cannot be detected in this way.
        # TODO: Remove this and related checks if OpenFPGA ever supports image libraries, or if Analogue
        #       adds in something like a custom database users can provide that will trigger
        #       the Game Details page for otherwise unrecognized CRC IDs (would be useful
        #       for flashable cartridges, such as fan translation carts)
        ( $_.BaseName -notmatch '(\[(Hack|T-)|\([\w\s,]*Hack)' ) -and
        
        # Ignore virtual console versions. These either have no physical counterpart or are identical
        # to a retail version of the game.
        ( $_.BaseName -notmatch 'Virtual Console' ) -and

        # Ignore pirate-flagged versions
        ( $_.BaseName -notmatch '\([\w\s,]*Pirate' )
    }

    Write-Host 'Beginning conversion (this will take a while)'
    $startTime = Get-Date

    # Convert each file to the .bin format
    $convertedCount = 0
    $results = $filesToConvert | ForEach-Object {
        $inFile = if ( Confirm-Image $_.FullName ) {
            $_.FullName
        }
        else {
            # If the ".png" file is not actually an image, assume it's a symlink with contents pointing to the correct filename
            $parent = Split-Path -Parent $_.FullName
            $realName = ( Get-Content -Raw -LiteralPath $_.FullName ) -replace '\/', '\'
            ( $realPath = "$parent\$realName" )

            if ( $Verbosity -match '^(Noisy|Extra)$') {
                Write-Verbose "Found symlink: ""$($_.FullName)"" => ""$realPath"""
            }
        }

        # Determine outfile name (skip if game not found)
        $found = $false
        foreach ( $game in $Dat ) {

            # Per `libretro-thumbnails` instructions, replace the following characters
            # in the game name with an underscore, as these characters are illegal in
            # file paths:
            #
            # &*/:`<>?\|"
            $useGameName = $game.name -replace '[&\*/:`<>\?\\\|"]', '_'
            if ( $_.BaseName -eq $useGameName ) {
                $found = $true
                $outFile = "$OutputDirectory\$($game.CRC).bin"

                if ( $OutputConvertedFiles ) {
                    Write-Host "$useGameName"
                }
                $returnObj = Convert-PngToAnalogueLibraryBmp -ScaleMode $ScaleMode $inFile $outFile
                $returnObj.Name = $_.BaseName

                if ($returnObj.Success ) {
                    $convertedCount++
                }
                break
            }
        }

        if ( !$found ) {
            Write-Verbose "Could not find a definition for ""$($_.BaseName)"" in the provided DAT, skipping..."
        }
    }

    $results | ForEach-Object {
        if ( !( $_.Success ) ) {
            Write-Warning ( "Failed to convert {0}: {1}" -f $_.Name, $_.Output )
        }
    }

    $timespan = ( Get-Date ) - $startTime
    Write-Host "Converted $convertedCount images in $timespan"
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

        # Treat top-level directory as optional, for the case where the archive is built from an
        # archive export of the git repo
        $boxartEntries = $zip.Entries | Where-Object { $_.FullName -match '^(.*/)?Named_BoxArts/.*\.png' }
        $titleEntries = $zip.Entries | Where-Object { $_.FullName -match '^(.*/)?Named_Titles/.*\.png' }
        $snapEntries = $zip.Entries | Where-Object { $_.FullName -match '^(.*/)?Named_Snaps/.*\.png' }

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
'',
'Download Console Image Library', # 2
'Download Console Image Library (Manual)', # 3
'Download No-Intro DAT file', # 4
'',
'Create BoxArt Library', # 5
'Create Title Library', # 6
'Create Snaps Library', # 7
'',
'Move BoxArt Library', # 8
'Move Title Library', # 9
'Move Snaps Library', # 10
'Move All Libraries', # 11
'',
'Clean up working directory', # 12
'How to copy to Analogue OS' # 13

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

            # INstructions
            1 {
                Clear-Host
                Show-Instructions
                break
            }

            # Download Console Image Library
            2 {
                Clear-Host
                Show-GetConsoleImages
                break
            }

            # Download Console Image Library (Manual)
            3 {
                Clear-Host
                Show-GetConsoleImages -Manual
                break
            }

            # Download No-Intro DAT File
            4 {
                Clear-Host
                Show-DatFileHowTo
                break
            }

            # Create BoxArt Library
            5 {
                Clear-Host
                Show-ConvertPrompt -LibraryType BoxArts
                break
            }

            # Create Titles Library
            6 {
                Clear-Host
                Show-ConvertPrompt -LibraryType Titles
                break
            }

            # Create Snaps Library
            7 {
                Clear-Host
                Show-ConvertPrompt -LibraryType Snaps
                break
            }

            # Move BoxArt Library 
            8 {
                Clear-Host
                Show-MovePrompt -LibraryType BoxArts
                break
            }

            # Move Titles Library
            9 {
                Clear-Host
                Show-MovePrompt -LibraryType Titles
                break
            }

            # Move Snaps Library
            10 {
                Clear-Host
                Show-MovePrompt -LibraryType Snaps
                break
            }

            # Move All Libraries
            11 {
                Clear-Host
                Show-MovePrompt
                break
            }

            # Clean up working directory
            12 {
                Write-Host 'Cleaning Up'
                Remove-CacheDir
                break
            }

            # How to copy to Analogue OS
            13 {
                Clear-Host
                Show-HowToInstallMenu
                break
            }
        }
    }
    catch {
        Write-Warning 'An error occurred and the current operation has been aborted.'
        Write-Error -EA Continue -ErrorRecord $_
        Pause
    }
} while ( $selection -ne -1 )

Write-Host -ForegroundColor Yellow 'Thank you, good bye!'