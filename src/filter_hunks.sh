#!/usr/bin/env bash

# This script filters a unified diff based on a provided regex pattern for
# hunk content, and optionally filters file paths based on include/exclude
# patterns. It reads a diff from STDIN and outputs the filtered diff
# incrementally to STDOUT.
#
# Usage: $0 [options] <hunk_regex_pattern>
# Options:
#   -I, --include <pattern>  Include only file paths matching this regex pattern
#   -X, --exclude <pattern>  Exclude file paths matching this regex pattern

# Function to print usage
print_usage() {
    echo "Usage: $0 [options] <hunk_regex_pattern>"
    echo "Options:"
    echo "  -I, --include <pattern>  Include only file paths matching this regex pattern"
    echo "  -X, --exclude <pattern>  Exclude file paths matching this regex pattern"
    exit 1
}

# Parse command-line arguments
include_pattern=""
exclude_pattern=""
while [[ $# -gt 0 ]]; do
    case $1 in
        -I|--include)
            include_pattern="$2"
            shift 2
            ;;
        -X|--exclude)
            exclude_pattern="$2"
            shift 2
            ;;
        *)
            if [[ -z "$hunk_regex_pattern" ]]; then
                hunk_regex_pattern="$1"
            else
                print_usage
            fi
            shift
            ;;
    esac
done

# Check if a hunk regex pattern is provided
if [ -z "$hunk_regex_pattern" ]; then
    print_usage
fi

# Variables to track the current state
in_file_header=false
in_hunk=false
current_hunk=""
current_file_header=""
current_file_content=""
file_has_matching_hunk=false
current_file_paths=()

# Function to check if either file path matches the include/exclude patterns
file_paths_match() {
    local old_path="$1"
    local new_path="$2"
    if [[ -n "$include_pattern" && ! "$old_path" =~ $include_pattern && ! "$new_path" =~ $include_pattern ]]; then
        return 1
    fi
    if [[ -n "$exclude_pattern" && ("$old_path" =~ $exclude_pattern || "$new_path" =~ $exclude_pattern) ]]; then
        return 1
    fi
    return 0
}

# Function to process a complete hunk
process_hunk() {
    if echo "$current_hunk" | grep -qE "$hunk_regex_pattern"; then
        # If this is the first matching hunk for the file, include the file header
        if ! $file_has_matching_hunk; then
            current_file_content+="$current_file_header"
            file_has_matching_hunk=true
        fi
        # Add the matching hunk to the file content
        current_file_content+="$current_hunk"
    fi
}

# Function to output the current file's content and reset variables
output_and_reset() {
    if $file_has_matching_hunk && file_paths_match "${current_file_paths[0]}" "${current_file_paths[1]}"; then
        echo -n "$current_file_content"
    fi
    current_file_header=""
    current_file_content=""
    file_has_matching_hunk=false
    current_file_paths=()
}

# Read the diff from STDIN line by line
while IFS= read -r line; do
    # Check for the start of a new file
    if [[ $line =~ ^diff ]]; then
        # Process the last hunk of the previous file if it exists
        if $in_hunk; then
            process_hunk
        fi
        # Output the previous file's content and reset variables
        output_and_reset
        # Extract the file paths
        IFS=" " read -r -a current_file_paths <<< "$(echo "$line" | awk '{print $3, $4}')"
        # Start new file header
        current_file_header="$line"$'\n'
        in_hunk=false
        in_file_header=true
    # Check for the end of the file header
     elif $in_file_header && [[ $line =~ ^\+\+\+ ]]; then
        current_file_header+="$line"$'\n'
        in_file_header=false
    # Accumulate file header lines
    elif $in_file_header; then
        current_file_header+="$line"$'\n'
    # Check for the start of a new hunk
    elif [[ $line =~ ^@@ ]]; then
        # Process the previous hunk if it exists
        if $in_hunk; then
            process_hunk
        fi
        # Start a new hunk
        in_hunk=true
        current_hunk="$line"$'\n'
    elif $in_hunk; then
        # Add the line to the current hunk
        current_hunk+="$line"$'\n'
    fi
done

# Process the last hunk
if $in_hunk; then
    process_hunk
fi

# Output the last file's content
output_and_reset
