# Analogue OS Library Image Generator

This is an interactive tool to assist with downloading image libraries from
[libretro-thumbnail](https://github.com/libretro-thumbnails/libretro-thumbnails)
and converting them to Analogue OS' ``.bin`` format.

Note that at this time image libraries only seem to work with cartridge-based
games.

## Note about OpenFPGA Cores
Presumably, OpenFPGA cores would follow the same image library format when displaying
game details. However, Analogue has yet to support Library images for titles launched
through OpenFPGA cores. Until such a time that OpenFPGA cores support Library images,
using these image libraries with ROMs launched through OpenFPGA cores cannot be
supported. 

## Quick Start
To get started, run `AnalogueOSLibraryImageGenerator.ps1` in PowerShell. An
interactive menu will guide you. It is recommended to read the **Introduction**
before using the tool for the first time to get a feel for how it works.

## What game libraries can I convert?
At this time of writing only GBA, GB, GBC, and GG images are useful for
conversion, but any libretro-thumbnail repository should be compatible.
This ensures future compatibility as official converters are released or if
Library images ever become supported on openFPGA cores.

## Why didn't it generate a thumbnail for one of my games?
Note that since this tool relies on both **libretro** and DAT files, it may miss
thumbnails for games which don't have a **libretro-thumbnail** image or if entries
are not found in your DAT file. For the latter, if you know the CRC of your
cart or ROM, you can add to your DAT file at any time using the text editor of
your choice. In particular, rom hacks are likely going to be missing from
the DAT file you pull from [DAT-O-MATIC](https://datomatic.no-intro.org/), but there are a few missing retail games
or revisions of them as well.

Keep in mind that DAT-O-MATIC does split some classes of games into their own
System. For example, GBA video cartridges have a special system classification
and are not included in the normal DAT with most actual games.

## Where can I run this script?
This tool is only supported on Windows as it relies on .NET types which are
not available on MacOS or Linux. You may see some remnants in the source of a
cross-platform direction, but this was quashed when I found the built-in namespaces
for image manipulation are Windows-only or deprecated in non-Windows environments.

## I would just like an image library please
Check out the [Releases](https://github.com/codewario/PocketLibraryImageConversion/releases)
page. You will find stable versions of the script along with
some image packs built for supported games at the time of publication.
