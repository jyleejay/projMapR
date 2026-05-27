# projMapR <img src="man/figures/logo_final.png" align="right" height="139" alt="projMapR logo" />
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)

**`projMapR`** is an R package designed to help data scientists organize, audit, and document their project directories. It automates the tedious task of listing files, identifying duplicates, and mapping the flow of data through R scripts and Python scripts.

## Why use `projMapR`?

When projects grow, file structures often become messy. You end up with multiple versions of the same dataset and lose track of which script generates which file. `projMapR` solves this by:

-   **Building a Clean Inventory:** Recursively scan folders to extract file metadata.
-   **True Duplicate Detection:** Use MD5 hashing to find files that are identical in content, even if their names are different.
-   **Data Lineage Mapping:** Automatically scan your R (.R) and Python (.py) scripts to find which files are being **imported** and **exported**.
-   **Collaboration Ready:** Export everything into a professional, multi-sheet Excel report for your team.

------------------------------------------------------------------------

## Installation

You can install the development version of `projMapR` from [GitHub](https://github.com/) with:

``` r
# install.packages("pak")
pak::pak("jyleejay/projMapR")

# install.packages("remotes")ca
remotes::install_git("https://github.com/jyleejay/projMapR.git")
```

------------------------------------------------------------------------

## Quick Start

One command to map your entire project:

``` r
library(projMapR)

# Analyze the current project and export an Excel report
export_project_map(target_dir = ".", output_excel = "Project_Audit_Report.xlsx")
```

### Advanced Usage

**1. Build a Detailed File Inventory**

``` r
# Filter by extension and get metadata
inventory <- build_inventory("data/raw_data", include_ext = c("csv", "rds"))

# Detect true duplicates regardless of file name
duplicates <- inventory[inventory$is_duplicate == TRUE, ]
```

**2. Trace Data I/O Flows**

``` r
# See which files your scripts are reading and write operations
flow_map <- scan_io("scripts/analysis_v1.R")
```

------------------------------------------------------------------------

## Key Functions

| Function               | Description                                                         |
|:-----------------------------------|:-----------------------------------|
| `build_inventory()`    | Scans a directory for metadata and calculates MD5 hashes.           |
| `scan_io()`            | Parses an R or Python script to find `read` and `write` operations. |
| `export_project_map()` | The master wrapper to generate a full Excel report.                 |

------------------------------------------------------------------------

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue or submit a pull request.

## License

This project is licensed under the **MIT License**.
