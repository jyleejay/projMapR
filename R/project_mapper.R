# ==============================================================================
# 1. build_inventory()
# ==============================================================================

#' Build a File Inventory and Detect Duplicates
#'
#' @description
#' Scans a specified directory recursively to extract metadata for all files.
#' It also calculates the MD5 hash for each file to identify exact duplicates,
#' ignoring directory structures and focusing solely on file content.
#'
#' @param target_dir A character string specifying the directory path to scan.
#'        Defaults to the current working directory (".").
#' @param include_ext A character vector of extensions to include (e.g., c("R", "csv")).
#' @param min_size Minimum file size to include (in bytes).
#'
#' @return A `tibble` (data frame) containing file paths, sizes, modification times,
#'         file extensions, MD5 hashes, and a duplicate group identifier.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' inventory <- build_inventory("C:/my_project/data")
#' head(inventory)
#' }
build_inventory <- function(target_dir = ".", include_ext = NULL, min_size = NULL) {

  # 1. Extract raw file information using 'fs' package
  file_info <- fs::dir_info(path = target_dir, all = TRUE, recurse = TRUE) |>
    dplyr::filter(type == "file") |> # Exclude directories
    dplyr::mutate(
      file_name = fs::path_file(path),
      extension = fs::path_ext(path)
    )

  # 1-1. Extension Filtering
  if (!is.null(include_ext)) {
    file_info <- file_info |>
      dplyr::filter(tolower(extension) %in% tolower(include_ext))
  }

  # 1-2. Size Filtering
  if (!is.null(min_size)) {
    file_info <- file_info |>
      dplyr::filter(size >= min_size)
  }

  # 2. Calculate MD5 hash to detect true duplicates based on file content
  # Note: purrr::map_chr applies the digest function to each file path
  hashed_files <- file_info |>
    dplyr::mutate(
      md5_hash = purrr::map_chr(path, ~digest::digest(., algo = "md5", file = TRUE))
    )

  # 3. Group by hash to flag duplicates and assign group IDs
  inventory_final <- hashed_files |>
    dplyr::group_by(md5_hash) |>
    dplyr::mutate(
      is_duplicate = dplyr::n() > 1,
      duplicate_group = dplyr::cur_group_id()
    ) |>
    dplyr::ungroup() |>
    dplyr::arrange(extension, file_name)

  return(inventory_final)
}


# ==============================================================================
# 2. scan_io()
# ==============================================================================

#' Scan Scripts for Data Import/Export Flows (R and Python)
#'
#' @description
#' Parses script files line-by-line and extracts data I/O operations based on
#' the file extension. Currently supports R (.R) and Python (.py).
#'
#' @param file_path Path to the script file.
#' @return A tibble with script name, I/O type, data file, and original code.
#'
#' @export
scan_io <- function(file_path) {

  if (!file.exists(file_path)) stop("File not found.")

  ext <- tolower(fs::path_ext(file_path))

  # 1. Define Language-Specific Patterns
  # Add more languages here in the future!
  patterns <- list(
    r = list(
      import = "read_parquet|read\\.csv|read_csv|read_excel|readRDS|fread|load\\(",
      export = "write_parquet|write\\.csv|write_csv|write_xlsx|saveRDS|save\\(|ggsave|topptx|graph2ppt|target\\s*=",
      comment = "^#"
    ),
    py = list(
      import = "pd\\.read_|open\\(|\\.load\\(|np\\.load",
      export = "\\.to_csv|\\.to_excel|\\.to_pickle|\\.to_parquet|plt\\.savefig",
      comment = "^#"
    ),
    ipynb = list(
      import = "pd\\.read_|open\\(|\\.load\\(|np\\.load",
      export = "\\.to_csv|\\.to_excel|\\.to_pickle|\\.to_parquet|plt\\.savefig",
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
    extension = ext,
    type = c(rep("Import", length(imports)), rep("Export", length(exports))),
    data_file = extract_file_path(c(imports, exports)),
    original_code = stringr::str_trim(c(imports, exports))
  ) |>
    dplyr::mutate(
      data_file = dplyr::if_else(is.na(data_file), "[Variable/Dynamic Path]", data_file)
    )
}


# ==============================================================================
# 3. export_project_map()
# ==============================================================================

#' Export Project File Inventory and I/O Map to Excel
#'
#' @description
#' A high-level wrapper function that builds the file inventory, scans all
#' R scripts for data flows, and exports the results into a multi-sheet Excel file.
#'
#' @param target_dir Directory path to analyze. Defaults to current directory (".").
#' @param output_excel Name of the output Excel file. Defaults to "Project_Map.xlsx".
#'
#' @return Invisible. Generates an Excel file in the working directory.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' export_project_map(target_dir = ".", output_excel = "My_Project_Report.xlsx")
#' }
export_project_map <- function(target_dir = ".", output_excel = "Project_Map.xlsx") {

  # 1. Generate the overall file inventory
  message("Building file inventory... This may take a moment for large directories.")
  inventory <- build_inventory(target_dir)

  # 2. Isolate R, py, ipynb scripts for I/O scanning
  scripts_to_scan <- inventory |>
    dplyr::filter(tolower(extension) %in% c("r", "py", "ipynb")) |>
    dplyr::pull(path)

  # 3. Scan all R scripts and combine the results
  message("Scanning R scripts for Data I/O flows...")
  if (length(scripts_to_scan) > 0) {
    io_map <- purrr::map_dfr(scripts_to_scan, scan_io)
  } else {
    io_map <- dplyr::tibble(Message = "No analysis scripts (R/py/ipynb) found.")
  }

  # 4. Export the generated tables to a multi-sheet Excel workbook
  message(sprintf("Exporting results to: %s", output_excel))
  writexl::write_xlsx(
    list(
      "File_Inventory" = inventory,
      "Data_IO_Map" = io_map
    ),
    path = output_excel
  )

  message("Export completed successfully!")
}
