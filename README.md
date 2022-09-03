# Analogue OS Library Image Generator

This is an interactive tool to assist with downloading image libraries from
[libretro-thumbnail](https://github.com/libretro-thumbnails/libretro-thumbnails)
and converting them to Analogue OS' ``.bin`` format.

To get started, run the script in PowerShell. An interactive menu will guide you.
It is recommended to read the introduction before using the tool for the first
time to get a feel for how it works.

At this time of writing only GBA, GB, GBC, and GG images are useful for
conversion, but any libretro-thumbnail repository should be compatible.
This ensures future compatibility as new cores are released and Library
images become supported on openFPGA cores.

Note that since this tool relies on both **libretro** and DAT files, it may miss
thumbnails for games which don't have a **libretro-thumbnail** image or if entries
are not found in your DAT file. For the latter, if you know the CRC of your
cart or ROM, you can add to your DAT file at any time using the text editor of
your choice. In particular, rom hacks are likely going to be missing from
the DAT file you pull from DAT-O-MATIC, but there are a few missing retail games
or revisions of them as well. 

This tool is only supported on Windows as it relies on .NET types which are
not available on MacOS or Linux.
