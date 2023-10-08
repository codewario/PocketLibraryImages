# Creating a local image archive

Github seems to reset the connection after 20 mins, and often this happens before the archive is done downloading.
The download cannot be resumed as the `content-length` isn't advertised due to the download occurring while
GitHub does a `git archive` to export a zip.

Follow these instructions to build a local zip to pass into the Pocket conversion script. **Git is required for this**.
Supported consoles are used in the examples below but should work for any other system's repo.

1. Make sure long paths are turned on for git: `git config --system core.longpaths true`

2. `cd` to a suitable directory and run the following:

   - GBA: `git clone --depth 1 https://github.com/libretro-thumbnails/Nintendo_-_Game_Boy_Advance.git`
   -  GB: `git clone --depth 1 https://github.com/libretro-thumbnails/Nintendo_-_Game_Boy.git`
   - GBC: `git clone --depth 1 https://github.com/libretro-thumbnails/Nintendo_-_Game_Boy_Color.git`
   -  GG: `git clone --depth 1 https://github.com/libretro-thumbnails/Sega_-_Game_Gear.git`

   A fresh clone is recommended each time to save space, just make sure you remove the old working copy
   before cloning if it already exists.

3. Change to the directory you just cloned and run from the CLI (GBA export used in example below, use
   an appropriate file name for other systems):

   - GBA: `git archive --format=zip --output ../gba-thumbs.zip HEAD`
   -  GB: `git archive --format=zip --output ../gb-thumbs.zip HEAD`
   - GBC: `git archive --format=zip --output ../gbc-thumbs.zip HEAD`
   -  GG: `git archive --format=zip --output ../gg-thumbs.zip HEAD`

4. The image archive (close enough) as it would be downloaded from GitHub now exists one directory
   up at the path you provided for `--output`.

   Github code archives normally include the repo name and the branch as a prefix directory in the archive,
   but for the purposes of this process the script will also find the images if they are at the root of
   the archive, no prefix necessary.

5. Provide the full path to the archive when asked for a URL in the conversion script. Use the
   `Download Console Image Library (Manual)` selection to achieve this.