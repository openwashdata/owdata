test_that("empty prototypes carry the full documented schema", {
  pkgs <- owdata:::empty_catalog_tbl("owd_packages")
  expect_s3_class(pkgs, "tbl_df")
  expect_equal(nrow(pkgs), 0)
  expect_true(all(c(
    "pkg_name", "title", "description", "version", "tier", "legacy",
    "maintainer", "maintainer_orcid", "authors", "license", "date", "doi",
    "cff_version", "url_github", "url_docs", "n_datasets", "latest_release",
    "default_branch", "created_at", "last_commit", "topics",
    "has_dictionary", "has_extdata"
  ) %in% names(pkgs)))
  expect_s3_class(pkgs$tier, "factor")
  expect_equal(levels(pkgs$tier), c("dev", "candidate", "catalogued"))
  expect_s3_class(pkgs$date, "Date")
  expect_type(pkgs$legacy, "logical")
  expect_type(pkgs$n_datasets, "integer")

  ds <- owdata:::empty_catalog_tbl("owd_datasets")
  expect_equal(
    names(ds),
    c(
      "pkg_name", "dataset_name", "title", "description", "n_rows",
      "n_vars", "n_vars_dictionary", "csv_url", "xlsx_url"
    )
  )

  vars <- owdata:::empty_catalog_tbl("owd_variables")
  expect_equal(
    names(vars),
    c("pkg_name", "dataset_name", "variable_name", "variable_type", "description")
  )
})

test_that("accessors return schema-complete empty tables before the first harvest", {
  # Asserts the documented pre-harvest behavior; skipped automatically
  # once a harvested catalog ships in data/ or a refresh cache exists.
  skip_if(
    !is.na(owdata:::installed_harvest_date()),
    "shipped catalog data present"
  )
  skip_if(
    !is.null(tryCatch(owdata:::refreshed_table("owd_packages"), error = function(e) NULL)),
    "a refreshed catalog cache is present"
  )
  expect_equal(nrow(owd_packages()), 0)
  expect_equal(nrow(owd_datasets()), 0)
  expect_equal(nrow(owd_variables()), 0)
  expect_named(owd_packages(), names(owdata:::empty_catalog_tbl("owd_packages")))
})
