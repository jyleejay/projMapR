#' Compare Two Files for Content Identity
#'
#' This function checks if two files are identical using either a fast MD5 hash
#' or a robust text-based comparison that ignores whitespace and line endings.
#'
#' @param path1 Character. Path to the first file.
#' @param path2 Character. Path to the second file.
#' @param method Character. "hash" (default) for exact byte-level matching,
#'   or "text" for ignoring line-ending/whitespace differences.
#'
#' @return A list of class `projmap_compare` containing:
#'   \item{identical}{Logical. TRUE if files match, FALSE otherwise.}
#'   \item{method}{Character. The method used for comparison.}
#'   \item{status}{Character. A human-readable explanation of the result.}
#'
#' @examples
#' \dontrun{
#' compare_files("data_v1.csv", "data_v1_backup.csv")
#' compare_files("script.R", "nas/script.R", method = "text")
#' }
#' @export
compare_files <- function(path1, path2, method = c("hash", "text")) {
  method <- match.arg(method)

  if (!all(file.exists(path1, path2))) {
    stop("One or both file paths do not exist.")
  }

  if (method == "hash") {
    h1 <- unname(tools::md5sum(path1))
    h2 <- unname(tools::md5sum(path2))

    is_same <- length(setdiff(h1, h2)) == 0
    reason <- if(is_same) "Exact byte-for-byte match" else "Content differs at byte level"

  } else {
    lines1 <- trimws(readLines(path1, warn = FALSE))
    lines2 <- trimws(readLines(path2, warn = FALSE))

    lines1 <- lines1[lines1 != ""]
    lines2 <- lines2[lines2 != ""]

    is_same <- identical(lines1, lines2)
    reason <- if(is_same) "Text content is identical (ignoring whitespace/newlines)" else "Text lines differ"
  }

  res <- list(identical = is_same, method = method, status = reason)

  class(res) <- c("projmap_compare", "list")

  return(res)
}

#' Custom Print Method for compare_files
#' @param x An object of class projmap_compare
#' @param ... Further arguments passed to or from other methods.
#' @export
print.projmap_compare <- function(x, ...) {
  # Print the main result with clear visual indicators
  if (x$identical) {
    cat("\n✅ [MATCH] The files are identical.\n")
  } else {
    cat("\n❌ [MISMATCH] The files differ.\n")
  }

  # Print the detailed metadata
  cat(sprintf("   ▪ Method : %s\n", x$method))
  cat(sprintf("   ▪ Details : %s\n\n", x$status))

  # Return the object invisibly so it can still be assigned to a variable
  invisible(x)
}
