test_that("Imports stay base R plus tibble and utils", {
  imports <- utils::packageDescription("owdata")[["Imports"]]
  imports <- trimws(sub("\\s*\\(.*\\)$", "", strsplit(imports, ",")[[1]]))
  expect_setequal(imports, c("tibble", "utils"))
})

test_that("the package is licensed CC BY 4.0", {
  expect_identical(utils::packageDescription("owdata")[["License"]], "CC BY 4.0")
})
