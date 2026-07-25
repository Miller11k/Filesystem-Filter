#!/usr/bin/env bash
# =============================================================================================================================
# filesystem_filter.sh
# 
# Description:
#   This program removes general OS-generated metadata and thumbnail cache files. These files are harmless on the OS they come 
#   from but waste space clutter folders, and in some cases can trigger false positives in programs with media scanners.
# 
# Usage:
#   filesystem_filter.sh [OPTIONS] [TARGET]
#
#   TARGET: Path to the directory to clean (defaults to current directory).
# 
# Options:
#   - a, --apple        Targets Apple/macOS related items; skips other items
#   - w, --windows      Targets Windows related items; skips other items
#   - n, --dry-run      Prints what would be removed without deleting anything
#   - v, --verbose      Print each path/file as it is removed as it is removed
#                       (no-op with --dry-run)
#   - r, --recursive    Descend into the subdirectories of TARGET directory
#   - l, --log FILE     Appends the absolute path of every item deleted to
#                       FILE (created if does not exist)
#   - q, --quiet        Suppresses all stdout output (overrides --verbose)
#   - h, --help         Prints this help message and exits
# 
# Exit Codes:
#   0 Success (includes dry-run)
#   1 Invalid argument or unusable TARGET
# 
# Examples:
#   1.) Dry-Run on '/mnt/media', logging what would be removed:
#       filesystem_filter.sh --dry-run --verbose --log /tmp/junk.log /mnt/media
#
#   2.) Remove only Apple items from the current directory (recursively):
#       filesystem_filter.sh --apple --recursive
#
#   3.) Run silently from cron, logging what would be deleted:
#       filesystem_filter.sh --quiet --log /tmp/junk.log /srv/shares
#
# Author: Miller Kodish
# Version: 1.0.0
# =============================================================================================================================

set -euo pipefail   # Bash strict mode

# -----------------------------------------------------------------------------------------------------------------------------
# Default option values
#   - When flags are defaulted to "true", they are enabled.
#   - When flags are defaulted to "false", they are disabled.
#   - Flags are toggled by argument parser.
# -----------------------------------------------------------------------------------------------------------------------------
TARGET="."          # Target directory to clean (overridden by the first 
                    # positional argument)
DO_APPLE=true       # Flag to clean Apple/macOS artifacts (enabled when true)
DO_WINDOWS=true     # Flag to clean Windows artifacts (enabled when true)
DRY_RUN=false       # Only print what would be removed (disabled when false)
VERBOSE=false       # Print each path when deleted (disabled when false)
RECURSE=false       # Go through all subdirectories of target directory
                    # (disabled when false)
QUIET=false         # Suppress all text output (disabled when false)
LOG_FILE=""         # Path to log deleted entries to (empty disables logging)

# -----------------------------------------------------------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------------------------------------------------------

# Extracts documentation from top of script and displays it
usage() {
  local start end   # Set two variables for start and end line numbers

  start=$(grep -n '^# Description:' "$0" |  # Find every "# Description:" line
          head -1 |                         # Grab the first match
          cut -d: -f1)                      # Save the line number

  end=$(grep -n '^# Version:' "$0" |  # Find ever "# Version:" line
         head -1 |                    # Grab the first match
         cut -d: -f1)                 # Save the line number

  sed -n "${start},${end}p" "$0" |  # Grab the reference content
    sed 's/^# \{0,1\}//'            # Delete beginning "# "

  exit 0  # Exit successfully
}

# Prints log line if not set to quiet mode
log() {
  $QUIET || echo "$@"
}

# Prints warning message to standard error (never gets supressed)
warn() {
  echo "Warning: $*" >&2
}

# Prints error message and fails
die() {
  echo "Error: $*" >&2  # Prints formatted error message
  exit 1                # Exit with failure status
}

# -----------------------------------------------------------------------------------------------------------------------------
# Argument Parsing:
#   - Supports both short flags (i.e., "-n") and long flags (i.e. "--dry-run")
#   - Flags may appear before, after, or interleaved with positional arguments (i.e., TARGET path)
#   - A bare "--" terminates option pr ocessing so that a TARGET path beginning with "-" can be passed safely
#   - Invalid flag usage produces an error rather than silently being ignored
# -----------------------------------------------------------------------------------------------------------------------------

POSITIONAL=() # Create empty array for positional arguments
while [[ $# -gt 0 ]]; do  # Loop through all flags
  case "$1" in            # Check which flags are set
    # Check for Apple only filtering flag
    -a|--apple)
      DO_WINDOWS=false;   # Set Windows filtering to false (only Apple files)
      shift               # Discard flag (handled)
      ;; 

    # Check for Windows only filtering flag
    -w|--windows)
      DO_APPLE=false;     # Set Apple filtering to false (only Windows files)
      shift               # Discard flag (handled)
      ;;

    # Check for dry-run flag
    -n|--dry-run)
      DRY_RUN=true;       # Enable dry-run mode
      shift               # Discard flag (handled)
      ;; 

    # Check for verbose logging flag
    -v|--verbose)
      VERBOSE=true;       # Enable verbose logging
      shift               # Discard flag (handled)
      ;;

    # Check for recursive flag
    -r|--recursive)
      RECURSE=true;       # Enable recursive operation mode
      shift               # Discard flag (handled)
      ;;

    # Check for quiet flag
    -q|--quiet)
      QUIET=true;         # Enable quiet operation mode
      shift               # Discard flag (handled)
      ;;

    -l|--log)
      # Require an argument following --log / -l
      [[ -n "${2:-}" ]] || die "--log requires a file path argument"
      LOG_FILE="$2"       # Save path of log file to variable
      shift 2             # Discard both flag and filepath (handled)
      ;;

    # Check for help flag
    -h|--help)
      usage               # Display help manual (and exit script)
      ;;

    # Check for double-dash option terminator
    --)
      shift               # Discard flag (handled)
      POSITIONAL+=("$@")  # Append remaining arguments to positional array
      break               # Stop parsing and exit the loop
      ;;

    # Exit with error for any unrecognized flags
    -*)
      die "Unknown option: '$1'  (run with --help for usage)"
      ;;

    # Handle standard positional arguments (i.e., TARGET directory path)
    *)  POSITIONAL+=("$1"); # Save non-flag arguments to positional array
    shift                   # Discard flag (handled)
    ;;
  esac
done

# Apply the first positional argument as TARGET, if provided.
[[ ${#POSITIONAL[@]} -gt 0 ]] && TARGET="${POSITIONAL[0]}"

# Validate that TARGET exists and is a directory before doing any work.
[[ -d "$TARGET" ]] || die "Target is not a directory: '$TARGET'"

# -----------------------------------------------------------------------------------------------------------------------------
# Resolve Find Depth Arguments:
#   - When --no-recurse is active, -maxdepth 1 restricts find to the top level of TARGET only
#   - Otherwise DEPTH_ARGS is left empty, giving find its default unlimited depth
# -----------------------------------------------------------------------------------------------------------------------------

DEPTH_ARGS=()                           # Array form so it can be safely expanded (or left empty)
$RECURSE || DEPTH_ARGS=(-maxdepth 1)    # Default (non-recursive) run: cap find at the top-level of TARGET only

# -----------------------------------------------------------------------------------------------------------------------------
# do_delete — locate and remove matching files or directories
#
# Arguments:
#   $1  Entry type passed to find's -type predicate ('f' for file, 'd' for dir)
#   $2  Name-match flag: '-name' (case-sensitive) or '-iname' (case-insensitive)
#   $@  One or more filename glob patterns to match against
#
# - Behaviour is controlled by the global flags DRY_RUN, VERBOSE, QUIET, and LOG_FILE
# - Directories are removed recursively (rm -rf)
#     - Files with rm -f find errors (e.g. permission denied on a subdirectory) are suppressed so that one inaccessible path 
#       does not abort the entire run.
# -----------------------------------------------------------------------------------------------------------------------------

do_delete() {
  local ftype="$1";    shift   # 'f' or 'd' consumed first (then removed from $@)
  local nameflag="$1"; shift   # '-name' or '-iname' consumed next (then removed from $@)
  local patterns=("$@")        # Everything left over is the list of glob patterns to match

  # Build the find OR-expression from the supplied patterns.
  # Results in:  ( -name 'pat1' -o -name 'pat2' -o ... )
  local expr=()     # Stores the assembled find expression
  for i in "${!patterns[@]}"; do             # Iterate through all patterns
    [[ $i -gt 0 ]] && expr+=(-o)             # Insert an "-o" between patterns (not including the first pattern)
    expr+=("$nameflag" "${patterns[$i]}")    # Add it to the expression
  done

  # Collect all matches into an array using NUL-delimited output so that paths containing spaces, 
  # newlines, or special characters are handled correctly.
  local matches=()                    # Stores all matching paths found
    while IFS= read -r -d '' path; do   # Iterate through all entries
      matches+=("$path")                # Add path to match array
    done < <(
      # Search TARGET (DEPTH_ARGS adds -maxdepth 1 when non-recursive)
      find "$TARGET" "${DEPTH_ARGS[@]}" \
          # Restrict to files ('f') or directories ('d') as set earlier
          -type "$ftype" \
          # Use the expressions set earlier
          \( "${expr[@]}" \) \
          # NUL-delimit output so filenames (spaces/newlines survive intact)
          -print0 \
          2>/dev/null   # Suppress errors so one bad path doesn't break everything
    )

  [[ ${#matches[@]} -eq 0 ]] && return 0  # Return early if nothing matches (print nothing)

  for path in "${matches[@]}"; do
    if $DRY_RUN; then   # In dry-run mode, report the path but take no destructive action
      log "[dry-run] would remove: $path"
    else                # Otherwise, report the path AND take destructive action
      $VERBOSE && log "removing: $path"

      # Append to the log file before deletion so the record exists even if the rm call fails for some reason
      [[ -n "$LOG_FILE" ]] && echo "$path" >> "$LOG_FILE"

      if [[ "$ftype" == "d" ]]; then
        rm -rf -- "$path"   # Remove contents too if filetype to remove is a directory
      else
        rm -f  -- "$path"   # If filetype is not a directory, just remove the file
      fi
    fi
  done
}

# -----------------------------------------------------------------------------------------------------------------------------
# Run Banner:
# - Summarise what is about to happen so the operator can confirm intent before any files are touched
# - Skipped entirely when --quiet is active
# -----------------------------------------------------------------------------------------------------------------------------

if ! $QUIET; then   # Only run if quiet flag is not set
  # Print out the scope of what files are being removed
  if $DO_APPLE && $DO_WINDOWS; then   # Both Apple and Windows files set to be removed
    scope="Apple + Windows"
  elif $DO_APPLE; then                # Only Appe files set to be removed
    scope="Apple"
  else                                # Only Windows files set to be removed
    scope="Windows"
  fi

  $DRY_RUN && scope+=" [DRY RUN — no files will be deleted]"      # Print whether or not dry run mode is set
  log "Cleaning $scope junk in: $TARGET"                          # Print what's being deleted
  [[ -n "$LOG_FILE" ]] && log "Logging deletions to: $LOG_FILE"   # Print where logging is being written to (if set)
  log ""
fi
# -----------------------------------------------------------------------------------------------------------------------------
# Apple/macOS Artifacts
#
# Files:
#   .DS_Store            — Finder folder metadata (view settings, icon positions)
#   ._*                  — AppleDouble resource fork sidecars
#   Icon?                — Custom folder icon file (trailing char is CR, not '?')
#   .apdisk              — Apple Partition Disk metadata
#   .VolumeIcon.icns     — Volume-level custom icon
#   ._.Trashes           — AppleDouble sidecar for the .Trashes folder
#   .LSOverride          — Launch Services attribute override
#
# Directories:
#   .Spotlight-V100      — Spotlight search index
#   .Trashes             — Per-volume Trash folder
#   .fseventsd           — FSEvents journal used by Time Machine and Spotlight
#   .AppleDouble         — Resource fork storage directory (older HFS compat)
#   .TemporaryItems      — Transient files created during save operations
#   .AppleDB             — Legacy Desktop Database (pre-OS X)
#   .AppleDesktop        — Legacy Desktop file storage (pre-OS X)
#   .DocumentRevisions-V100 — Auto-save / Versions document store
# -----------------------------------------------------------------------------------------------------------------------------

if $DO_APPLE; then
  log "  [Apple] removing metadata files..."
  do_delete f -name \
    '.DS_Store'        \
    '._*'              \
    'Icon?'            \
    '.apdisk'          \
    '.VolumeIcon.icns' \
    '._.Trashes'       \
    '.LSOverride'

  log "  [Apple] removing metadata directories..."
  do_delete d -name \
    '.Spotlight-V100'           \
    '.Trashes'                  \
    '.fseventsd'                \
    '.AppleDouble'              \
    '.TemporaryItems'           \
    '.AppleDB'                  \
    '.AppleDesktop'             \
    '.DocumentRevisions-V100'
fi

# -----------------------------------------------------------------------------------------------------------------------------
# Windows Artifacts
#
# Matched case-insensitively (-iname) because FAT/exFAT volumes and some SMB
# implementations do not preserve filename capitalisation.
#
# Files:
#   Thumbs.db            — Explorer thumbnail cache (legacy, pre-Vista)
#   ehthumbs.db          — Windows Media Center thumbnail cache
#   Desktop.ini          — Folder view customisation metadata
#   autorun.inf          — AutoRun/AutoPlay manifest (security risk on shares)
#   .*.lnk               — Hidden Windows shortcut files
#
# Directories:
#   $RECYCLE.BIN         — Per-volume Recycle Bin store
#   System Volume Information — System restore points and VSS metadata
# -----------------------------------------------------------------------------------------------------------------------------

if $DO_WINDOWS; then
  log "  [Windows] removing metadata files..."
  do_delete f -iname \
    'Thumbs.db'    \
    'ehthumbs.db'  \
    'Desktop.ini'  \
    'autorun.inf'  \
    '.*.lnk'

  log "  [Windows] removing metadata directories..."
  do_delete d -iname \
    '$RECYCLE.BIN'              \
    'System Volume Information'
fi

# -----------------------------------------------------------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------------------------------------------------------
log ""
log "Done."