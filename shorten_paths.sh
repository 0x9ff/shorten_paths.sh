#!/bin/bash

# Configuration
MAX_PATH_LENGTH=260  # Maximum path length (adjust if needed)
MAX_NAME_LENGTH=128  # Maximum file/folder name length
SOURCE_DIR="$1"      # Directory to scan (passed as argument)
OUTPUT_LOG="long_paths_report.txt"
TRUNCATE_TO=50       # Target length for shortened names (excluding extension)
DRY_RUN=0            # Default: no dry run

# Illegal characters regex for SharePoint (excluding spaces for separate handling)
ILLEGAL_CHARS='[~"#%&*{}:\\<>?/+|,]+|\.\.+|^[.]|^[-]'

# Check for dry-run flag
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=1
    SOURCE_DIR="$2"
    echo "Running in DRY-RUN mode. No changes will be made."
elif [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=1
    echo "Running in DRY-RUN mode. No changes will be made."
fi

# Function to check if a name contains illegal characters
has_illegal_chars() {
    local name="$1"
    if [[ "$name" =~ $ILLEGAL_CHARS || "$name" =~ ^[[:space:]]|[[:space:]]$ ]]; then
        return 0  # Illegal characters or leading/trailing spaces found
    else
        return 1  # No illegal characters
    fi
}

# Function to check if a name is a shadow file, .DS_Store, or Thumbs.db
is_special_file() {
    local name="$1"
    if [[ "$name" =~ ^~\$ || "$name" == ".DS_Store" || "$name" == "Thumbs.db" ]]; then
        return 0  # Shadow file, .DS_Store, or Thumbs.db
    else
        return 1  # Not a special file
    fi
}

# Function to get special file type
get_special_file_type() {
    local name="$1"
    if [[ "$name" =~ ^~\$ ]]; then
        echo "Shadow File"
    elif [[ "$name" == ".DS_Store" ]]; then
        echo ".DS_Store File"
    elif [[ "$name" == "Thumbs.db" ]]; then
        echo "Thumbs.db File"
    fi
}

# Function to clean illegal characters
clean_name() {
    local name="$1"
    # Replace illegal characters with underscore
    local cleaned_name=$(echo "$name" | sed -E "s/$ILLEGAL_CHARS/_/g")
    # Remove leading/trailing spaces, periods, or dashes
    cleaned_name=$(echo "$cleaned_name" | sed -E 's/^[.[:space:]-]+|[.[:space:]-]+$//g')
    # If name is empty after cleaning, provide a default
    if [[ -z "$cleaned_name" ]]; then
        cleaned_name="renamed_file"
    fi
    echo "$cleaned_name"
}

# Function to clean multiple spaces, space-underscore-space, and trailing numeric suffixes
clean_suffixes() {
    local name="$1"
    # Replace multiple spaces with a single space
    local cleaned_name=$(echo "$name" | sed -E 's/[[:space:]]+/ /g')
    # Replace space-underscore-space with a single underscore
    cleaned_name=$(echo "$cleaned_name" | sed -E 's/ _ /_/g')
    # Remove trailing _N or _N_M suffixes (e.g., _1, _1_1)
    cleaned_name=$(echo "$cleaned_name" | sed -E 's/(_[0-9]+)+$//g')
    # If name is empty after cleaning, provide a default
    if [[ -z "$cleaned_name" ]]; then
        cleaned_name="renamed_file"
    fi
    echo "$cleaned_name"
}

# Function to generate a unique name
generate_unique_name() {
    local original="$1"
    local dirname="$2"
    local ext="$3"
    local path_length="$4"  # Pass path length to check if truncation is needed
    
    # Clean illegal characters
    local base_name=$(basename -- "$original" "$ext")
    local cleaned_name=$(clean_name "$base_name")
    
    # Remove multiple spaces, space-underscore-space, and trailing numeric suffixes
    cleaned_name=$(clean_suffixes "$cleaned_name")
    
    # Check if cleaned name is the same as original (no changes needed)
    if [[ "$cleaned_name" == "$base_name" && -n "$path_length" && $path_length -gt $MAX_PATH_LENGTH && ${#base_name} -le $MAX_NAME_LENGTH ]]; then
        echo "$original"  # Return original name if no changes needed
        return
    fi
    
    # Truncate only if name or path exceeds limits
    local final_name="$cleaned_name"
    if [[ -n "$path_length" && ( $path_length -gt $MAX_PATH_LENGTH || ${#base_name} -gt $MAX_NAME_LENGTH ) ]]; then
        final_name="${cleaned_name:0:$TRUNCATE_TO}"
        # Ensure the name is safe (additional check for alphanumerics)
        final_name=$(echo "$final_name" | tr -dc 'a-zA-Z0-9_-')
        final_name="${final_name:0:$TRUNCATE_TO}"
        # If truncated name is empty, use a default
        if [[ -z "$final_name" ]]; then
            final_name="renamed_file"
        fi
    fi
    
    local new_name="$final_name$ext"
    local counter=1
    local unique_name="$new_name"
    
    # Check for existing files to avoid overwrites
    while [[ -e "$dirname/$unique_name" && "$dirname/$unique_name" != "$dirname/$original" ]]; do
        unique_name="${final_name}_${counter}${ext}"
        ((counter++))
    done
    
    echo "$unique_name"
}

# Function to check if a name is already compliant
is_compliant() {
    local name="$1"
    local path_length="$2"
    # Check if name has no illegal characters, no space-underscore-space, no multiple spaces, and is within length limits
    if [[ ! $(has_illegal_chars "$name"; echo $?) -eq 0 && ! "$name" =~ _[[:space:]]+_ && ! "$name" =~ [[:space:]][[:space:]]+ && ${#name} -le $MAX_NAME_LENGTH && ( -z "$path_length" || $path_length -le $MAX_PATH_LENGTH ) ]]; then
        return 0  # Compliant
    else
        return 1  # Not compliant
    fi
}

# Function to process files and folders
process_paths() {
    local dir="$1"
    local log_file="$2"
    
    local total_processed=0
    local total_changed=0
    local pass=0
    
    # Clear the log file
    > "$log_file"
    
    echo "Scanning directory: $dir" | tee -a "$log_file"
    echo "Logging paths exceeding $MAX_PATH_LENGTH characters, names exceeding $MAX_NAME_LENGTH characters, containing illegal characters, space-underscore-space, multiple spaces, shadow files (~$), .DS_Store, or Thumbs.db to $log_file" | tee -a "$log_file"
    
    # Main processing loop for deletions and renames
    while true; do
        ((pass++))
        local items_processed=0
        local items_changed=0
        echo "Starting pass $pass" | tee -a "$log_file"
        
        # Use find to locate all files and directories, sort in reverse to process deepest paths first
        while IFS= read -r -d '' item; do
            # Get the absolute path
            item_path=$(realpath "$item" 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                echo "Skipping '$item' (path no longer exists)" >> "$log_file"
                echo "Skipping '$item' (path no longer exists)"
                echo "------------------------" >> "$log_file"
                continue
            fi
            path_length=${#item_path}
            # Validate path_length is a number
            if [[ ! $path_length =~ ^[0-9]+$ ]]; then
                echo "Skipping '$item' (invalid path length)" >> "$log_file"
                echo "Skipping '$item' (invalid path length)"
                echo "------------------------" >> "$log_file"
                continue
            fi
            item_name=$(basename "$item")
            name_length=${#item_name}
            
            # Check if name is already compliant
            if is_compliant "$item_name" "$path_length"; then
                echo "Skipping '$item_path' (already compliant)" >> "$log_file"
                echo "Skipping '$item_path' (already compliant)"
                echo "------------------------" >> "$log_file"
                ((items_processed++))
                ((total_processed++))
                continue
            fi
            
            # Check for shadow files, .DS_Store, or Thumbs.db first
            if is_special_file "$item_name"; then
                echo "Item: $item_path" >> "$log_file"
                echo "Reason: $(get_special_file_type "$item_name")" >> "$log_file"
                if [[ $DRY_RUN -eq 1 ]]; then
                    echo "[DRY-RUN] Would delete $(get_special_file_type "$item_name") '$item_name'" >> "$log_file"
                    echo "[DRY-RUN] Would delete $(get_special_file_type "$item_name") '$item_name'"
                else
                    rm -f "$item"
                    if [[ $? -eq 0 ]]; then
                        echo "Deleted $(get_special_file_type "$item_name") '$item_name'" >> "$log_file"
                        echo "Deleted $(get_special_file_type "$item_name") '$item_name'"
                        ((items_changed++))
                        ((total_changed++))
                    else
                        echo "Failed to delete $(get_special_file_type "$item_name") '$item_name'" >> "$log_file"
                        echo "Failed to delete $(get_special_file_type "$item_name") '$item_name'"
                    fi
                fi
                echo "------------------------" >> "$log_file"
                ((items_processed++))
                ((total_processed++))
                continue
            fi
            
            # Check for long paths, long names, illegal characters, space-underscore-space, or multiple spaces
            if [[ $path_length -gt $MAX_PATH_LENGTH || $name_length -gt $MAX_NAME_LENGTH || $(has_illegal_chars "$item_name"; echo $?) -eq 0 || "$item_name" =~ _[[:space:]]+_ || "$item_name" =~ [[:space:]][[:space:]]+ ]]; then
                echo "Item: $item_path" >> "$log_file"
                if [[ $path_length -gt $MAX_PATH_LENGTH || $name_length -gt $MAX_NAME_LENGTH ]]; then
                    echo "Path Length: $path_length" >> "$log_file"
                    echo "Name Length: $name_length" >> "$log_file"
                    echo "Reason: Long Path or Name" >> "$log_file"
                elif [[ $(has_illegal_chars "$item_name"; echo $?) -eq 0 ]]; then
                    echo "Reason: Illegal Characters" >> "$log_file"
                elif [[ "$item_name" =~ _[[:space:]]+_ ]]; then
                    echo "Reason: Space-Underscore-Space" >> "$log_file"
                elif [[ "$item_name" =~ [[:space:]][[:space:]]+ ]]; then
                    echo "Reason: Multiple Spaces" >> "$log_file"
                fi
                
                # Generate new name
                local ext=""
                if [[ -f "$item" ]]; then
                    ext="${item_name##*.}"
                    if [[ "$ext" == "$item_name" ]]; then
                        ext=""  # No extension
                    else
                        ext=".$ext"
                    fi
                fi
                
                new_name=$(generate_unique_name "$item_name" "$(dirname "$item")" "$ext" "$path_length")
                new_path="$(dirname "$item")/$new_name"
                new_path_length=${#new_path}
                new_name_length=${#new_name}
                
                # Skip if no rename is needed (same name)
                if [[ "$new_name" == "$item_name" ]]; then
                    echo "No rename needed for '$item_name' (name already valid)" >> "$log_file"
                    echo "No rename needed for '$item_name' (name already valid)"
                    echo "------------------------" >> "$log_file"
                    ((items_processed++))
                    ((total_processed++))
                    continue
                fi
                
                if [[ $DRY_RUN -eq 1 ]]; then
                    if [[ $path_length -gt $MAX_PATH_LENGTH || $name_length -gt $MAX_NAME_LENGTH ]]; then
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Old Path Length: $path_length, Old Name Length: $name_length, New Path Length: $new_path_length, New Name Length: $new_name_length)" >> "$log_file"
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Old Path Length: $path_length, Old Name Length: $name_length, New Path Length: $new_path_length, New Name Length: $new_name_length)"
                    elif [[ $(has_illegal_chars "$item_name"; echo $?) -eq 0 ]]; then
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Reason: Illegal Characters)" >> "$log_file"
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Reason: Illegal Characters)"
                    elif [[ "$item_name" =~ _[[:space:]]+_ ]]; then
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Reason: Space-Underscore-Space)" >> "$log_file"
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Reason: Space-Underscore-Space)"
                    elif [[ "$item_name" =~ [[:space:]][[:space:]]+ ]]; then
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Reason: Multiple Spaces)" >> "$log_file"
                        echo "[DRY-RUN] Would rename '$item_name' to '$new_name' (Reason: Multiple Spaces)"
                    fi
                else
                    # Perform the rename
                    mv -n "$item" "$new_path"
                    if [[ $? -eq 0 ]]; then
                        if [[ $path_length -gt $MAX_PATH_LENGTH || $name_length -gt $MAX_NAME_LENGTH ]]; then
                            echo "Renamed '$item_name' to '$new_name' (Old Path Length: $path_length, Old Name Length: $name_length, New Path Length: $new_path_length, New Name Length: $new_name_length)" >> "$log_file"
                            echo "Renamed '$item_name' to '$new_name' (Old Path Length: $path_length, Old Name Length: $name_length, New Path Length: $new_path_length, New Name Length: $new_name_length)"
                        elif [[ $(has_illegal_chars "$item_name"; echo $?) -eq 0 ]]; then
                            echo "Renamed '$item_name' to '$new_name' (Reason: Illegal Characters)" >> "$log_file"
                            echo "Renamed '$item_name' to '$new_name' (Reason: Illegal Characters)"
                        elif [[ "$item_name" =~ _[[:space:]]+_ ]]; then
                            echo "Renamed '$item_name' to '$new_name' (Reason: Space-Underscore-Space)" >> "$log_file"
                            echo "Renamed '$item_name' to '$new_name' (Reason: Space-Underscore-Space)"
                        elif [[ "$item_name" =~ [[:space:]][[:space:]]+ ]]; then
                            echo "Renamed '$item_name' to '$new_name' (Reason: Multiple Spaces)" >> "$log_file"
                            echo "Renamed '$item_name' to '$new_name' (Reason: Multiple Spaces)"
                        fi
                        ((items_changed++))
                        ((total_changed++))
                    else
                        echo "Failed to rename '$item_name'" >> "$log_file"
                        echo "Failed to rename '$item_name'"
                    fi
                fi
                echo "------------------------" >> "$log_file"
                ((items_processed++))
                ((total_processed++))
            fi
        done < <(find "$dir" -print0 | sort -r)
        
        # In dry-run mode, exit after one pass
        if [[ $DRY_RUN -eq 1 ]]; then
            echo "Dry-run complete. Processed $items_processed items in pass $pass" | tee -a "$log_file"
            break
        fi
        
        echo "Pass $pass complete. Processed $items_processed items, made $items_changed changes" | tee -a "$log_file"
        
        # Exit if no changes were made
        if [[ $items_changed -eq 0 ]]; then
            break
        fi
    done
    
    echo "Total processed: $total_processed items, Total changes: $total_changed" | tee -a "$log_file"
}

# Check if source directory is provided
if [[ -z "$SOURCE_DIR" || ! -d "$SOURCE_DIR" ]]; then
    echo "Usage: $0 [--dry-run] <source_directory>"
    echo "Please provide a valid directory to scan."
    exit 1
fi

# Convert SOURCE_DIR to absolute path
SOURCE_DIR=$(realpath "$SOURCE_DIR")

# Run the script
process_paths "$SOURCE_DIR" "$OUTPUT_LOG"

echo "Scan complete. Check $OUTPUT_LOG for details."
