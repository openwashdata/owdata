synthetic_packages <- function() {
  tbl <- owdata:::empty_catalog_tbl("owd_packages")
  tibble::add_row(
    tbl,
    pkg_name = c("washmalawi", "gdho", "newpkg"),
    title = c("Water Data Malawi", "Global Health Orgs", "New Package"),
    description = c(
      "Groundwater and sanitation data for Malawi.",
      "Directory of organizations.",
      "Early development data."
    ),
    version = c("1.0.0", "0.1.0", "0.0.0.9000"),
    tier = factor(
      c("catalogued", "candidate", "dev"),
      levels = levels(tbl$tier)
    ),
    legacy = c(FALSE, FALSE, FALSE)
  )
}

synthetic_datasets <- function() {
  tbl <- owdata:::empty_catalog_tbl("owd_datasets")
  tibble::add_row(
    tbl,
    pkg_name = c("washmalawi", "gdho"),
    dataset_name = c("waterpoints", "organisations"),
    title = c("Waterpoint observations", "Organisation directory"),
    description = c("Groundwater points by region.", "Health organisations.")
  )
}

synthetic_variables <- function() {
  tbl <- owdata:::empty_catalog_tbl("owd_variables")
  tibble::add_row(
    tbl,
    pkg_name = c("washmalawi", "washmalawi"),
    dataset_name = c("waterpoints", "waterpoints"),
    variable_name = c("groundwater_depth", "status"),
    variable_type = c("double", "character"),
    description = c("Depth of the groundwater table in metres.", "Functional status.")
  )
}

with_synthetic_catalog <- function(code) {
  tables <- list(
    owd_packages = synthetic_packages(),
    owd_datasets = synthetic_datasets(),
    owd_variables = synthetic_variables()
  )
  testthat::with_mocked_bindings(
    code,
    catalog_table = function(name) tables[[name]]
  )
}

test_that("owd_packages filters by tier and validates tier values", {
  with_synthetic_catalog({
    expect_equal(nrow(owd_packages()), 3)
    expect_equal(owd_packages(tier = "catalogued")$pkg_name, "washmalawi")
    expect_equal(
      sort(owd_packages(tier = c("catalogued", "candidate"))$pkg_name),
      c("gdho", "washmalawi")
    )
    expect_error(owd_packages(tier = "published"))
  })
})

test_that("owd_datasets and owd_variables filter by package and dataset", {
  with_synthetic_catalog({
    expect_equal(owd_datasets(pkg = "gdho")$dataset_name, "organisations")
    expect_equal(nrow(owd_variables(pkg = "washmalawi")), 2)
    expect_equal(
      owd_variables(dataset = "waterpoints")$variable_name,
      c("groundwater_depth", "status")
    )
    expect_equal(nrow(owd_variables(pkg = "nope")), 0)
  })
})

test_that("owd_search finds hits across tables with match types", {
  with_synthetic_catalog({
    hits <- owd_search("groundwater")
    expect_true(all(hits$pkg_name == "washmalawi"))
    expect_setequal(unique(hits$match_type), c("package", "dataset", "variable"))

    upper <- owd_search("GROUNDWATER")
    expect_equal(nrow(upper), nrow(hits))

    none <- owd_search("xyzzy-no-match")
    expect_equal(nrow(none), 0)
    expect_named(
      none,
      c("pkg_name", "match_type", "matched_field", "matched_text")
    )

    only_vars <- owd_search("groundwater", fields = "variable_name")
    expect_true(all(only_vars$match_type == "variable"))

    expect_error(owd_search("x", fields = "not_a_field"))
    expect_error(owd_search(""))
  })
})

test_that("owd_install refuses bulk install without a catalog or a terminal", {
  with_synthetic_catalog({
    skip_if(interactive())
    expect_error(owd_install(), "non-interactive")
  })
  testthat::with_mocked_bindings(
    expect_error(owd_install(), "no catalogued packages"),
    catalog_table = function(name) owdata:::empty_catalog_tbl(name)
  )
})
