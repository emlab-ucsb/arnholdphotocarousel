# Builds the slideshow website from a public Google Drive folder.
#
# 1. Lists every image in the Drive folder (no Google login needed,
#    because the folder is shared as "Anyone with the link").
# 2. Downloads each photo, converts iPhone HEIC files to JPG, fixes
#    rotation, and resizes so the site loads quickly.
# 3. Writes the finished site to _site/ for GitHub Pages.
#
# Photos play in alphabetical order by file name. To control the order,
# start file names with numbers, like "01 Cover.jpg", "02 Field day.jpg".

suppressPackageStartupMessages({
  library(googledrive)
  library(magick)
  library(jsonlite)
})

folder_id <- Sys.getenv("DRIVE_FOLDER_ID", "1MJLNOndjdak7NsnDLfj0V94b4aH6duU3")
max_edge  <- 2000   # longest side of each photo, in pixels
quality   <- 80     # JPEG quality, 1-100

out_dir   <- "_site"
photo_dir <- file.path(out_dir, "photos")
unlink(out_dir, recursive = TRUE)
dir.create(photo_dir, recursive = TRUE)
invisible(file.copy("index.html", out_dir))

# Read the public folder without logging in. An optional API key of your
# own (repo secret GOOGLE_API_KEY) avoids shared rate limits.
api_key <- Sys.getenv("GOOGLE_API_KEY")
if (nzchar(api_key)) drive_auth_configure(api_key = api_key)
drive_deauth()

# The folder lives in a Shared Drive, so list it with the Drive API
# directly (googledrive's drive_ls() needs a login for Shared Drives).
list_folder <- function(id) {
  out <- list(); token <- NULL
  repeat {
    params <- list(
      q = sprintf("'%s' in parents and trashed = false", id),
      supportsAllDrives = TRUE, includeItemsFromAllDrives = TRUE,
      pageSize = 1000, fields = "nextPageToken,files(id,name,mimeType)"
    )
    if (!is.null(token)) params$pageToken <- token
    res <- do_request(request_generate("drive.files.list", params = params))
    out <- c(out, res$files)
    token <- res$nextPageToken
    if (is.null(token)) break
  }
  data.frame(
    id   = vapply(out, `[[`, "", "id"),
    name = vapply(out, `[[`, "", "name"),
    mime = vapply(out, `[[`, "", "mimeType")
  )
}

download_file <- function(id, path) {
  req <- request_generate("drive.files.get",
                          params = list(fileId = id, alt = "media", supportsAllDrives = TRUE))
  res <- request_make(req, httr::write_disk(path, overwrite = TRUE))
  if (httr::status_code(res) >= 300) stop("HTTP ", httr::status_code(res))
  path
}

files <- list_folder(folder_id)
files <- files[grepl("^image/", files$mime), ]
files <- files[order(tolower(files$name)), ]

message("Found ", nrow(files), " image(s) in the folder.")

tmp <- tempfile("raw_")
dir.create(tmp)
photos <- character()

for (i in seq_len(nrow(files))) {
  name <- files$name[i]
  src <- tryCatch(
    download_file(files$id[i], file.path(tmp, sprintf("raw_%03d", i))),
    error = function(e) { message("  Skipped ", name, ": ", conditionMessage(e)); NULL }
  )
  if (is.null(src)) next

  # iPhone photos (HEIC/HEIF): convert to JPG first.
  if (grepl("hei[cf]", files$mime[i], ignore.case = TRUE)) {
    jpg <- paste0(src, ".jpg")
    status <- suppressWarnings(system2("heif-convert", c(shQuote(src), shQuote(jpg)),
                                       stdout = FALSE, stderr = FALSE))
    if (identical(as.integer(status), 0L) && file.exists(jpg)) src <- jpg
  }

  out <- sprintf("%03d.jpg", length(photos) + 1)
  ok <- tryCatch({
    img <- image_read(src)[1]                              # first frame only (GIFs)
    img <- image_orient(img)                               # fix sideways phone photos
    img <- image_resize(img, sprintf("%dx%d>", max_edge, max_edge))
    img <- image_flatten(image_background(img, "white"))   # remove transparency
    image_write(img, file.path(photo_dir, out), format = "jpeg", quality = quality)
    TRUE
  }, error = function(e) {
    message("  Skipped ", name, ": couldn't process this image (", conditionMessage(e), ")")
    FALSE
  })
  rm(list = intersect("img", ls())); gc(verbose = FALSE)   # free memory between photos
  unlink(src)
  if (!ok) next

  photos <- c(photos, file.path("photos", out))
  message("  Added ", name)
}

if (!length(photos)) {
  stop("No photos could be added. Check that the folder is shared as 'Anyone with the link'.")
}

write_json(
  list(updated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), photos = photos),
  file.path(out_dir, "photos.json"), auto_unbox = TRUE
)
message("Built slideshow with ", length(photos), " photo(s).")
