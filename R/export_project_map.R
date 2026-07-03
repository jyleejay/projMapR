#' Export Project File Inventory and I/O Map to Excel
#'
#' @description
#' A high-level wrapper function that builds the file inventory, scans all
#' R scripts for data flows, and exports the results into a multi-sheet Excel file.
#'
#' @param target_dir Directory path to analyze. Defaults to current directory (".").
#' @param include_ext Character vector. Specific extensions to include (e.g., c("R", "py")). Default is NULL (all extensions).
#' @param min_size Numeric/Character. Minimum file size to include (as numeric, e.g., 1024 or 532). Default is NULL.
#' @param ignore_dirs Character vector. Directories to exclude from the scan (e.g., .git, renv).
#' @param ignore_files Character vector. Files to exclude from the scan (e.g., .git, renv).
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
export_project_map <- function(target_dir = ".",
                               output_excel = "Project_Map.xlsx",
                               include_ext = NULL,
                               min_size = NULL,
                               ignore_dirs = c(".git", "renv", ".Rproj.user", ".venv", "__pycache__", ".ipynb_checkpoints"),
                               ignore_files = c("renv.lock", "Thumbs.db", ".DS_Store", ".gitignore", ".Rhistory"),
                               ignore_ext = c("css", "bib")) {

  # 1. Generate the overall file inventory
  message("Building file inventory... This may take a moment for large directories.")

  inventory <- build_inventory(
    target_dir = target_dir,
    include_ext = include_ext,
    min_size = min_size,
    ignore_dirs = ignore_dirs,
    ignore_files = ignore_files,
    ignore_ext = ignore_ext
  )

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
