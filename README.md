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
Examples:
```bash
stree -a -D -s /var/log
stree -J -o tree.json ~/Documents
stree --xml --output listing.xml /etc
```

## Options
- `-a, --all` – Show hidden files.
- `-D, --date` – Print modification dates.
- `-s, --size` – Display file sizes.
- `-J, --json` – Export tree as JSON.
- `-C, --csv` – Export as CSV.
- `-X, --xml` – Export as XML.
- `-H, --html` – Export as HTML.
- `-Y, --yaml` – Export as YAML.
- `-f, --full` – Print full paths.
- `-L, --max-depth=N` – Limit depth to N levels.

Run `stree --help` for the full list of options.

