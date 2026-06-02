#' Build Project File Inventory with Custom Filters
#'
#' @param target_dir Character. Path to the project directory.
#' @param include_ext Character vector. Specific extensions to include (e.g., c("R", "csv")). Default is NULL (all extensions).
#' @param min_size Numeric/Character. Minimum file size to include (e.g., 1024 or "100KB"). Default is NULL.
#' @export
build_inventory <- function(target_dir = ".", include_ext = NULL, min_size = NULL) {

  # 1. Extract raw file information using fs package
  info <- fs::dir_info(target_dir, all = TRUE, recurse = TRUE) |>
    dplyr::filter(type == "file")    # Exclude directories

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

  if (nrow(info) == 0) {
    return(dplyr::tibble(
      path = character(), file_name = character(), type = character(),
      size = fs::as_fs_bytes(numeric()), extension = character(),
      modification_time = POSIXct(), md5_hash = character(),
      is_duplicate = logical(), duplicate_group = integer()
    ))
  }


  # 2. Calculate MD5 hash to detect true duplicates based on file content
  inventory <- info |>
    dplyr::mutate(
      path = fs::path_abs(path, start = target_dir),
      file_name = fs::path_file(path),
      extension = tolower(fs::path_ext(path)),
      size = fs::as_fs_bytes(size),
      modification_time = modification_time,
      md5_hash = tools::md5sum(path) |> unname()
    ) |>
    # 3. Group by hash to flag duplicates and assign group IDs
    dplyr::group_by(md5_hash) |>
    dplyr::mutate(
      is_duplicate = dplyr::n() > 1,
      duplicate_group = dplyr::if_else(is_duplicate, dplyr::cur_group_id(), NA_integer_)
    ) |>
    dplyr::ungroup() |>
    dplyr::select(
      path, file_name, type, size, extension,
      modification_time, md5_hash, is_duplicate, duplicate_group
    )

  return(inventory)
}
