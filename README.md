# Stree - A Better Tree Command

**Stree** is an enhanced directory tree visualization tool for Unix-like systems, providing more control, formatting options, and output formats compared to the traditional `tree` command. It allows you to inspect directories with various filters, color-coded output, and export options in multiple formats such as JSON, CSV, XML, HTML, and YAML.

## Features
- 📁 **Flexible File Listing** – List files, directories, or both, with options to sort by name, time, status, or version.
- 🌳 **Customizable Output** – Control indentation, colors, and file path display. Print metadata like permissions, ownership, size, and modification dates.
- 🔍 **Filtering** – List or ignore files with wildcards and regex. Filter hidden files, empty directories, or gitignored files.
- 📜 **Multiple Export Formats** – Output as CSV, JSON, XML, HTML, Markdown, or YAML.
- ⚡ **Performance** – Supports partial hashing and depth control for faster directory traversal.
- 🔗 **Symbolic Links** – Optionally follow symbolic links to directories.
- 🚧 **Xdev Support** – Restrict the search to a single filesystem, similar to `find -xdev`.

## Installation
Ensure you have Perl 5.10 or later installed, along with the following Perl modules:
```bash
cpan install Digest::SHA Term::ANSIColor Getopt::Long::Descriptive Cpanel::JSON::XS HTML::Tiny Text::CSV YAML::XS XML::Writer
```

## Usage
```bash
stree [options] [directory]
```

## Options

### General Options
- `-?`, `--help`            : Prints the help information and exits.
- `--[no-]version`          : Prints the version information and exits.

### Display Options
- `-a`, `--all`             : Show all files, including hidden ones.
- `-f`, `--full`            : Print the full path prefix for each file.
- `-F`, `--suffix`          : Print custom type indicators.
- `-Q`, `--quotes`          : Quote filenames in double quotes.
- `-q`, `--question-marks`  : Replace non-printable characters in filenames with question marks.

### Sorting Options
- `-b`, `--dirs-first`      : List directories before files.
- `-B`, `--files-first`     : List files before directories.
- `-r`, `--reverse`         : Sort the output in reverse order.
- `-t`, `--time`            : Sort by last modification time.
- `-c`, `--status`          : Sort by last status change time.
- `-V`, `--sort-version`    : Sort by version numbers.
- `-U`, `--no-sort`         : Disable sorting; output order is arbitrary.

### Filtering Options
- `-d`, `--dirs`            : List directories only.
- `-P`, `--pattern STR`     : List only files matching a pattern (supports PCRE).
- `-I`, `--ignore STR`      : Exclude files matching a pattern (supports PCRE).
- `-R`, `--ignore-case`     : Ignore case when matching patterns.
- `-G`, `--gitignore`       : Use `.gitignore` files for filtering.
- `-E`, `--prune`           : Do not display empty directories.

### Depth and Recursion
- `-L INT`, `--max-depth INT` : Limit recursion depth.
- `-x`, `--xdev`             : Stay on the current filesystem.
- `-l`, `--links`            : Follow symbolic links that point to directories.

### Metadata Display
- `-s`, `--size`            : Show file sizes.
- `-D`, `--date`            : Show last modification date.
- `-e`, `--device`          : Show device number of files.
- `-g`, `--group`           : Show file group name or GID.
- `-u`, `--user`            : Show file owner or UID.
- `-p`, `--permissions`     : Show file permissions.
- `-n`, `--inodes`          : Show inode numbers.
- `-j`, `--hash`            : Compute and display SHA256 hash.
- `-h INT`, `--partial INT` : Use only the first `INT` bytes for hashing.

### Alternative Input
- `-A STR`, `--from-file STR` : Read directory listing from a file.

### Output Formatting
- `-C`, `--csv`             : Output as CSV.
- `-J`, `--json`            : Output as JSON.
- `-H`, `--html`            : Output as HTML.
- `-M`, `--markdown`        : Output as Markdown.
- `-X`, `--xml`             : Output as XML.
- `-Y`, `--yaml`            : Output as YAML.
- `-o STR`, `--output STR`  : Write output to a file.
- `-i`, `--no-indent`       : Remove indentation (useful with `-f`, `-J`, or `-x`).

## Examples

### Print a directory tree with all files
```sh
./stree -a /path/to/directory
```

### List only directories, sorted by modification time
```sh
./stree -d -t /path/to/directory
```

### Export directory structure to JSON
```sh
./stree --json -o tree.json /path/to/directory
```

### Limit recursion depth to 3 levels
```sh
./stree -L 3 /path/to/directory
```

### Filter files using a pattern (show only `.txt` files)
```sh
./stree -P "*.txt" /path/to/directory
```

### Ignore files that match a pattern (hide `.log` files)
```sh
./stree -I "*.log" /path/to/directory
```
