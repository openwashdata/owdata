#' Search the openwashdata catalog
#'
#' Case-insensitive regular expression search across the package,
#' dataset, and variable tables, so `owd_search("groundwater")` answers
#' the question "which package has data about groundwater".
#'
#' @param query A regular expression, matched case-insensitively.
#' @param fields Character vector of fields to search. Any of
#'   `"title"`, `"description"`, `"variable_name"`, `"dataset_name"`.
#'
#' @return A tibble of hits with columns `pkg_name`, `match_type`
#'   (package, dataset, or variable), `matched_field`, and
#'   `matched_text`.
#' @export
#'
#' @examples
#' owd_search("groundwater")
#' owd_search("sanitation", fields = c("title", "description"))
owd_search <- function(query,
                       fields = c("title", "description", "variable_name", "dataset_name")) {
  stopifnot(is.character(query), length(query) == 1, nzchar(query))
  fields <- match.arg(fields, several.ok = TRUE)
  search_impl(
    list(
      owd_packages = catalog_table("owd_packages"),
      owd_datasets = catalog_table("owd_datasets"),
      owd_variables = catalog_table("owd_variables")
    ),
    query = query, fields = fields
  )
}

# Field availability per table; searched only where the field exists.
search_impl <- function(tables, query, fields) {
  spec <- list(
    owd_packages = list(match_type = "package", fields = c("title", "description")),
    owd_datasets = list(
      match_type = "dataset",
      fields = c("title", "description", "dataset_name")
    ),
    owd_variables = list(
      match_type = "variable",
      fields = c("description", "variable_name", "dataset_name")
    )
  )
  hits <- list()
  for (tbl_name in names(spec)) {
    tbl <- tables[[tbl_name]]
    for (field in intersect(fields, spec[[tbl_name]]$fields)) {
      values <- tbl[[field]]
      hit <- !is.na(values) & grepl(query, values, ignore.case = TRUE)
      if (any(hit)) {
        hits[[length(hits) + 1]] <- tibble::tibble(
          pkg_name = tbl$pkg_name[hit],
          match_type = spec[[tbl_name]]$match_type,
          matched_field = field,
          matched_text = values[hit]
        )
      }
    }
  }
  if (length(hits) == 0) {
    return(tibble::tibble(
      pkg_name = character(), match_type = character(),
      matched_field = character(), matched_text = character()
    ))
  }
  do.call(rbind, hits)
}
