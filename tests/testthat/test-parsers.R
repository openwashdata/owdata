read_fixture <- function(name) {
  paste(
    readLines(test_path("fixtures", name), warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
}

# --- dictionary.csv fixtures (real files from org repos) --------------------

std_cols <- c("directory", "file_name", "variable_name", "variable_type", "description")

expect_standard_dictionary <- function(fixture) {
  res <- owd_parse_dictionary(read_fixture(fixture))
  expect_equal(res$status, "ok", info = fixture)
  expect_equal(res$schema, "standard", info = fixture)
  expect_equal(names(res$data), std_cols, info = fixture)
  expect_gt(nrow(res$data), 0)
  expect_false(any(is.na(res$data$variable_name)))
  expect_false(any(grepl('"', names(res$data))))
  res
}

test_that("clean standard dictionary parses", {
  res <- expect_standard_dictionary("dictionary-standard.csv")
  expect_true(all(grepl("\\.rda$", res$data$file_name)))
})

test_that("space-padded column names are trimmed", {
  expect_standard_dictionary("dictionary-space-padded.csv")
})

test_that("fully quoted headers are normalized", {
  expect_standard_dictionary("dictionary-quoted-header.csv")
})

test_that("double-double-quoted headers are normalized", {
  res <- expect_standard_dictionary("dictionary-double-double-quoted.csv")
  expect_false(any(grepl('^"', res$data$directory), na.rm = TRUE))
})

test_that("trailing empty columns are dropped", {
  res <- expect_standard_dictionary("dictionary-trailing-empty-columns.csv")
  expect_true(any(grepl("dropped|unnamed", res$notes)))
})

test_that("extra columns are ignored but the five standard ones survive", {
  res <- expect_standard_dictionary("dictionary-extra-columns.csv")
  expect_true(any(grepl("extra column", res$notes)))
})

test_that("a leading unnamed column is dropped", {
  expect_standard_dictionary("dictionary-leading-unnamed-column.csv")
})

test_that("deprecated two-column schema with BOM maps to the standard shape", {
  res <- owd_parse_dictionary(read_fixture("dictionary-bom-two-column.csv"))
  expect_equal(res$status, "ok")
  expect_equal(res$schema, "two_column")
  expect_equal(names(res$data), std_cols)
  expect_gt(nrow(res$data), 0)
  expect_true(all(is.na(res$data$file_name)))
  # The BOM must not contaminate the first variable name. Whether the
  # BOM is consumed at read time or by the parser is locale dependent,
  # so only the outcome is asserted, not the notes.
  expect_false(any(grepl("\ufeff", res$data$variable_name)))
})

test_that("git-lfs pointer files are detected, not parsed", {
  res <- owd_parse_dictionary(read_fixture("dictionary-lfs-pointer.csv"))
  expect_equal(res$status, "lfs_pointer")
  expect_null(res$data)
})

test_that("garbage input lands in an error result, never an R error", {
  expect_equal(owd_parse_dictionary(NA_character_)$status, "error")
  expect_equal(owd_parse_dictionary("")$status, "error")
  expect_equal(owd_parse_dictionary("a,b\n1,2")$status, "error")
  expect_equal(owd_parse_dictionary("just some prose, no table at all")$status, "error")
})

# --- DESCRIPTION ------------------------------------------------------------

test_that("standard DESCRIPTION parses fully", {
  d <- owd_parse_description(read_fixture("DESCRIPTION-standard"))
  expect_equal(d$package, "washmalawi")
  expect_equal(d$version, "1.0.1")
  expect_equal(d$license, "CC BY 4.0")
  expect_equal(d$maintainer, "Emmanuel Mhango")
  expect_equal(d$maintainer_orcid, "0000-0003-3197-6244")
  expect_match(d$authors, "Emmanuel Mhango; Donald Robertson")
  expect_s3_class(d$date, "Date")
  expect_false(grepl("\n", d$description))
})

test_that("malformed version survives DESCRIPTION parsing for the tier layer", {
  d <- owd_parse_description(read_fixture("DESCRIPTION-malformed-version"))
  expect_equal(d$version, "v1.0.0")
  expect_equal(owd_normalize_version(d$version), "1.0.0")
})

test_that("broken DESCRIPTION degrades to NA fields", {
  d <- owd_parse_description("not a dcf file at all\n\n\nreally not")
  expect_true(is.na(d$package))
  d <- owd_parse_description("Package: x\nAuthors@R: not valid R code (")
  expect_equal(d$package, "x")
  expect_true(is.na(d$maintainer))
})

# --- CITATION.cff -----------------------------------------------------------

test_that("doi and version come out of a real CITATION.cff", {
  cff <- owd_parse_cff(read_fixture("CITATION-standard.cff"))
  expect_equal(cff$doi, "10.5281/zenodo.15799918")
  expect_equal(cff$version, "1.0.1")
})

test_that("identifiers block and quoted values are handled", {
  text <- paste(
    "cff-version: 1.2.0",
    "title: demo",
    "identifiers:",
    "  - type: doi",
    "    value: \"10.5281/zenodo.999\"",
    "version: '0.1.0'",
    sep = "\n"
  )
  cff <- owd_parse_cff(text)
  expect_equal(cff$doi, "10.5281/zenodo.999")
  expect_equal(cff$version, "0.1.0")
})

test_that("missing CITATION.cff yields NA fields", {
  cff <- owd_parse_cff(NA_character_)
  expect_true(is.na(cff$doi))
  expect_true(is.na(cff$version))
  cff <- owd_parse_cff("{ not yaml")
  expect_true(is.na(cff$doi))
})

# --- @format variants -------------------------------------------------------

test_that("all known @format variants parse to dimensions", {
  expect_equal(
    unname(owd_parse_format_dims("A tibble with 4548 rows and 35 variables")),
    c(4548L, 35L)
  )
  expect_equal(
    unname(owd_parse_format_dims("A tibble with 23112 rows and 27 variables")),
    c(23112L, 27L)
  )
  # Reversed order with thousands separator.
  expect_equal(
    unname(owd_parse_format_dims("A tibble with 10 columns and 790,375 rows.")),
    c(790375L, 10L)
  )
  expect_equal(
    unname(owd_parse_format_dims("A data frame with 100 observations and 5 columns")),
    c(100L, 5L)
  )
  expect_equal(
    unname(owd_parse_format_dims("nothing numeric here")),
    c(NA_integer_, NA_integer_)
  )
})

test_that("roxygen data docs parse from a real org file", {
  docs <- owd_parse_data_docs(read_fixture("data-docs-gdho.R"))
  expect_equal(nrow(docs), 1)
  expect_equal(docs$dataset_name, "gdho")
  expect_match(docs$title, "Global Database")
  expect_equal(docs$n_rows, 4548L)
  expect_equal(docs$n_vars, 35L)
})

test_that("format tag variants at block level all parse", {
  make <- function(format_line) {
    paste(
      "#' Demo dataset",
      "#'",
      "#' A description line.",
      format_line,
      "\"demo\"",
      sep = "\n"
    )
  }
  # Trailing colon after @format.
  docs <- owd_parse_data_docs(make("#' @format: A tibble with 10 rows and 2 variables"))
  expect_equal(c(docs$n_rows, docs$n_vars), c(10L, 2L))
  # No space between #' and @format.
  docs <- owd_parse_data_docs(make("#'@format A tibble with 10 rows and 2 variables"))
  expect_equal(c(docs$n_rows, docs$n_vars), c(10L, 2L))
  # Unrecognized format text returns NA dims but keeps the dataset.
  docs <- owd_parse_data_docs(make("#' @format Something else entirely"))
  expect_equal(docs$dataset_name, "demo")
  expect_true(is.na(docs$n_rows))
})

test_that("files without data docs yield zero rows", {
  expect_equal(nrow(owd_parse_data_docs("x <- function() 1")), 0)
  expect_equal(nrow(owd_parse_data_docs(NA_character_)), 0)
})
