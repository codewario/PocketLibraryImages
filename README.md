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

By default the output is minimal. You can use the following flags to control
whether to show additional output when launching the script. Note that these
flags will increase the conversion time a bit as writing to the console is not
an instant operation:

- `-OutputConvertedFiles`: Output the files which are converted to the console
- `-Verbose`: Additional debugging output, useful when troubleshooting the script
- `-Verbosity`: `Minimal`, `Extra`, or `Noisy`. Controls how much information is
displayed when `-Verbose` is set. No effect otherwise. `Minimal` is the default.

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

I am aware that there are third-party libs/tools that can be leveraged for image
manipulation, however, one of the goals of this project is portability and not
requiring additional items to be installed. It is also why this script crawls
the GitHub site to obtain the zip URLs instead of requiring `git` to be installed
for cloning `libretro-thumbnails` and its submodules directly.

That said, if anybody wants to contribute such functionality for Mac OS or Linux,
pull requests are welcomed. Just try to keep any external dependencies to a
"standard enough" minimum.

## Getting a "connection closed" error when downloading one of the `libretro-thumbnails` image libraries
There's not a whole lot I can do about this, I hit this sometimes too when trying to convert
the GBA library due to its size. GitHub terminates the code archive download if it runs for
longer than 20 minutes, in my experience. This is likely due to the fact that GitHub
creates code archives on-demand, and the time the exported archive remains cached is limited.

As a workaround when this happens, if you choose `Download Console Image Library (Manual)`,
and provide a file path (instead of a URL) to an archive that you've either:

- [exported yourself from a cloned copy of the `git` repo](./create-local-archive.md); or
- been able to obtain from `libretro-thumbnails` yourself via other means

then the script will work with the local archive you've pointed to instead of attempting to
obtain it from GitHub. Note that this script expects a `.zip` file; `.tar.gz` is not supported.

## I would just like an image library please
Check out the latest [Release](https://github.com/codewario/PocketLibraryImageConversion/releases/latest)
page for the most recent sample image packs.

If you have a problem with the latest version, all [Releases](https://github.com/codewario/PocketLibraryImageConversion/releases/)
have sample packs provided, so you may try one of those. You can find older stable versions of the
script along with image packs for supported games at the time of release as well as prior versions
of the script. Don't forget if you have a problem with the latest sample packs to
please create an issue on the [project's issue tracker]([url](https://github.com/codewario/PocketLibraryImageConversion/issues)https://github.com/codewario/PocketLibraryImageConversion/issues).
