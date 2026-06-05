#' Scan Scripts for Data Input and Output Lineage
#'
#' @description
#' Parses an R, Python, or R Markdown script to trace data import and export
#' flows, capturing clean filenames, absolute data paths, and file extensions.
#'
#' @param file_path Character. Path to the script file to be scanned.
#' @return A tibble containing script metadata, data operations, and lineage details.
#' @export
scan_io <- function(file_path) {

  if (!file.exists(file_path)) stop("File not found.")

  ext <- tolower(fs::path_ext(file_path))

  # 1. Define Language-Specific Patterns
  # Add more languages here in the future!
  patterns <- list(
    r = list(
      import = "read_parquet|read\\.csv|read_csv|read_excel|readRDS|fread|load\\(",
      export = "write_parquet|write\\.csv|write_csv|write_xlsx|saveRDS|save\\(|ggsave|topptx|graph2ppt|target\\s*=|render\\(|\\.html|\\.pdf|\\.docx|\\.qmd|\\.[Rr]md",
      comment = "^#"
    ),
    py = list(
      import = "pd\\.read_|open\\(|\\.load\\(|np\\.load",
      export = "\\.to_csv|\\.to_excel|\\.to_pickle|\\.to_parquet|plt\\.savefig|quarto\\s+render|\\.html|\\.pdf",
      comment = "^#"
    ),
    ipynb = list(
      import = "pd\\.read_|open\\(|\\.load\\(|np\\.load",
      export = "\\.to_csv|\\.to_excel|\\.to_pickle|\\.to_parquet|plt\\.savefig|\\.html|\\.pdf",
      comment = "^#"
    )
  )

  # 2. Select the appropriate pattern
  target_pattern <- patterns[[ext]]
  if (is.null(target_pattern)) return(NULL) # Skip unsupported extensions

  # 3. Read and filter code
  code_lines <- readLines(file_path, warn = FALSE)

  if (ext == "ipynb") {
    nb_data <- jsonlite::fromJSON(file_path)
    code_cells <- nb_data$cells[nb_data$cells$cell_type == "code", ]
    code_lines <- unlist(code_cells$source)
  } else {
    code_lines <- readLines(file_path, warn = FALSE)
  }

  # Remove commented lines and empty lines
  active_lines <- code_lines[
    !stringr::str_detect(stringr::str_trim(code_lines), target_pattern$comment) &
      stringr::str_trim(code_lines) != ""
  ]

  # 4. Detect Import and Export lines
  imports <- stringr::str_subset(active_lines, target_pattern$import)
  exports <- stringr::str_subset(active_lines, target_pattern$export)

  if (length(imports) == 0 && length(exports) == 0) return(NULL)

  # 5. Helper function: Extract strings inside quotes
  extract_file_path <- function(lines) {
    raw_strings <- stringr::str_extract(lines, "target\\s*=\\s*\"[^\"]+\"|target\\s*=\\s*'[^']+'|\"[^\"]+\"|'[^']+'")
    clean_strings <- stringr::str_remove_all(raw_strings, "target\\s*=\\s*|\"|'")
    return(clean_strings)
  }

  # 6. Assemble the result
  dplyr::tibble(
    script_name = basename(file_path),
    script_path = as.character(fs::path_abs(file_path)),
    script_ext = ext,
    type = c(rep("Import", length(imports)), rep("Export", length(exports))),
    data_file = extract_file_path(c(imports, exports)),
    data_ext = tolower(tools::file_ext(data_file)),
    original_code = stringr::str_trim(c(imports, exports))
  ) |>
    dplyr::mutate(

      data_path = dplyr::case_when(
        data_file == "[Variable/Dynamic Path]" ~ NA_character_,
        fs::is_absolute_path(data_file) ~ as.character(data_file),
        TRUE ~ {
          combined_path <- file.path(dirname(script_path), data_file)
          normalizePath(combined_path, winslash = "/", mustWork = FALSE)
        }
      ),

      is_dynamic = data_file == "[Variable/Dynamic Path]" |
        stringr::str_detect(data_file, "Variable|Dynamic"),

      data_file = dplyr::case_when(
        is_dynamic ~ "[Variable/Dynamic Path]",
        TRUE ~ as.character(fs::path_file(data_file))
      ),

      base_ext = tolower(tools::file_ext(data_file)),

      data_ext = dplyr::case_when(
        data_file == "[Variable/Dynamic Path]" ~ NA_character_,
        stringr::str_detect(original_code, "readRDS|saveRDS") ~ "rds",
        stringr::str_detect(original_code, "read_parquet|write_parquet") ~ "parquet",
        stringr::str_detect(original_code, "read_excel|write_xlsx") & !(base_ext %in% c("xlsx", "xls")) ~ "xlsx",
        TRUE ~ base_ext),

      data_file = dplyr::if_else(is.na(data_file), "[Variable/Dynamic Path]", data_file),
      data_path = dplyr::if_else(data_file == "[Variable/Dynamic Path]", NA_character_, data_path),
      data_ext = dplyr::if_else(data_file == "[Variable/Dynamic Path]", NA_character_, data_ext)
    ) |>
    dplyr::select(script_name, script_path, type, data_file, data_path, data_ext, original_code)
}
