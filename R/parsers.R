# Hardened parsers for per-package metadata files.
#
# These functions parse text already fetched by a harvest backend
# (data-raw/harvest_helpers.R); they never touch the network or the
# filesystem themselves, which keeps them unit testable against the
# fixtures in tests/testthat/fixtures/. Every function is written so a
# malformed input degrades to NA fields or a flagged result instead of an
# error; the harvest treats failures as data, not exceptions.

# --- DESCRIPTION ------------------------------------------------------------

#' Parse a DESCRIPTION file
#'
#' @param text Full contents of a DESCRIPTION file as a single string.
#' @return A list with fields package, title, description, version,
#'   license, date (Date), url, maintainer, maintainer_orcid, authors.
#'   Missing or unparseable fields are NA.
#' @keywords internal
#' @noRd
owd_parse_description <- function(text) {
  out <- list(
    package = NA_character_, title = NA_character_,
    description = NA_character_, version = NA_character_,
    license = NA_character_, date = as.Date(NA), url = NA_character_,
    maintainer = NA_character_, maintainer_orcid = NA_character_,
    authors = NA_character_
  )
  dcf <- tryCatch(
    read.dcf(textConnection(text)),
    error = function(e) NULL
  )
  if (is.null(dcf) || nrow(dcf) == 0) {
    return(out)
  }
  field <- function(name) {
    if (name %in% colnames(dcf) && !is.na(dcf[1, name])) unname(dcf[1, name]) else NA_character_
  }
  squash <- function(x) {
    if (is.na(x)) NA_character_ else trimws(gsub("\\s+", " ", x))
  }
  out$package <- squash(field("Package"))
  out$title <- squash(field("Title"))
  out$description <- squash(field("Description"))
  out$version <- squash(field("Version"))
  out$license <- squash(field("License"))
  out$url <- squash(field("URL"))

  date_raw <- field("Date")
  if (!is.na(date_raw)) {
    out$date <- tryCatch(as.Date(trimws(date_raw)), error = function(e) as.Date(NA))
  }

  people <- owd_parse_authors(field("Authors@R"))
  if (is.null(people)) {
    # Old-style Maintainer: "Given Family <email>"
    maint <- field("Maintainer")
    if (!is.na(maint)) {
      out$maintainer <- squash(sub("<[^>]*>", "", maint))
      out$authors <- out$maintainer
    }
    return(out)
  }
  out$maintainer <- people$maintainer
  out$maintainer_orcid <- people$maintainer_orcid
  out$authors <- people$authors
  out
}

# Evaluate an Authors@R field and extract maintainer plus author list.
# Returns NULL when the field is absent or does not evaluate to persons.
owd_parse_authors <- function(authors_r) {
  if (is.na(authors_r)) {
    return(NULL)
  }
  persons <- tryCatch(
    # utils::person() must be findable when the field is evaluated.
    eval(parse(text = authors_r), envir = new.env(parent = asNamespace("utils"))),
    error = function(e) NULL
  )
  if (!inherits(persons, "person") || length(persons) == 0) {
    return(NULL)
  }
  entries <- unclass(persons)
  name_of <- function(p) {
    trimws(paste(
      paste(p$given %||% character(), collapse = " "),
      paste(p$family %||% character(), collapse = " ")
    ))
  }
  roles <- lapply(entries, function(p) p$role %||% character())
  is_cre <- vapply(roles, function(r) "cre" %in% r, logical(1))
  is_aut <- vapply(roles, function(r) any(c("aut", "cre") %in% r), logical(1))
  names_all <- vapply(entries, name_of, character(1))

  maintainer <- NA_character_
  maintainer_orcid <- NA_character_
  if (any(is_cre)) {
    cre <- entries[[which(is_cre)[1]]]
    maintainer <- name_of(cre)
    comment <- cre$comment
    if (!is.null(comment) && "ORCID" %in% names(comment)) {
      maintainer_orcid <- sub("^https?://orcid\\.org/", "", comment[["ORCID"]])
    }
  }
  authors <- if (any(is_aut)) {
    paste(names_all[is_aut & nzchar(names_all)], collapse = "; ")
  } else {
    NA_character_
  }
  list(
    maintainer = maintainer,
    maintainer_orcid = maintainer_orcid,
    authors = authors
  )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# --- dictionary.csv ---------------------------------------------------------

owd_dictionary_columns <- function() {
  c("directory", "file_name", "variable_name", "variable_type", "description")
}

#' Parse a data-raw/dictionary.csv file
#'
#' Handles every pathology observed across the org (see
#' tests/testthat/fixtures/): fully quoted headers, double-double-quoted
#' headers, space-padded names, trailing empty columns, extra columns,
#' leading unnamed columns, a UTF-8 BOM, the deprecated two-column schema,
#' and git-lfs pointer files.
#'
#' @param text Full contents of the file as a single string.
#' @return A list with fields status ("ok", "lfs_pointer" or "error"),
#'   schema ("standard" or "two_column"), data (tibble with the five
#'   standard columns, NULL unless status is "ok") and notes (character
#'   vector of normalizations applied).
#' @keywords internal
#' @noRd
owd_parse_dictionary <- function(text) {
  res <- list(status = "error", schema = NA_character_, data = NULL, notes = character())
  if (is.null(text) || length(text) != 1 || is.na(text) || !nzchar(trimws(text))) {
    res$notes <- "empty or missing file"
    return(res)
  }
  if (grepl("^version https://git-lfs", text)) {
    res$status <- "lfs_pointer"
    res$notes <- "git-lfs pointer file; content must be fetched from the media endpoint"
    return(res)
  }
  txt <- sub("^\ufeff", "", text)
  if (!identical(txt, text)) {
    res$notes <- c(res$notes, "stripped UTF-8 BOM")
  }
  df <- tryCatch(
    utils::read.csv(
      text = txt, header = TRUE, colClasses = "character",
      check.names = FALSE, na.strings = c("NA", ""), fill = TRUE,
      stringsAsFactors = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(df) || ncol(df) == 0) {
    res$notes <- c(res$notes, "read.csv failed on file contents")
    return(res)
  }

  nm <- names(df)
  nm_clean <- tolower(trimws(gsub('"', "", nm, fixed = TRUE)))
  # Second line of defense: depending on the locale, a BOM can survive
  # into the first header name instead of the raw text.
  nm_clean <- sub("^\ufeff", "", nm_clean)
  if (!identical(nm_clean, nm)) {
    res$notes <- c(res$notes, "normalized header names")
  }
  names(df) <- nm_clean

  unnamed <- !nzchar(nm_clean)
  if (any(unnamed)) {
    df <- df[, !unnamed, drop = FALSE]
    res$notes <- c(res$notes, sprintf("dropped %d unnamed column(s)", sum(unnamed)))
  }

  std <- owd_dictionary_columns()
  present <- intersect(std, names(df))

  if (setequal(present, c("variable_name", "description"))) {
    res$schema <- "two_column"
    df <- df[, c("variable_name", "description"), drop = FALSE]
    df$directory <- NA_character_
    df$file_name <- NA_character_
    df$variable_type <- NA_character_
    res$notes <- c(res$notes, "deprecated two-column schema")
  } else if (all(c("file_name", "variable_name") %in% present)) {
    res$schema <- "standard"
    extra <- setdiff(names(df), std)
    if (length(extra) > 0) {
      res$notes <- c(res$notes, paste("ignored extra column(s):", paste(extra, collapse = ", ")))
    }
    for (col in setdiff(std, names(df))) {
      df[[col]] <- NA_character_
    }
  } else {
    res$notes <- c(res$notes, paste(
      "unrecognized schema; columns:", paste(names(df), collapse = ", ")
    ))
    return(res)
  }

  df <- df[, std, drop = FALSE]
  for (col in std) {
    x <- trimws(df[[col]])
    x <- gsub('^"+|"+$', "", x)
    x[!is.na(x) & !nzchar(x)] <- NA_character_
    df[[col]] <- x
  }
  df <- df[!is.na(df$variable_name), , drop = FALSE]

  res$status <- "ok"
  res$data <- tibble::as_tibble(df)
  res
}

# --- CITATION.cff -----------------------------------------------------------

#' Extract doi and version from a CITATION.cff file
#'
#' Deliberately regex based rather than a full YAML parse: only two scalar
#' fields are needed and a broken YAML file must not abort the harvest.
#' Falls back to the identifiers block when no top-level doi exists.
#'
#' @param text Full contents of the file as a single string, or NA.
#' @return A list with fields doi and version, NA where absent.
#' @keywords internal
#' @noRd
owd_parse_cff <- function(text) {
  out <- list(doi = NA_character_, version = NA_character_)
  if (is.null(text) || length(text) != 1 || is.na(text)) {
    return(out)
  }
  lines <- strsplit(text, "\r?\n")[[1]]
  unquote <- function(x) gsub('^["\']|["\']$', "", trimws(x))

  doi_line <- grep("^doi:", lines, value = TRUE)
  if (length(doi_line) > 0) {
    out$doi <- unquote(sub("^doi:", "", doi_line[1]))
  } else {
    # identifiers:
    #   - type: doi
    #     value: 10.5281/zenodo.123
    type_idx <- grep("^\\s*-\\s*type:\\s*doi\\s*$", lines)
    for (i in type_idx) {
      window <- lines[seq(i + 1, min(i + 2, length(lines)))]
      val <- grep("^\\s*value:", window, value = TRUE)
      if (length(val) > 0) {
        out$doi <- unquote(sub("^\\s*value:", "", val[1]))
        break
      }
    }
  }
  ver_line <- grep("^version:", lines, value = TRUE)
  if (length(ver_line) > 0) {
    out$version <- unquote(sub("^version:", "", ver_line[1]))
  }
  if (!is.na(out$doi)) {
    out$doi <- sub("^https?://doi\\.org/", "", out$doi)
    if (!nzchar(out$doi)) out$doi <- NA_character_
  }
  if (!is.na(out$version) && !nzchar(out$version)) out$version <- NA_character_
  out
}

# --- roxygen data docs ------------------------------------------------------

#' Parse dataset dimensions out of an @format line
#'
#' Tolerates every observed variant: "A tibble with N rows and M
#' variables", a trailing colon after the tag, "#'@format" without a
#' space, reversed order with a thousands separator ("10 columns and
#' 790,375 rows."). Anything unrecognized returns NA dimensions.
#'
#' @param text The text following the @format tag.
#' @return Integer vector c(n_rows, n_vars), NA where not found.
#' @keywords internal
#' @noRd
owd_parse_format_dims <- function(text) {
  dims <- c(n_rows = NA_integer_, n_vars = NA_integer_)
  if (is.null(text) || length(text) == 0 || all(is.na(text))) {
    return(dims)
  }
  txt <- paste(text, collapse = " ")
  grab <- function(pattern) {
    m <- regmatches(txt, regexpr(pattern, txt, ignore.case = TRUE, perl = TRUE))
    if (length(m) == 0) {
      return(NA_integer_)
    }
    num <- gsub("[^0-9]", "", sub("\\s.*$", "", m))
    as.integer(num)
  }
  dims["n_rows"] <- grab("[0-9][0-9,.']*\\s+(rows?|observations?|obs\\b)")
  dims["n_vars"] <- grab("[0-9][0-9,.']*\\s+(variables?|columns?|vars?\\b|cols?\\b)")
  dims
}

#' Parse roxygen data documentation from an R source file
#'
#' Finds each roxygen block that documents a dataset (the block is
#' followed by a quoted dataset name, or carries an @name tag) and
#' extracts the dataset name, title, description and @format dimensions.
#'
#' @param text Full contents of an R file as a single string.
#' @return A tibble with columns dataset_name, title, description,
#'   n_rows, n_vars. Zero rows when the file documents no dataset.
#' @keywords internal
#' @noRd
owd_parse_data_docs <- function(text) {
  empty <- tibble::tibble(
    dataset_name = character(), title = character(),
    description = character(), n_rows = integer(), n_vars = integer()
  )
  if (is.null(text) || length(text) != 1 || is.na(text)) {
    return(empty)
  }
  lines <- strsplit(text, "\r?\n")[[1]]
  is_roxy <- grepl("^\\s*#'", lines)
  if (!any(is_roxy)) {
    return(empty)
  }
  # Identify runs of consecutive roxygen lines.
  runs <- rle(is_roxy)
  ends <- cumsum(runs$lengths)
  starts <- ends - runs$lengths + 1
  blocks <- which(runs$values)

  rows <- vector("list", length(blocks))
  for (k in seq_along(blocks)) {
    b <- blocks[k]
    content <- sub("^\\s*#'\\s?", "", lines[starts[b]:ends[b]])

    # Dataset name: @name tag wins, else the next quoted string statement.
    name <- NA_character_
    name_tag <- grep("^@name\\s+", content, value = TRUE)
    if (length(name_tag) > 0) {
      name <- trimws(sub("^@name\\s+", "", name_tag[1]))
    } else {
      after <- lines[seq(min(ends[b] + 1, length(lines)), min(ends[b] + 3, length(lines)))]
      after <- after[nzchar(trimws(after))]
      if (length(after) > 0) {
        m <- regmatches(after[1], regexec("^\\s*[\"']([^\"']+)[\"']\\s*$", after[1]))[[1]]
        if (length(m) == 2) name <- m[2]
      }
    }
    if (is.na(name) || !nzchar(name)) next

    tag_idx <- grep("^@", content)
    pre_tag <- if (length(tag_idx) > 0) content[seq_len(tag_idx[1] - 1)] else content
    pre_tag <- trimws(pre_tag)
    pre_tag <- pre_tag[nzchar(pre_tag)]
    title <- if (length(pre_tag) > 0) pre_tag[1] else NA_character_
    description <- if (length(pre_tag) > 1) {
      trimws(gsub("\\s+", " ", paste(pre_tag[-1], collapse = " ")))
    } else {
      NA_character_
    }

    fmt_idx <- grep("^@format:?", content)
    dims <- c(n_rows = NA_integer_, n_vars = NA_integer_)
    if (length(fmt_idx) > 0) {
      i <- fmt_idx[1]
      rest <- content[seq(i, length(content))]
      stop_at <- grep("^@|^\\\\describe", rest[-1])
      fmt_text <- if (length(stop_at) > 0) rest[seq_len(stop_at[1])] else rest
      fmt_text[1] <- sub("^@format:?\\s*", "", fmt_text[1])
      dims <- owd_parse_format_dims(fmt_text)
    }

    rows[[k]] <- tibble::tibble(
      dataset_name = name, title = title, description = description,
      n_rows = dims[["n_rows"]], n_vars = dims[["n_vars"]]
    )
  }
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(empty)
  }
  out <- do.call(rbind, rows)
  out[!duplicated(out$dataset_name), , drop = FALSE]
}
