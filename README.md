
# `filesystem_filter.sh`

A lightweight, zero-dependency Bash utility designed to purge operating system-generated metadata, hidden files, and thumbnail caches left behind by macOS and Windows clients. 

This tool is optimized for various environments and deployment scenarios, including:
* Local storage volumes and directories
* SMB/CIFS network-attached shares
* Media server directories (e.g., Plex, Jellyfin, Unraid, TrueNAS) to prevent indexing anomalies and false-positive media detection


## Installation

You can install `filesystem_filter.sh` using either **User Mode** (default, no root required) or **System Mode** (requires `sudo`).

### User Mode Installation (Default)

#### Automatic Install Using `curl`
Installs into your local user directory (`~/.local/bin`) without requiring root privileges:
```bash
curl -fsSL https://raw.githubusercontent.com/Miller11k/Filesystem-Filter/main/install.sh | sh
```

*(If prompted about your `PATH`, ensure `~/.local/bin` is added to your shell profile).*

#### Manual Install Using `git clone`
If you prefer to set it up manually:

```bash
# Clone the repository
git clone https://github.com/Miller11k/Filesystem-Filter.git
cd Filesystem-Filter

# Make the script executable and move it to your system PATH (or ~/.local/bin)
chmod +x filesystem_filter.sh
sudo mv filesystem_filter.sh ~/.local/bin/filesystem_filter
ln -s ~/.local/bin/filesystem_filter ~/.local/bin/fsfltr
```

### System-Wide Mode Installation

#### Automatic Install Using `curl`
Installs globally into `/usr/local/bin` (requires root privileges):

```bash
curl -fsSL https://raw.githubusercontent.com/Miller11k/Filesystem-Filter/main/install.sh | sh -s -- --system
```

#### Manual Install Using `git clone`
If you prefer to set it up manually:

```bash
# Clone the repository
git clone https://github.com/Miller11k/Filesystem-Filter.git
cd Filesystem-Filter

# Make the script executable and move it to your system PATH (or ~/.local/bin)
chmod +x filesystem_filter.sh
sudo mv filesystem_filter.sh /usr/local/bin/filesystem_filter
ln -s /usr/local/bin/filesystem_filter /usr/local/bin/fsfltr
```

---

## Target Artifacts (What Gets Cleaned Up)

Operating systems like macOS and Windows create background metadata and cache files. While harmless on local drives, these files create clutter, waste space, and trigger false positives in automated media indexers.

### macOS/Apple Artifacts

| Type | Path / Pattern | Description |
| --- | --- | --- |
| **Files** | `.DS_Store` | Finder folder metadata (layout, view settings, icon positions) |
|  | `._*` | AppleDouble resource fork sidecar files |
|  | `Icon?` | Custom folder icon file |
|  | `.apdisk` | Apple Partition Disk network metadata |
|  | `.VolumeIcon.icns` | Custom volume icon file |
|  | `._.Trashes` | AppleDouble sidecar for the `.Trashes` folder |
|  | `.LSOverride` | Launch Services attribute override file |
| **Directories** | `.Spotlight-V100` | Spotlight search index directory |
|  | `.Trashes` | Per-volume Trash folder |
|  | `.fseventsd` | FSEvents log directory (Time Machine & Spotlight) |
|  | `.AppleDouble` | Legacy resource fork storage directory |
|  | `.TemporaryItems` | Transient files created during operations |
|  | `.AppleDB` / `.AppleDesktop` | Legacy Desktop Database folders (pre-OS X) |
|  | `.DocumentRevisions-V100` | Auto-save and document revision store |

---

### Windows Artifacts *(Case-Insensitive)*

| Type | Path / Pattern | Description |
| --- | --- | --- |
| **Files** | `Thumbs.db` | Windows Explorer thumbnail cache |
|  | `ehthumbs.db` | Windows Media Center thumbnail cache |
|  | `Desktop.ini` | Folder view customization metadata |
|  | `autorun.inf` | AutoRun/AutoPlay manifest file |
|  | `.*.lnk` | Hidden Windows shortcut files |
| **Directories** | `$RECYCLE.BIN` | Per-volume Windows Recycle Bin folder |
|  | `System Volume Information` | System restore points and VSS shadow copies |

---

## Usage

### Syntax

```bash
filesystem_filter.sh [OPTIONS] [TARGET]

```

> If `TARGET` is omitted, the script defaults to cleaning the **current directory** (`.`). By default, execution is **non-recursive** unless `-r` / `--recursive` is supplied.

---

### Options & Flags

| Flag | Long Form | Description |
| --- | --- | --- |
| `-a` | `--apple` | Target Apple/macOS items only (skips Windows) |
| `-w` | `--windows` | Target Windows items only (skips Apple) |
| `-n` | `--dry-run` | Print what would be deleted without taking action |
| `-v` | `--verbose` | Print each path as it is removed (ignored during dry-run) |
| `-r` | `--recursive` | Descend recursively into subdirectories |
| `-l` | `--log FILE` | Append absolute path of every deleted item to `FILE` |
| `-q` | `--quiet` | Suppress all stdout output (overrides `--verbose`) |
| `-h` | `--help` | Print help documentation and exit |

---

### Examples

#### 1. Preview changes recursively on a share (Dry-Run)

Test what would be cleaned in `/mnt/media` and log results without modifying anything:

```bash
filesystem_filter --dry-run --verbose --log /tmp/junk.log /mnt/media

```

#### 2. Clean Apple artifacts recursively

Recursively strip macOS metadata files out of the current working directory:

```bash
filesystem_filter --apple --recursive

```

#### 3. Automated background cleanup

Run silently against network shares and maintain an audit log:

```bash
filesystem_filter --quiet --log /var/log/junk.log /srv/shares

```

---

## Cron Integration

To keep network folders pristine on a schedule, add a task to your system `crontab`:

```bash
crontab -e

```

Example cron job to run every night at 2:00 AM (recursively cleaning `/mnt/media` quietly):

```cron
0 2 * * * /usr/local/bin/filesystem_filter --recursive --quiet --log /var/log/filesystem_filter.log /mnt/media

```

---

## Author & Version

* **Author:** Miller Kodish
* **Version:** 1.0.0