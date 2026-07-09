# kokoro script
#

## Setup

SELF=$0
TAB=$(printf '\t')

## Step 0 - Dependency Check
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

## Step 1 - Mode Dispatch and Run Dependency Check
if [ "$1" = "--list-matches" ]; then
	generate_matches "$2"
	exit 0
fi

check_dependencies
