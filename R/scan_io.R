#' Scan Scripts for Data Input and Output Lineage
#'
#' @description
#' Parses an R, Python, or Stata script to trace data import and export
#' flows, capturing clean filenames, absolute data paths, and file extensions.
#'
#' @param file_path Character. Path to the script file to be scanned.
#' @return A tibble containing script metadata, data operations, and lineage details.
#' @export
scan_io <- function(file_path) {

  if (!file.exists(file_path)) {
    stop("The specified script file does not exist.")
  }

  ext <- tolower(tools::file_ext(file_path))

  # extensions for language/tool
  r_family  <- c("r", "rmd", "qmd")
  py_family <- c("py", "ipynb")
  stata_family <- c("do")

  if (!(ext %in% c(r_family, py_family, stata_family))) return(NULL)

  if (ext == "ipynb") {
    # get source code from .ipynb (JSON)
    nb_data <- tryCatch({
      jsonlite::fromJSON(file_path, simplifyVector = FALSE)
    }, error = function(e) {
      warning(paste("Failed to parse JSON for notebook:", file_path))
      return(NULL)
    })

    if (is.null(nb_data)) return(NULL)

    lines <- purrr::map(nb_data$cells, function(cell) {
      if (cell$cell_type == "code") as.character(cell$source) else NULL
    }) |> purrr::flatten_chr()

  } else {
    # every lines of script files except .ipynb reads here
    lines <- readLines(file_path, warn = FALSE)
  }

  patterns <- list(
    r = list(
      import = "read_parquet|read\\.csv|read_csv|read_excel|readRDS|fread|load\\(",
      export = "write_parquet|write\\.csv|write_csv|write_xlsx|saveRDS|save\\(|ggsave|topptx|graph2ppt|target\\s*=|render\\(|\\.html|\\.pdf|\\.docx|\\.qmd|\\.[Rr]md",
      comment = "^#"
    ),
    py = list(
      import = "pd\\.read_|open\\(|with\\s+open|\\.load\\(|np\\.load",
      export = "to_csv|to_parquet|to_excel|to_pickle|\\.write\\(|plt\\.savefig",
      comment = "^#"
    ),
    stata = list(
      import = "\\buse\\b|\\bu\\s+|\\bimport\\s+(delimited|excel|sas|spss)\\b",
      export = "\\bsave\\b|\\bsa\\s+|\\bexport\\s+(delimited|excel)\\b",
      comment = "^\\*|^//"
    )
  )

  lang <- dplyr::case_when(
    ext %in% r_family ~ "r",
    ext %in% py_family ~ "py",
    ext %in% stata_family ~ "stata"
  )

  # lang <- if (ext %in% r_family) "r" else "py"
  curr_p <- patterns[[lang]]

  clean_lines <- lines[!stringr::str_detect(stringr::str_trim(lines), curr_p$comment)]
  imports     <- clean_lines[stringr::str_detect(clean_lines, curr_p$import)]
  exports     <- clean_lines[stringr::str_detect(clean_lines, curr_p$export)]

  if (length(imports) == 0 && length(exports) == 0) {
    return(dplyr::tibble(
      script_name = character(), script_path = character(), type = character(),
      data_file = character(), data_path = character(), data_ext = character(),
      original_code = character()
    ))
  }

  extract_file_path <- function(code_lines) {
    raw_strings <- stringr::str_extract(code_lines, "target\\s*=\\s*\"[^\"]+\"|target\\s*=\\s*'[^']+'|\"[^\"]+\"|'[^']+'")
    stringr::str_remove_all(raw_strings, "target\\s*=\\s*|\"|'")
  }

  dplyr::tibble(
    script_name   = basename(file_path),
    script_path   = as.character(fs::path_abs(file_path)),
    script_ext    = ext,
    type          = c(rep("Import", length(imports)), rep("Export", length(exports))),
    raw_file_path = extract_file_path(c(imports, exports)),
    original_code = stringr::str_trim(c(imports, exports))
  ) |>
    dplyr::mutate(
      is_dynamic = is.na(raw_file_path) | raw_file_path == "" | stringr::str_detect(raw_file_path, "Variable|Dynamic"),

      data_file = dplyr::if_else(is_dynamic, "[Variable/Dynamic Path]", as.character(fs::path_file(raw_file_path))),

      base_ext = dplyr::if_else(is_dynamic, NA_character_, tolower(tools::file_ext(data_file))),
      data_ext = dplyr::case_when(
        is_dynamic ~ NA_character_,
        stringr::str_detect(original_code, "readRDS|saveRDS") ~ "rds",
        stringr::str_detect(original_code, "read_parquet|write_parquet") ~ "parquet",
        stringr::str_detect(original_code, "read_excel|write_xlsx") & !(base_ext %in% c("xlsx", "xls")) ~ "xlsx",
        TRUE ~ base_ext
      ),

      data_path = dplyr::case_when(
        is_dynamic ~ NA_character_,
        fs::is_absolute_path(raw_file_path) ~ as.character(raw_file_path),
        TRUE ~ {
          combined_path <- file.path(dirname(script_path), raw_file_path)
          normalizePath(combined_path, winslash = "/", mustWork = FALSE)
        }
      ),

      data_path = dplyr::if_else(is_dynamic | stringr::str_detect(data_path, "/NA$|\\\\NA$"), NA_character_, data_path)
    ) |>
    dplyr::select(script_name, script_path, type, data_file, data_path, data_ext, original_code)
}
