# filter-hunks

A simple bash script to filter hunks from a unified diff using regular expressions (regexes).

There are lots of existing tools which do this, but sometimes it's easier to copy/paste a script and be on your way.

## Usage

`filter_hunks.sh` reads from STDIN and writes to STDOUT.

```bash
Usage: src/filter_hunks.sh [options] <hunk_regex_pattern>
Options:
  -I, --include <pattern>  Include only file paths matching this regex pattern
  -X, --exclude <pattern>  Exclude file paths matching this regex pattern
```

Example:

```bash
# keep only hunks that contain the word 'foo'
cat my.diff | filter_hunks.sh '.*foo.*'
#                             ^^^^^^^^^
#                                └- keep only hunks that contain 'foo'

# keep only hunks that modify files in the 'src/'
cat my.diff | filter_hunks.sh -I 'src\/' '.*'
#                                ^^^^^^^ ^^^^
#                                   |     └- keep all hunks
#                                   |
#                              include only files with 'src/' in the path

# keep only hunks that do not modify files ending in '_test.py'
cat my.diff | filter_hunks.sh -X '.*_test\.py$' '.*'
#                                ^^^^^^^^^^^^^^ ^^^^
#                                   |             └- keep all hunks
#                                   |
#                              exclude files ending in '_test.py'
```
