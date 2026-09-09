#' Search the openwashdata catalog
#'
#' Runs a case-insensitive regular expression over package, dataset and
#' variable metadata, so `owd_search("groundwater")` answers "which
#' package has data about groundwater". The search runs against a
#' prebuilt flat index, so it is a single vectorized match regardless of
#' catalog size.
#'
#' @param query A single regular expression (case-insensitive). Plain
#'   words work as-is.
#' @param fields Character vector of fields to search. Any of "title",
#'   "description", "variable_name", "dataset_name", "pkg_name". The
#'   default covers titles, descriptions, variable names and dataset
#'   names.
#' @return A tibble of hits with columns pkg_name, match_type ("package",
#'   "dataset" or "variable"), dataset_name, field and text (the matched
#'   text). Zero rows when nothing matches.
#' @export
#' @examples
#' owd_search("sanitation")
#' owd_search("water", fields = "variable_name")
owd_search <- function(query,
                       fields = c("title", "description", "variable_name", "dataset_name")) {
  if (!is.character(query) || length(query) != 1 || is.na(query) || !nzchar(query)) {
    stop("`query` must be a single non-empty string.", call. = FALSE)
  }
  fields <- match.arg(
    fields,
    c("title", "description", "variable_name", "dataset_name", "pkg_name"),
    several.ok = TRUE
  )
  index <- owd_active_catalog()$index
  index <- index[index$field %in% fields, , drop = FALSE]
  bad_regex <- function(c) stop("Invalid regular expression: ", query, call. = FALSE)
  hit <- tryCatch(
    grepl(query, index$text, ignore.case = TRUE, perl = TRUE),
    error = bad_regex,
    warning = bad_regex
  )
  index[hit, , drop = FALSE]
}
