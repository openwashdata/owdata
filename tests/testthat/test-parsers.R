DICT_COLS <- c(
  "directory", "file_name", "variable_name", "variable_type", "description"
)

test_that("clean and pathological dictionary headers all normalize", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  for (fixture in c(
    "dict_standard.csv", "dict_quoted_headers.csv", "dict_space_padded.csv",
    "dict_trailing_empty.csv", "dict_extra_columns.csv",
    "dict_leading_unnamed.csv", "dict_double_quoted.csv"
  )) {
    out <- e$parse_dictionary(fixture_path(fixture))
    expect_equal(out$schema, "standard", label = fixture)
    expect_equal(names(out$data), DICT_COLS, label = fixture)
    expect_gt(nrow(out$data), 0, label = fixture)
    expect_true(is.na(out$problem), label = fixture)
  }
})

test_that("extra dictionary columns are ignored, not kept", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$parse_dictionary(fixture_path("dict_extra_columns.csv"))
  expect_false(any(c("unit_type", "error") %in% names(out$data)))
})

test_that("deprecated 2-column schema with BOM maps to the single dataset", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$parse_dictionary(
    fixture_path("dict_two_column_bom.csv"),
    single_dataset = "waterpoints"
  )
  expect_equal(out$schema, "deprecated2")
  expect_equal(names(out$data), DICT_COLS)
  expect_equal(unique(out$data$file_name), "waterpoints")
  expect_equal(out$data$variable_name[[1]], "id")
})

test_that("git-lfs pointer files are detected and routed to problems", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$parse_dictionary(fixture_path("dict_lfs_pointer.csv"))
  expect_null(out$data)
  expect_match(out$problem, "git-lfs")
})

test_that("parse_description extracts fields, maintainer, and ORCID", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  txt <- paste(
    "Package: washexample",
    "Title: Example Data",
    "Version: v1.0.0",
    "Authors@R: c(",
    "    person(\"Ada\", \"Lovelace\", , \"ada@example.org\", role = c(\"aut\", \"cre\"),",
    "           comment = c(ORCID = \"0000-0001-8271-5555\")),",
    "    person(\"Grace\", \"Hopper\", role = \"aut\"))",
    "Description: Example data for parser tests,",
    "    wrapped over two lines.",
    "License: CC BY 4.0",
    sep = "\n"
  )
  out <- e$parse_description(txt)
  expect_equal(out$package, "washexample")
  expect_equal(out$version, "v1.0.0")
  expect_equal(out$maintainer, "Ada Lovelace")
  expect_equal(out$maintainer_orcid, "0000-0001-8271-5555")
  expect_equal(out$authors, "Ada Lovelace; Grace Hopper")
  expect_match(out$description, "wrapped over two lines")
})

test_that("parse_description degrades instead of failing on bad Authors@R", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$parse_description(
    "Package: broken\nVersion: 0.1.0\nAuthors@R: not_valid_r_code("
  )
  expect_equal(out$package, "broken")
  expect_true(is.na(out$maintainer))
  expect_null(e$parse_description("not a dcf file at all\nstill not"))
})

test_that("parse_cff finds doi and version including quoted values", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  out <- e$parse_cff(
    "cff-version: 1.2.0\ndoi: 10.5281/zenodo.12345\nversion: '0.1.0'\n"
  )
  expect_equal(out$doi, "10.5281/zenodo.12345")
  expect_equal(out$version, "0.1.0")

  ids <- e$parse_cff(
    "cff-version: 1.2.0\nidentifiers:\n  - type: doi\n    value: 10.5281/zenodo.999\nversion: 1.0.0\n"
  )
  expect_equal(ids$doi, "10.5281/zenodo.999")
})

test_that("every observed @format variant parses to dimensions", {
  skip_if_not(has_data_raw(), "data-raw not available under R CMD check")
  e <- data_raw_env()

  block <- function(fmt) {
    paste(
      "#' Waterpoint observations",
      "#'",
      "#' Observations of waterpoints in four regions.",
      "#'",
      paste0("#' ", fmt),
      "\"waterpoints\"",
      sep = "\n"
    )
  }
  variants <- list(
    dominant = list("@format A tibble with 100 rows and 8 variables", 100L, 8L),
    colon = list("@format: A tibble with 100 rows and 8 variables", 100L, 8L),
    reversed_thousands = list(
      "@format: A tibble with 10 columns and 790,375 rows.", 790375L, 10L
    )
  )
  for (nm in names(variants)) {
    v <- variants[[nm]]
    out <- e$parse_roxygen_format(block(v[[1]]))
    expect_equal(nrow(out), 1, label = nm)
    expect_equal(out$n_rows, v[[2]], label = nm)
    expect_equal(out$n_vars, v[[3]], label = nm)
    expect_equal(out$dataset_name, "waterpoints", label = nm)
    expect_equal(out$title, "Waterpoint observations", label = nm)
    expect_match(out$description, "four regions", label = nm)
  }

  no_space <- paste(
    "#' Title line",
    "#'",
    "#'@format A tibble with 5 rows and 2 variables",
    "\"tinydata\"",
    sep = "\n"
  )
  out <- e$parse_roxygen_format(no_space)
  expect_equal(out$n_rows, 5L)
  expect_equal(out$n_vars, 2L)

  unknown <- e$parse_roxygen_format(block("@format Something unrecognizable"))
  expect_equal(nrow(unknown), 1)
  expect_true(is.na(unknown$n_rows))
  expect_true(is.na(unknown$n_vars))
})
