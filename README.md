# shorten_paths.sh - File and Folder Name Cleanup Script

## Overview

`shorten_paths.sh` is a Bash script designed to clean up file and folder names in a specified directory to ensure compatibility with platforms like SharePoint. It addresses common issues such as illegal characters, long paths or names, multiple spaces, space-underscore-space sequences, trailing numeric suffixes, and system files. The script processes files and directories recursively, logs all actions, and supports a dry-run mode for testing.

Generated with Grok 3, tested on 300GB+ of real data.

### Key Features
- **Removes Illegal Characters**: Replaces characters like `~`, `#`, `%`, `&`, `*`, `{`, `}`, `:`, `\`, `<`, `>`, `?`, `/`, `+`, `|`, `,`, leading/trailing periods, and leading dashes with underscores (`_`).
- **Cleans Multiple Spaces**: Reduces multiple consecutive spaces to a single space (e.g., `TEST  123` → `TEST 123`).
- **Cleans Space-Underscore-Space**: Replaces ` _ ` with a single underscore (e.g., `TEST _ 123` → `TEST_123`).
- **Removes Trailing Numeric Suffixes**: Strips trailing `_N` or `_N_M` suffixes (e.g., `Foto_1_1.jpg` → `Foto.jpg`).
- **Deletes System Files**: Removes `Thumbs.db`, `.DS_Store`, and shadow files (`~$*`).
- **Handles Long Paths and Names**: Logs and optionally truncates names or paths exceeding specified length limits.
- **Dry-Run Mode**: Simulates changes without modifying files or folders.
- **Multi-Pass Processing**: Ensures parent directories are renamed first to avoid path issues.
- **Detailed Logging**: Outputs a detailed log (`long_paths_report.txt`) with reasons for each action.

## Requirements
- **Operating System**: Linux, macOS, or any Unix-like system with Bash.
- **Dependencies**: Standard Unix utilities (`find`, `sed`, `realpath`, `basename`, `mv`, `rm`).
- **Permissions**: Read/write access to the target directory for renaming/deleting files.

## Installation
1. Save the script as `shorten_paths.sh`.
2. Make it executable:
   ```bash
   chmod +x shorten_paths.sh
   ```

## Usage
Run the script from the command line, specifying the directory to process. Use the `--dry-run` flag to simulate changes without applying them.

### Syntax
```bash
./shorten_paths.sh [--dry-run] <source_directory>
```

- `<source_directory>`: The path to the directory to scan (must exist).
- `--dry-run` (optional): Preview changes without modifying files or folders.

### Examples
- **Full Run** (applies changes):
  ```bash
  ./shorten_paths.sh /Volumes/Migrazione/LAVORI
  ```
- **Dry Run** (simulates changes):
  ```bash
  ./shorten_paths.sh --dry-run /Volumes/Migrazione/LAVORI
  ```

## Configuration
The script includes configurable parameters at the top of the file:

- `MAX_PATH_LENGTH=260`: Maximum allowed path length (characters).
- `MAX_NAME_LENGTH=128`: Maximum allowed file/folder name length (characters).
- `TRUNCATE_TO=50`: Target length for truncated names (excluding extension).
- `OUTPUT_LOG="long_paths_report.txt"`: Log file for detailed output.
- `ILLEGAL_CHARS='[~"#%&*{}:\\<>?/+|,]+|\.\.+|^[.]|^[-]'`: Regex for illegal characters, including leading periods and dashes.

Modify these values to suit your needs.

## Functionality Details
The script processes files and directories recursively, performing the following actions:

1. **System File Deletion**:
   - Deletes `Thumbs.db`, `.DS_Store`, and shadow files (`~$*`) to ensure compatibility with SharePoint.
   - Logged with reasons like "Thumbs.db File," ".DS_Store File," or "Shadow File."

2. **Illegal Character Replacement**:
   - Replaces characters matching `ILLEGAL_CHARS` with underscores (`_`).
   - Removes leading/trailing spaces, periods, or dashes.
   - Example: `PIPPO#AGG:PS.pdf` → `PIPPO_AGG_PS.pdf`.

3. **Multiple Spaces Cleanup**:
   - Reduces multiple consecutive spaces to a single space.
   - Example: `TEST  123.pdf` → `TEST 123.pdf` (then `TEST_123.pdf` after space replacement).

4. **Space-Underscore-Space Cleanup**:
   - Replaces ` _ ` with a single underscore.
   - Example: `TEST _ 123.pdf` → `TEST_123.pdf`.

5. **Trailing Numeric Suffix Cleanup**:
   - Removes trailing `_N` or `_N_M` suffixes.
   - Example: `Foto_1_1.jpg` → `Foto.jpg`.

6. **Long Path/Name Handling**:
   - Logs paths exceeding `MAX_PATH_LENGTH` or names exceeding `MAX_NAME_LENGTH`.
   - Truncates names to `TRUNCATE_TO` characters if needed, ensuring unique names.
   - Example: A 150-character name may be truncated to `first_50_chars.pdf`.

7. **Multi-Pass Processing**:
   - Processes deepest paths first (using `find ... | sort -r`).
   - Runs multiple passes to handle parent directory renames until no changes are needed.

8. **Dry-Run Mode**:
   - Simulates all actions and logs them without modifying the filesystem.
   - Runs only one pass to avoid redundant simulation.

9. **Logging**:
   - Outputs to `long_paths_report.txt` and the console.
   - Includes:
     - Full path and reason for each action (e.g., "Illegal Characters," "Multiple Spaces," "Long Path or Name").
     - Path and name lengths for long paths/names.
     - Skipped files (already compliant).
     - Summary of processed items and changes per pass.

## Example Log Output
```text
Scanning directory: /Volumes/Migrazione/LAVORI
Logging paths exceeding 260 characters, names exceeding 128 characters, containing illegal characters, space-underscore-space, multiple spaces, shadow files (~$), .DS_Store, or Thumbs.db to long_paths_report.txt
Starting pass 1
Item: /Volumes/Migrazione/LAVORI/TEST/07 DATI/XYZ/14:02:24 AGG/PIPPO  AGG  PS.pdf
Reason: Multiple Spaces
Renamed 'PIPPO  AGG  PS.pdf' to 'PIPPO_AGG_PS.pdf' (Reason: Multiple Spaces)
------------------------
Item: /Volumes/Migrazione/LAVORI/TEST/07 DATI/XYZ/14:02:24 AGG/-  SCHEDA IMPR.xlsx
Reason: Illegal Characters
Renamed '-  SCHEDA IMPR.xlsx' to 'SCHEDA_IMPR.xlsx' (Reason: Illegal Characters)
------------------------
Item: /Volumes/Migrazione/LAVORI/TEST/07 DATI/XYZ/14:02:24 AGG/.DS_Store
Reason: .DS_Store File
Deleted .DS_Store File '.DS_Store'
------------------------
Item: /Volumes/Migrazione/LAVORI/very/long/path/to/2018_05_28_Agg_antincendio_rischio_medio_PATTI_COS.pdf
Path Length: 286
Name Length: 54
Reason: Long Path or Name
No rename needed for '2018_05_28_Agg_antincendio_rischio_medio_PATTI_COS.pdf' (name already valid)
------------------------
Pass 1 complete. Processed 4 items, made 3 changes
Starting pass 2
Item: /Volumes/Migrazione/TEST/07 DATI/X Y  Z/
Reason: Multiple Spaces
Renamed 'X Y  Z' to 'XYZ' (Reason: Multiple Spaces)
------------------------
Pass 2 complete. Processed 1 items, made 1 changes
Starting pass 3
Skipping '/Volumes/Migrazione/LAVORI/very/long/path/to/2018_05_28_Agg_antincendio_rischio_medio_PATTI_COS.pdf' (already compliant)
------------------------
Pass 3 complete. Processed 1 items, made 0 changes
Total processed: 6 items, Total changes: 4
```

## Notes
- **Backup**: Always back up your files before running the script without `--dry-run`, as renames and deletions are permanent.
- **Long Paths**: Files with paths exceeding `MAX_PATH_LENGTH` are logged but not renamed if their names are valid. To resolve long paths, shorten parent folder names or move files to a shorter directory structure. Contact the script maintainer to enable forced truncation for long paths.
- **SharePoint Compatibility**: The script ensures files are free of illegal characters, system files, and problematic patterns, making them suitable for SharePoint uploads.
- **Customization**:
  - Adjust `MAX_PATH_LENGTH`, `MAX_NAME_LENGTH`, or `TRUNCATE_TO` for specific requirements.
  - Modify `ILLEGAL_CHARS` to include additional restricted characters.
  - Add more system files to `is_special_file` (e.g., `desktop.ini`) if needed.
- **Safety**:
  - Uses `mv -n` to prevent overwriting existing files.
  - Uses `rm -f` for safe deletion of system files.
  - Validates path lengths and skips invalid or missing paths.
- **Performance**: Processes all cleanups (multiple spaces, ` _ `, `_N` suffixes, illegal characters) in a single pass per file, minimizing overhead. Multi-pass ensures parent directories are handled correctly.

## Troubleshooting
- **Error: `basename: illegal option --`**:
  - This should no longer occur with the updated script, which uses `basename --` to handle files starting with `-`.
  - If you encounter it, ensure you’re using the latest version.
- **Unexpected Renames** (e.g., `renamed_file`)**:
  - Occurs if a name becomes empty after cleaning. The script assigns `renamed_file` as a fallback. Verify `ILLEGAL_CHARS` and cleaning rules.
- **Long Paths Persist**:
  - If paths exceed `MAX_PATH_LENGTH`, consider shortening parent folder names or enabling forced truncation.
- **Missing Files**:
  - If files are skipped (logged as "path no longer exists"), they may have been renamed or deleted in a previous pass. Check the log for details.

For further assistance, share the `long_paths_report.txt` output with the script maintainer.

## Limitations
- Does not automatically shorten long paths unless the file/folder name itself is too long. Manual intervention may be needed for deeply nested structures.
- Dry-run mode runs only one pass to avoid redundant simulation, so some parent directory issues may not be fully previewed.
- Assumes Unix-like environment; not tested on Windows without Bash (e.g., WSL).

## License
This script is provided as-is, free to use and modify. No warranty is implied. Always test with `--dry-run` and back up your data before running.
