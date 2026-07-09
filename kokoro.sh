# kokoro script
#

# Setup

SELF=$0
TAB=$(printf '\t')

## Input: $1 = query (may be empty)
## Output: newline-seperated "label<TAB>value" lines on stdout

generate_matches() {
    q=$1

    # ---- .sh candidates: matched by filename/title, never content ----
    sh_raw=$(fd -t f -e sh .)

    if [ -n "$sh_raw" ]; then
        # Single awk pass over the whole list -- cost stays flat as the
        # number of .sh files grows.
        sh_lines=$(printf '%s\n' "$sh_raw" | awk -F/ '{
            f = $NF
            sub(/\.sh$/, "", f)
            print f "\t" $0
        }' | sort)
    else
        sh_lines=""
    fi

    if [ -n "$q" ] && [ -n "$sh_lines" ]; then
        # Filter by title only, in a single rg call: get matching line
        # numbers from the title column, then map back to full lines.
        sh_titles=$(printf '%s\n' "$sh_lines" | awk -F"$TAB" '{print $1}')
        sh_hit_nums=$(printf '%s\n' "$sh_titles" | rg -n -i -F -- "$q" | cut -d: -f1)

        if [ -n "$sh_hit_nums" ]; then
            sh_lines=$(printf '%s\n' "$sh_lines" | awk -v nums="$sh_hit_nums" '
                BEGIN {
                    n = split(nums, arr, "\n")
                    for (i = 1; i <= n; i++) keep[arr[i]] = 1
                }
                keep[NR]
            ')
        else
            sh_lines=""
        fi
    fi

    # ---- .md candidates: matched by content, once a query exists ----
    md_raw=$(fd -t f -e md .)

    if [ -z "$q" ]; then
        # Empty query: top-level .md files only.
        if [ -n "$md_raw" ]; then
            md_paths=$(printf '%s\n' "$md_raw" | awk '!/\//' | sort)
        else
            md_paths=""
        fi
    else
        # Non-empty query: single rg call across all .md file contents,
        # subdirectories included.
        if [ -n "$md_raw" ]; then
            md_paths=$(printf '%s\n' "$md_raw" | rg -l -i -F --files-from=- -- "$q" | sort)
        else
            md_paths=""
        fi
    fi

    if [ -n "$md_paths" ]; then
        md_lines=$(printf '%s\n' "$md_paths" | awk -v t="$TAB" '{print $0 t $0}')
    else
        md_lines=""
    fi

    # ---- print combined output ----
    [ -n "$sh_lines" ] && printf '%s\n' "$sh_lines"
    [ -n "$md_lines" ] && printf '%s\n' "$md_lines"
}

# Step 0 - Dependency Check
check_dependencies() {
	if ! command -v git >/dev/null 2>&1; then
		echo "NOTE: git was not found; it is recommended..." >&2
	fi

	missing=""
	command -v fzf >/dev/null 2>&1 || missing="$missing fzf"
	command -v rg >/dev/null 2>&1 || missing="$missing rg"
	command -v fd >/dev/null 2>&1 || missing="$missing fd"

	if [ -n "$missing" ]; then
		echo "ERROR: required tool(s) missing:$missing" >&2
		exit 1
	fi
}

# Step 1 - Mode Dispatch and Run Dependency Check
if [ "$1" = "--list-matches" ]; then
	generate_matches "$2"
	exit 0
fi

check_dependencies

