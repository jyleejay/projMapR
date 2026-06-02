# projMapR <img src="man/figures/logo_final.png" align="right" height="139" alt="projMapR logo" />
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

**`projMapR`** is an R package designed to help data scientists organize, audit, and document their project directories. It automates the tedious task of listing files, identifying duplicates, and mapping the flow of data through R scripts and Python scripts.

## Why use `projMapR`?

When projects grow, file structures often degrade into messy data silos. You can easily end up with multiple versions of the same dataset and lose track of which script generates which file. `projMapR` solves this by:

-   **Building a Clean Inventory:** Recursively scan folders to extract file metadata.
-   **True Duplicate Detection:** Use MD5 hashing to find files that are identical in content, even if their names are different.
-   **Data Lineage Mapping:** Automatically scan your R (.R) and Python (.py, .ipynb) scripts to trace exact **import** and **export** operations.
-   **Collaboration Ready:** Export everything into a professional, multi-sheet Excel report for seamless team audits.

------------------------------------------------------------------------

## Installation

You can install the development version of `projMapR` from [GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("jyleejay/projMapR")

# install.packages("remotes")
remotes::install_git("https://github.com/jyleejay/projMapR.git")
```

------------------------------------------------------------------------

## Quick Start

Map your entire project with a single command:

``` r
library(projMapR)

# Analyze the current project and export an audit-ready Excel report
export_project_map(target_dir = ".", output_excel = "Project_Audit_Report.xlsx")
```

### Advanced Usage

**1. Build a Detailed File Inventory**

``` r
# Filter by extension and get metadata
inventory <- build_inventory("data/raw_data", include_ext = c("xlsx", "r"))

# Detect true duplicates to clean up storage
duplicates <- inventory[inventory$is_duplicate == TRUE, ]
```

**2. Trace Data I/O Flows**

``` r
# Audit a script to see exactly which files it reads and writes
flow_map <- scan_io("scripts/analysis_v1.R")
```

**3. Verify File Integrity**

``` r
# Compare local scripts against NAS backups, ignoring OS-specific line endings (CRLF vs LF)
compare_files("scripts/analysis_v1.R", "Z:/NAS_backup/scripts/analysis_v1.R", method = "text")

# Ensure two binary data files are identical byte-for-byte
compare_files("data/raw_data.rds", "data/backup_data.rds", method = "hash")
```

------------------------------------------------------------------------

## Key Functions

| Function               | Description                                                         |
|:-----------------------------------|:-----------------------------------|
| `build_inventory()`    | Scans a directory for metadata and calculates MD5 hashes.           |
| `scan_io()`            | Parses an R or Python script to find `read` and `write` operations. |
| `export_project_map()` | The master wrapper to generate a full Excel report.                 |
| `compare_files()`      | Validates if two files are identical using byte-level hashing or text comparison.|

------------------------------------------------------------------------

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue or submit a pull request.

## License

This project is licensed under the **MIT License**.
