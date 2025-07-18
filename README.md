# shorten_paths.sh

A Bash script to clean file and folder names for compatibility with platforms like SharePoint. It recursively processes a specified directory, removing illegal characters, multiple spaces, space-underscore-space sequences, trailing numeric suffixes, and system files (`Thumbs.db`, `.DS_Store`, `~$*`). The script supports a dry-run mode for testing and logs all actions to a detailed report.

## Features
- **Removes Illegal Characters**: Replaces characters like `~`, `#`, `%`, `&`, `*`, `{`, `}`, `:`, `\`, `<`, `>`, `?`, `/`, `+`, `|`, `,`, leading/trailing periods, and leading dashes with underscores (`_`).
- **Cleans Multiple Spaces**: Reduces multiple spaces to a single space (e.g., `TEST  123` → `TEST 123`).
- **Cleans Space-Underscore-Space**: Replaces ` _ ` with a single underscore (e.g., `TEST _ 123` → `TEST_123`).
- **Removes Trailing Numeric Suffixes**: Strips trailing `_N` or `_N_M` suffixes (e.g., `Foto_1_1.jpg` → `Foto.jpg`).
- **Deletes System Files**: Removes `Thumbs.db`, `.DS_Store`, and shadow files (`~$*`).
- **Handles Long Paths/Names**: Logs and optionally truncates names or paths exceeding specified limits.
- **Dry-Run Mode**: Simulates changes without modifying the filesystem.
- **Multi-Pass Processing**: Processes parent directories first to avoid path issues.
- **Detailed Logging**: Outputs actions to `long_paths_report.txt` with reasons and length details.

## Requirements
- **Operating System**: Linux, macOS, or any Unix-like system with Bash.
- **Dependencies**: Standard Unix utilities (`find`, `sed`, `realpath`, `basename`, `mv`, `rm`).
- **Permissions**: Read/write access to the target directory for renaming/deleting files.



