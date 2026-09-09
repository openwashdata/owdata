# The gate the harvest must pass. Column names and types, non-empty
# tables, and the value-level checks a schema test alone cannot make:
# NA and a mojibake string are both structurally valid (#4, #5).

catalog <- owd_active_catalog()

test_that("the catalog carries its five elements", {
  expect_true(owd_is_catalog(catalog))
  expect_s3_class(catalog$meta$harvest_date, "Date")
  expect_true(nzchar(catalog$meta$org))
  expect_true(catalog$meta$backend %in% c("local", "github"))
})

test_that("owd_packages has the documented columns and types", {
  p <- catalog$packages
  expect_named(p, c(
    "pkg_name", "title", "description", "version", "published", "reviewed",
    "maintainer", "maintainer_orcid", "authors", "license", "date",
    "keywords", "spatial_coverage", "temporal_coverage", "doi",
    "cff_version", "url_github", "url_docs", "n_datasets",
    "latest_release", "default_branch", "created_at", "last_commit",
    "topics", "has_dictionary", "has_extdata",
    "washr_version", "brand_ref", "pkgreview_standard",
    "has_r_cmd_check", "has_pkgdown_workflow", "has_jsonld"
  ))
  expect_gt(nrow(p), 0)
  expect_type(p$pkg_name, "character")
  expect_type(p$published, "logical")
  expect_type(p$n_datasets, "integer")
  expect_s3_class(p$date, "Date")
  expect_false(any(is.na(p$pkg_name)))
})

test_that("owd_datasets and owd_variables have the documented columns", {
  expect_named(catalog$datasets, c(
    "pkg_name", "dataset_name", "title", "description",
    "n_rows", "n_vars", "n_vars_dictionary", "csv_url", "xlsx_url"
  ))
  expect_named(catalog$variables, c(
    "pkg_name", "dataset_name", "variable_name", "variable_type", "description"
  ))
  expect_named(catalog$index, c(
    "pkg_name", "match_type", "dataset_name", "field", "text"
  ))
})

test_that("no value carries a unicode escape", {
  # The defect that put <U+00F6> into 37 places of the first seed data:
  # a harvest run outside a UTF-8 locale.
  escaped <- unlist(lapply(
    list(catalog$packages, catalog$datasets, catalog$variables),
    function(df) {
      chr <- vapply(df, is.character, logical(1))
      unlist(lapply(df[chr], function(x) x[!is.na(x) & grepl("<U\\+[0-9A-Fa-f]{4}", x)]))
    }
  ))
  expect_length(escaped, 0)
})

test_that("no DOI and no package name is shared by two rows", {
  doi <- catalog$packages$doi
  expect_false(any(duplicated(doi[!is.na(doi)])))
  expect_false(any(duplicated(catalog$packages$pkg_name)))
})

test_that("published packages carry a Zenodo DOI and the others do not", {
  p <- catalog$packages
  expect_true(all(grepl("^10\\.5281/zenodo\\.", p$doi[p$published])))
  expect_true(all(is.na(p$doi[!p$published]) |
                    !grepl("^10\\.5281/zenodo\\.", p$doi[!p$published])))
})

test_that("detail rows belong to a package in the catalog", {
  known <- catalog$packages$pkg_name
  expect_true(all(catalog$datasets$pkg_name %in% known))
  expect_true(all(catalog$variables$pkg_name %in% known))
})

test_that("versions carry no leading v", {
  v <- catalog$packages$version
  expect_false(any(grepl("^[vV]", v[!is.na(v)])))
})
