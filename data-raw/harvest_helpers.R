# Harvest backends: interchangeable sources of repository files.
#
# A source is a plain list with fields:
#   repo             repository name
#   read_file(path)  file contents as one string, NA_character_ if absent
#   read_file_media(path)  like read_file but resolves git-lfs content
#                    (GitHub backend only; local backend returns the
#                    pointer unchanged)
#   list_files(dir)  file names inside dir, character(0) if absent
#   meta             list: default_branch, created_at, pushed_at, topics,
#                    latest_release, archived. Fields a backend cannot
#                    know are NA.
#
# The GitHub backend budget is 4 API requests plus a handful of raw
# fetches per repo (raw.githubusercontent.com is not rate limited), so a
# full org harvest stays far below the 5000/hour API limit.

# A few org repos ship latin1-encoded files (for example the
# undpcomposite dictionary); normalize everything to valid UTF-8 before
# it reaches the parsers.
owd_as_utf8 <- function(x) {
  if (is.na(x) || all(validUTF8(x))) {
    return(x)
  }
  converted <- iconv(x, from = "latin1", to = "UTF-8")
  if (is.na(converted)) iconv(x, to = "UTF-8", sub = "byte") else converted
}

# --- local backend ----------------------------------------------------------

owd_local_source <- function(path) {
  stopifnot(dir.exists(path))
  read_file <- function(rel) {
    f <- file.path(path, rel)
    if (!file.exists(f)) {
      return(NA_character_)
    }
    owd_as_utf8(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  }
  list_files <- function(rel) {
    d <- file.path(path, rel)
    if (!dir.exists(d)) {
      return(character())
    }
    list.files(d)
  }
  git <- function(...) {
    out <- suppressWarnings(tryCatch(
      system2("git", c("-C", path, ...), stdout = TRUE, stderr = FALSE),
      error = function(e) character()
    ))
    if (length(out) == 0 || !nzchar(out[1])) NA_character_ else out[1]
  }
  list(
    repo = basename(path),
    read_file = read_file,
    read_file_media = read_file,
    list_files = list_files,
    meta = list(
      default_branch = git("rev-parse", "--abbrev-ref", "HEAD"),
      created_at = NA_character_,
      pushed_at = git("log", "-1", "--format=%cs"),
      topics = NA_character_,
      latest_release = NA_character_,
      archived = FALSE
    )
  )
}

# All immediate subdirectories of root that look like git repos or plain
# package checkouts.
owd_local_repos <- function(root) {
  dirs <- list.dirs(root, recursive = FALSE)
  dirs[!startsWith(basename(dirs), ".")]
}

# --- GitHub backend ---------------------------------------------------------

owd_gh_token <- function() {
  for (var in c("GITHUB_PAT", "GITHUB_TOKEN", "GH_TOKEN")) {
    tok <- Sys.getenv(var, unset = "")
    if (nzchar(tok)) {
      return(tok)
    }
  }
  ""
}

# GET a URL to a temp file with one retry; returns the path or NULL.
owd_http_fetch <- function(url, headers = character(), tries = 3) {
  for (i in seq_len(tries)) {
    dest <- tempfile()
    ok <- tryCatch(
      {
        suppressWarnings(utils::download.file(
          url, dest,
          quiet = TRUE, mode = "wb", headers = headers
        ))
        TRUE
      },
      error = function(e) FALSE
    )
    if (ok) {
      return(dest)
    }
    unlink(dest)
    if (i < tries) Sys.sleep(2^i)
  }
  NULL
}

owd_gh_api <- function(path, org = "openwashdata") {
  headers <- c(Accept = "application/vnd.github+json")
  tok <- owd_gh_token()
  if (nzchar(tok)) {
    headers <- c(headers, Authorization = paste("Bearer", tok))
  }
  f <- owd_http_fetch(paste0("https://api.github.com", path), headers, tries = 2)
  if (is.null(f)) {
    return(NULL)
  }
  on.exit(unlink(f))
  tryCatch(jsonlite::fromJSON(f, simplifyVector = TRUE), error = function(e) NULL)
}

# One paginated listing of all non-archived org repos.
owd_github_repos <- function(org = "openwashdata") {
  repos <- character()
  archived <- character()
  page <- 1
  repeat {
    batch <- owd_gh_api(sprintf("/orgs/%s/repos?per_page=100&page=%d", org, page))
    if (is.null(batch) || length(batch) == 0 || is.null(batch$name)) break
    repos <- c(repos, batch$name[!batch$archived])
    archived <- c(archived, batch$name[batch$archived])
    if (nrow(batch) < 100) break
    page <- page + 1
  }
  if (length(repos) == 0) {
    stop("Could not list repositories for org ", org)
  }
  list(active = repos, archived = archived)
}

owd_github_source <- function(repo, org = "openwashdata") {
  info <- owd_gh_api(paste0("/repos/", org, "/", repo))
  if (is.null(info) || is.null(info$default_branch)) {
    stop("repos API request failed for ", repo)
  }
  branch <- info$default_branch
  release <- owd_gh_api(paste0("/repos/", org, "/", repo, "/releases/latest"))

  fetch_text <- function(base, rel) {
    url <- paste0(base, "/", org, "/", repo, "/", branch, "/", utils::URLencode(rel))
    f <- owd_http_fetch(url, tries = 2)
    if (is.null(f)) {
      return(NA_character_)
    }
    on.exit(unlink(f))
    owd_as_utf8(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  }
  read_file <- function(rel) {
    fetch_text("https://raw.githubusercontent.com", rel)
  }
  # media.githubusercontent.com serves the stored object for git-lfs
  # pointers, which raw.githubusercontent.com does not resolve.
  read_file_media <- function(rel) {
    fetch_text("https://media.githubusercontent.com/media", rel)
  }
  list_files <- function(rel) {
    listing <- owd_gh_api(paste0(
      "/repos/", org, "/", repo, "/contents/", utils::URLencode(rel), "?ref=", branch
    ))
    if (is.null(listing) || is.null(listing$name)) {
      return(character())
    }
    listing$name
  }
  as_date_chr <- function(x) {
    if (is.null(x) || is.na(x)) NA_character_ else substr(x, 1, 10)
  }
  list(
    repo = repo,
    read_file = read_file,
    read_file_media = read_file_media,
    list_files = list_files,
    meta = list(
      default_branch = branch,
      created_at = as_date_chr(info$created_at),
      pushed_at = as_date_chr(info$pushed_at),
      topics = if (length(info$topics) > 0) paste(info$topics, collapse = ", ") else NA_character_,
      latest_release = if (!is.null(release$tag_name)) release$tag_name else NA_character_,
      archived = isTRUE(info$archived)
    )
  )
}
