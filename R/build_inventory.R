#' Build Project File Inventory with Custom Filters
#'
#' @param target_dir Character. Path to the project directory.
#' @param include_ext Character vector. Specific extensions to include (e.g., c("R", "py")). Default is NULL (all extensions).
#' @param min_size Numeric/Character. Minimum file size to include (as numeric, e.g., 1024 or 532). Default is NULL.
#' @param ignore_dirs Character vector. Directories to exclude from the scan (e.g., .git, renv).
#' @param ignore_files Character vector. Files to exclude from the scan (e.g., .git, renv).
#' @return A structured tibble containing comprehensive file metadata.
#' @export
build_inventory <- function(target_dir = ".", include_ext = NULL, min_size = NULL,
                            ignore_dirs = c(".git", "renv", ".Rproj.user", ".venv", "__pycache__", ".ipynb_checkpoints",
                                            "$RECYCLE.BIN", "Recovery", "System Volume Information"),
                            ignore_files = c("renv.lock", "Thumbs.db", ".DS_Store", ".gitignore", ".Rhistory"),
                            ignore_ext = c("css", "bib")) {

  # Use purrr::map_dfr to iterate safely over multiple directories and row-bind the results automatically
  inventory_list <- purrr::map_dfr(target_dir, function(single_dir) {

    # 1. Resolve base target directory to absolute path safely
    abs_target <- fs::path_abs(single_dir)

    # Check if directory exists before scanning
    if (!fs::dir_exists(abs_target)) {
      warning(paste("Directory does not exist and will be skipped:", single_dir))
      return(NULL)
    }

    info <- fs::dir_info(abs_target, recurse = TRUE, all = TRUE, fail = FALSE)

    # pre-filtering condition: ignore_dirs
    if (!is.null(ignore_dirs) && length(ignore_dirs) > 0) {

      safe_dirs <- gsub("([.$])", "\\\\\\1", ignore_dirs)
      ignore_pattern <- paste0("/(", paste(safe_dirs, collapse = "|"), ")(/|$)")
      info <- info |>
        dplyr::filter(!stringr::str_detect(path, stringr::regex(ignore_pattern, ignore_case = TRUE)))
    }

    info <- info |>
      dplyr::filter(!stringr::str_detect(path, "/[^/]+_(files|cache)(/|$)"))

    # pre-filtering condition: ignore_files, ignore_ext
    if (!is.null(ignore_files)) {
      info <- info |> dplyr::filter(!as.character(fs::path_file(path)) %in% ignore_files)
    }
    if (!is.null(ignore_ext)) {
      info <- info |> dplyr::filter(!tolower(fs::path_ext(path)) %in% tolower(ignore_ext))
    }

    # 1-1. Extension filtering
    if (!is.null(include_ext)) {
      target_exts <- tolower(include_ext)
      info <- info |>
        dplyr::filter(tolower(fs::path_ext(path)) %in% target_exts)
    }

    # 1-2. Size filtering
    if (!is.null(min_size)) {
      limit_bytes <- fs::as_fs_bytes(min_size)
      info <- info |>
        dplyr::filter(size >= limit_bytes)
    }

    if (nrow(info) == 0) return(NULL)

    # 2. Process paths to absolute strings safely per-directory
    info |>
      dplyr::mutate(
        path = as.character(fs::path_abs(path)),
        file_name = as.character(fs::path_file(path)),
        extension = tolower(fs::path_ext(path)),
        size = fs::as_fs_bytes(size),
        modification_time = modification_time
      )
  })

  # If no files were found across all directories, return an empty schema
  if (nrow(inventory_list) == 0) {
    return(dplyr::tibble(
      path = character(),
      file_name = character(),
      type = character(),
      size_bytes = numeric(),
      size_readable = character(),
      extension = character(),
      modification_time = Sys.time()[0],
      md5_hash = character(),
      is_duplicate = logical(),
      duplicate_group = integer()
    ))
  }

  # 3. Global Duplicate Hashing & Grouping (Runs across ALL scanned paths)
  final_inventory <- inventory_list |>
    dplyr::mutate(
      md5_hash = unname(tools::md5sum(path))
    ) |>
    dplyr::group_by(md5_hash) |>
    dplyr::mutate(
      is_duplicate = dplyr::n() > 1,
      duplicate_group = dplyr::if_else(is_duplicate, dplyr::cur_group_id(), NA_integer_)
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      size_bytes = as.numeric(size),
      size_readable = as.character(size) |> stringr::str_squish()
    ) |>
    dplyr::select(
      path, file_name, type,
      size_bytes, size_readable,
      extension, modification_time, md5_hash, is_duplicate, duplicate_group
    )

  return(final_inventory)
}
