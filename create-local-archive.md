# Creating a local image archive

This is mainly for the GBA image downloads due to the size of the code archive.

Github seems to reset the connection after 20 mins, and often this happens before the archive is done downloading.
The download cannot be resumed as the `content-length` isn't advertised due to the download occurring while
GitHub does a `git archive` to export a zip.

Follow these instructions to build a local zip to pass into the Pocket conversion script. **Git is required for this**.

At this time, most repos don't have an issue downloading from the script, so the instructions below are for
the GBA archive. Use suitable locations and file names if following this for images for a different console.

1. Make sure long paths are turned on for git: `git config --system core.longpaths true`

2. `cd` to a suitable directory and run the following:

   `git clone --depth 1 https://github.com/libretro-thumbnails/Nintendo_-_Game_Boy_Advance.git`

   A fresh clone is recommended each time to save space, just make sure you remove the old working copy
   before cloning if it already exists.

3. Change to the directory you just cloned and run from the CLI:

   `git archive --format=zip --output ../gba-thumbs.zip HEAD`

4. Image archive (close enough) as it would be downloaded from GitHub now exists at `../gba-thumbs.zip`

   Github code archives normally include the repo name and the branch as a prefix directory in the archive,
   but for the purposes of this process the script will also find the images if they are at the root of
   the archive, no prefix necessary.

5. Provide the full path to the archive when asked for a URL in the conversion script. Use the
   `Download Console Image Library (Manual)` selection to achieve this.