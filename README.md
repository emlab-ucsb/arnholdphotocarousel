# Photo slideshow

A full-screen, auto-advancing photo slideshow, published with GitHub Pages.
The photos come from a Google Drive folder. Every morning a GitHub Action runs
`R/build_site.R`, which downloads the folder's photos, resizes them, and
republishes the site. Add or remove photos in the folder and the site follows.

## How it fits together

| File | What it does |
| --- | --- |
| `R/build_site.R` | Downloads the photos from Drive and builds the site into `_site/` |
| `site/index.html` | The slideshow page |
| `.github/workflows/build.yml` | Runs the build daily, on demand, and on every push, then publishes to Pages |

## Updating the photos

- **Add or remove photos** in the Google Drive folder. The site updates the next morning.
- **Update right away:** go to the repo's **Actions** tab, choose **Build slideshow**, click **Run workflow**.
- **Change the order:** photos play alphabetically by file name. Start names with numbers
  (`01 Cover.jpg`, `02 Field day.jpg`) to set the order.

The folder must stay shared as **Anyone with the link → Viewer**, because the build reads it without logging in.

## Settings you can change

- **Folder:** edit `folder_id` at the top of `R/build_site.R`.
- **Schedule:** edit the `cron` line in `.github/workflows/build.yml` (times are UTC).
- **Photo size and quality:** `max_edge` and `quality` at the top of `R/build_site.R`.
- **Seconds per photo:** viewers can pick 3, 5, 8, or 12 from the controls.

## Running it on your own computer

```r
install.packages(c("googledrive", "magick", "jsonlite"))
source("R/build_site.R")
```

Then open `_site/index.html` through a local server (for example `servr::httd("_site")`),
since browsers block loading `photos.json` from a file opened directly.

## If the build fails

Open the failed run on the **Actions** tab and look at the "Build site from the Drive folder" step.

- **"Login Required" or "File not found":** the folder isn't shared as "Anyone with the link." Fix the sharing and run the workflow again.
- **"Rate limit exceeded":** create a Google API key with the Drive API enabled, and add it as a repository secret named `GOOGLE_API_KEY`.
- **A photo shows "Skipped":** that file couldn't be read. Re-save it as JPG or PNG in the folder.
