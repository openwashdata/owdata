# Hardened parsers for per-package metadata files (issue #3), plus the
# r-universe registry generator. Unit tested in
# tests/testthat/test-parsers.R and test-registry.R against fixtures in
# tests/testthat/fixtures/ (tests are skipped under R CMD check because
# data-raw/ is not part of the built package).
#
# Parser contract: no call may abort the harvest run. Failures are
# data, not errors: on unrecoverable input a parser returns NULL and
# the caller records the package in the problems tibble.

# ---- generic text guards ----------------------------------------------

is_lfs_pointer <- function(lines) {
  length(lines) > 0 && startsWith(lines[[1]], "version https://git-lfs")
}

strip_bom <- function(x) {
  sub("^\uFEFF", "", x)
}

read_text_lines <- function(path_or_text) {
  if (length(path_or_text) == 1 && file.exists(path_or_text)) {
    lines <- readLines(path_or_text, warn = FALSE, encoding = "UTF-8")
  } else {
    lines <- unlist(strsplit(paste(path_or_text, collapse = "\n"), "\n"))
  }
  if (length(lines) > 0) {
    lines[[1]] <- strip_bom(lines[[1]])
  }
  lines
}

# ---- DESCRIPTION -------------------------------------------------------

# Returns a named list of the fields the catalog needs, or NULL when the
# file cannot be read as DCF at all. Authors@R is evaluated defensively;
# a malformed field degrades to NA authors rather than a failure.
parse_description <- function(path_or_text) {
  lines <- read_text_lines(path_or_text)
  dcf <- tryCatch(
    read.dcf(textConnection(lines)),
    error = function(e) NULL
  )
  if (is.null(dcf) || nrow(dcf) == 0) {
    return(NULL)
  }
  field <- function(name) {
    if (name %in% colnames(dcf)) {
      val <- unname(dcf[1, name])
      if (is.na(val)) NA_character_ else gsub("\\s+", " ", trimws(val))
    } else {
      NA_character_
    }
  }

  maintainer <- NA_character_
  maintainer_orcid <- NA_character_
  authors <- NA_character_
  authors_r <- field("Authors@R")
  if (!is.na(authors_r)) {
    persons <- tryCatch(
      eval(
        parse(text = authors_r),
        envir = list(person = utils::person),
        enclos = baseenv()
      ),
      error = function(e) NULL
    )
    if (!is.null(persons)) {
      persons <- as.list(persons)
      fmt_one <- function(p) {
        trimws(paste(
          paste(p$given, collapse = " "),
          paste(p$family, collapse = " ")
        ))
      }
      is_cre <- vapply(persons, function(p) "cre" %in% p$role, logical(1))
      is_aut <- vapply(
        persons,
        function(p) any(c("aut", "cre") %in% p$role),
        logical(1)
      )
      if (any(is_cre)) {
        cre <- persons[is_cre][[1]]
        maintainer <- fmt_one(cre)
        orcid <- unlist(cre$comment)[names(unlist(cre$comment)) == "ORCID"]
        if (length(orcid) == 1) {
          maintainer_orcid <- unname(orcid)
        }
      }
      if (any(is_aut)) {
        authors <- paste(
          vapply(persons[is_aut], fmt_one, character(1)),
          collapse = "; "
        )
      }
    }
  }

  date <- suppressWarnings(as.Date(field("Date")))

  list(
    package = field("Package"),
    title = field("Title"),
    description = field("Description"),
    version = field("Version"),
    license = field("License"),
    url = field("URL"),
    date = date,
    maintainer = maintainer,
    maintainer_orcid = maintainer_orcid,
    authors = authors
  )
}

# ---- dictionary.csv ----------------------------------------------------

DICTIONARY_COLUMNS <- c(
  "directory", "file_name", "variable_name", "variable_type", "description"
)

# Returns a list(data = data.frame over DICTIONARY_COLUMNS,
# schema = "standard" | "deprecated2", problem = NA or reason).
# On unrecoverable input returns list(data = NULL, problem = reason).
parse_dictionary <- function(path_or_text, single_dataset = NA_character_) {
  fail <- function(reason) list(data = NULL, schema = NA_character_, problem = reason)

  lines <- tryCatch(read_text_lines(path_or_text), error = function(e) NULL)
  if (is.null(lines) || length(lines) == 0) {
    return(fail("dictionary unreadable or empty"))
  }
  if (is_lfs_pointer(lines)) {
    return(fail("git-lfs pointer file; refetch via the raw content API"))
  }

  df <- tryCatch(
    utils::read.csv(
      textConnection(lines),
      stringsAsFactors = FALSE, check.names = FALSE,
      colClasses = "character"
    ),
    error = function(e) NULL
  )
  if (is.null(df) || ncol(df) == 0) {
    return(fail("dictionary could not be parsed as CSV"))
  }

  # Normalize header names: strip quotes (including doubled quotes),
  # trim whitespace, lowercase.
  names(df) <- tolower(trimws(gsub('"', "", names(df))))

  # Drop unnamed columns and columns that are entirely empty.
  named <- nzchar(names(df))
  df <- df[, named, drop = FALSE]
  keep <- vapply(
    df,
    function(col) any(!is.na(col) & nzchar(trimws(col))),
    logical(1)
  )
  df <- df[, keep | names(df) %in% DICTIONARY_COLUMNS, drop = FALSE]

  # Deprecated 2-column schema: variable_name, description. Attribute
  # rows to the package's single dataset when it has exactly one.
  if (setequal(names(df), c("variable_name", "description"))) {
    out <- data.frame(
      directory = "data",
      file_name = if (is.na(single_dataset)) NA_character_ else single_dataset,
      variable_name = df$variable_name,
      variable_type = NA_character_,
      description = df$description,
      stringsAsFactors = FALSE
    )
    return(list(data = out, schema = "deprecated2", problem = NA_character_))
  }

  missing <- setdiff(DICTIONARY_COLUMNS, names(df))
  if (length(missing) > 0) {
    return(fail(paste(
      "dictionary missing columns:", paste(missing, collapse = ", ")
    )))
  }

  # Keep only the five standard columns and ignore extras.
  out <- df[, DICTIONARY_COLUMNS, drop = FALSE]
  list(data = out, schema = "standard", problem = NA_character_)
}

# ---- CITATION.cff ------------------------------------------------------

# Light-touch extraction of the doi and version fields. Deliberately
# regex-based to avoid a YAML dependency in the harvest; the two fields
# are single-line scalars in every observed CITATION.cff.
parse_cff <- function(path_or_text) {
  lines <- tryCatch(read_text_lines(path_or_text), error = function(e) NULL)
  if (is.null(lines)) {
    return(list(doi = NA_character_, version = NA_character_))
  }
  grab <- function(key) {
    hits <- grep(sprintf("^%s:\\s*", key), lines, value = TRUE)
    if (length(hits) == 0) {
      return(NA_character_)
    }
    val <- sub(sprintf("^%s:\\s*", key), "", hits[[1]])
    val <- gsub("^['\"]|['\"]$", "", trimws(val))
    if (nzchar(val)) val else NA_character_
  }
  doi <- grab("doi")
  if (is.na(doi)) {
    # Zenodo also writes the DOI as an identifiers list entry.
    idx <- grep("^\\s*-?\\s*value:\\s*10\\.5281/zenodo\\.", lines)
    if (length(idx) > 0) {
      doi <- trimws(sub("^\\s*-?\\s*value:\\s*", "", lines[[idx[1]]]))
    }
  }
  list(doi = doi, version = grab("version"))
}

# ---- roxygen data docs -------------------------------------------------

# Extracts, per documented object in an R/ file: dataset_name, title,
# description (text before @format), n_rows, n_vars. The @format regex
# tolerates every observed variant (trailing colon, missing space after
# #', reversed order, thousands separators) and returns NA dimensions
# on anything unrecognized rather than failing.
parse_roxygen_format <- function(path_or_text) {
  lines <- tryCatch(read_text_lines(path_or_text), error = function(e) NULL)
  empty <- data.frame(
    dataset_name = character(), title = character(),
    description = character(), n_rows = integer(), n_vars = integer(),
    stringsAsFactors = FALSE
  )
  if (is.null(lines) || length(lines) == 0) {
    return(empty)
  }

  is_roxy <- grepl("^#'", lines)
  blocks <- list()
  i <- 1
  n <- length(lines)
  while (i <= n) {
    if (is_roxy[i]) {
      start <- i
      while (i <= n && is_roxy[i]) i <- i + 1
      # The documented object: next non-empty line, expected to be a
      # quoted dataset name.
      j <- i
      while (j <= n && !nzchar(trimws(lines[j]))) j <- j + 1
      name <- NA_character_
      if (j <= n) {
        m <- regmatches(
          lines[j],
          regexec('^\\s*"([^"]+)"\\s*$', lines[j])
        )[[1]]
        if (length(m) == 2) name <- m[2]
      }
      blocks[[length(blocks) + 1]] <- list(
        text = sub("^#'\\s?", "", lines[start:(i - 1)]),
        name = name
      )
    } else {
      i <- i + 1
    }
  }

  parse_block <- function(block) {
    txt <- block$text
    if (length(txt) == 0 || is.na(block$name)) {
      return(NULL)
    }
    title <- trimws(txt[[1]])
    tag_idx <- grep("^@", txt)
    desc_end <- if (length(tag_idx) > 0) min(tag_idx) - 1 else length(txt)
    description <- trimws(paste(
      txt[seq_len(desc_end)][-1],
      collapse = " "
    ))
    description <- gsub("\\s+", " ", description)

    n_rows <- NA_integer_
    n_vars <- NA_integer_
    fmt_idx <- grep("^@format", txt)
    if (length(fmt_idx) > 0) {
      fmt <- paste(txt[fmt_idx[1]:length(txt)], collapse = " ")
      num <- "([0-9][0-9,]*)"
      unit <- "(rows?|variables?|columns?|cols?)"
      pattern <- sprintf(
        "@format:?\\s+.*?[Aa] (?:tibble|data frame) with\\s+%s\\s+%s\\s+and\\s+%s\\s+%s",
        num, unit, num, unit
      )
      m <- regmatches(fmt, regexec(pattern, fmt))[[1]]
      if (length(m) == 5) {
        val1 <- as.integer(gsub(",", "", m[2]))
        val2 <- as.integer(gsub(",", "", m[4]))
        if (grepl("^row", m[3])) {
          n_rows <- val1
          n_vars <- val2
        } else {
          n_vars <- val1
          n_rows <- val2
        }
      }
    }
    data.frame(
      dataset_name = block$name, title = title, description = description,
      n_rows = n_rows, n_vars = n_vars, stringsAsFactors = FALSE
    )
  }

  parsed <- Filter(Negate(is.null), lapply(blocks, parse_block))
  if (length(parsed) == 0) {
    return(empty)
  }
  do.call(rbind, parsed)
}

# ---- r-universe registry ----------------------------------------------

# Generates the packages.json entries for the openwashdata.r-universe.dev
# registry repo. washr and owdata are included by construction, never by
# a manual note: the custom registry supersedes the auto-generated one,
# so a packages.json without washr would silently remove the org's core
# tooling package from the universe (issue #8, premortem finding R4).
REGISTRY_ALWAYS <- c("washr", "owdata")

make_registry <- function(pkg_names) {
  pkg_names <- union(REGISTRY_ALWAYS, pkg_names)
  pkg_names <- sort(unique(pkg_names[!is.na(pkg_names) & nzchar(pkg_names)]))
  lapply(pkg_names, function(p) {
    list(package = p, url = paste0("https://github.com/openwashdata/", p))
  })
}

write_registry <- function(pkg_names, path = file.path("data-raw", "packages.json")) {
  entries <- make_registry(pkg_names)
  jsonlite::write_json(entries, path, auto_unbox = TRUE, pretty = TRUE)
  invisible(entries)
}
