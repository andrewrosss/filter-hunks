#!/usr/bin/env awk -f

# Usage:
#   filter_delimited.awk -v delimiter="<delimiter>" -v regex="<regex>" -v inverted=1 < input_file
#
# ## Example 1
#
# Suppose we have a file (input_file.log) like:
# 
# ```text
# ERROR: foo
#   context - more context
# ERROR: bar
#   words and other words
#   this hunk has more lines than the other hunks
# ERROR: baz
#   words, plenty of words
# ```
#
# And we want to filter (keep) all the ERROR hunks containing the string "word",
# then we can run:
#
# ```bash
# ./filter_delimited.awk -v delimiter="^ERROR:" -v regex="words" < input_file.log
# ```
#
# This will produce:
#
# ```text
# ERROR: bar
#   words and other words
#   this hunk has more lines than the other hunks
# ERROR: baz
#   words, plenty of words
# ```
#
# ## Example 2
#
# Again, suppose we have a file (input_file.log), this time with different
# kinds of hunks (LOG vs ERROR):
# 
# ```text
# Mon Jan 20 12:34:01 EDT 2025 - LOG - a message
#   hello
# Mon Jan 20 12:34:02 EDT 2025 - ERROR - foo
#   context - more context
# Mon Jan 20 12:34:03 EDT 2025 - ERROR - bar
#   words and other words
#   this hunk has more lines than the other hunks
# Mon Jan 20 12:34:04 EDT 2025 - LOG - something else
#   more stuff
# Mon Jan 20 12:34:05 EDT 2025 - ERROR - baz
#   words, plenty of words
# 
# ```
#
# And we want to filter (keep) all the ERROR hunks containing string "word",
# in this case we can run filter_delimited.awk twice, once to grab all the ERROR
# hunks, and then again to filter those hunks (don't mind the UUOC - it makes
# it easier to read for the example):
#
# ```bash
# cat samples/sample02.log | ./src/filter_delimited.awk -v delimiter='^[^[:space:]].+? - (LOG|ERROR)' -v regex='- ERROR -' | ./src/filter_delimited.awk -v delimiter='^[^[:space:]].+? - ERROR' -v regex='words'
# #                                                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^          ^^^^^^^^^^^                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^          ^^^^^^^
# #                                                                  generic delimiter (LOG or ERROR)      keep only ERROR hunks                                 delimiter, assuming only error hunks    the needle in the haystack
# ```
#
# This will produce:
#
# ```text
# Mon Jan 20 12:34:02 EDT 2025 - ERROR - bar
#   words and other words
#   this hunk has more lines than the other hunks
# Mon Jan 20 12:34:05 EDT 2025 - ERROR - baz
#   words, plenty of words
# ```
BEGIN {
    # Initialize user-configurable variables
    if (length(delimiter) == 0) {
        # usage: `-v delimiter="<delimiter>"`
        # The delimiter is the string that separates the hunks in the input file
        print "Delimiter not set. Must be set to a non-empty string." >> "/dev/stderr"
        print "Set by passing the awk flag: `-v delimiter='<delimiter>'`" >> "/dev/stderr"
        exit 1 # we need this to be set to something
    }
    if (length(regex) == 0) {
        # usage: `-v regex="<regex>"`
        # The regex is the string that will be used to match the hunks
        # against the input file
        regex = /.*/ # default to match everything
        print "Regex not set. Defaulting to match EVERYTHING. This is probably not what you want" >> "/dev/stderr"
        print "Set by passing the awk flag: `-v regex='<regex>'`" >> "/dev/stderr"
        # this isn't an error ... but, wat
    }
    if (length(inverted) == 0) {
        # usage: `-v inverted=1`
        # The inverted flag is used to invert the match
        # If set to 1, hunks NOT matching the regex will be printed
        inverted = 0 # default to not inverted
    }
    hunk=""
}

{
    if (hunk && $0 ~ delimiter) {
        # we're at the start of a new hunk, check if the previous hunk matches
        # the regex and print it if it does
        if (!inverted && hunk ~ regex) {
            printf "%s", hunk
        } else if (inverted && hunk !~ regex) {
            printf "%s", hunk
        }

        # reset the hunk
        hunk = ""
    }
    # append the current line to the hunk
    hunk = hunk $0 "\n"
}


END {
    if (!hunk) {
        # no hunks were found
        print "No hunks found." >> "/dev/stderr"
        exit 1
    }

    # check the last hunk
    if (!inverted && hunk ~ regex) {
        printf "%s", hunk
    } else if (inverted && hunk !~ regex) {
        printf "%s", hunk
    }
}
