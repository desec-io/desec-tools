#!/usr/bin/env bash

if [ -z "$2" ]
  then
    cat <<- EOM
	Usage: $0 oldfile newfile

	The input files are expected to contain a JSON array of RRset objects as
	described at https://desec.readthedocs.io/en/latest/#rrset-field-reference.
	The script then outputs a diff-like JSON array. Filenames equal to a dash -
	are mapped to stdin.

	The most common use case is that oldfile is the response body of a GET rrsets/
	request, and newfile is the desired target state. When the output is used as
	the body of a bulk PATCH request (see docs above), the state will transition
	from the one represented by oldfile to the one represented by newfile.

	Note: The NS RRset at the zone apex (no subdomain) is touched only if it is
	contained in newfile. Otherwise, it will be ignored even if present in
	oldfile, so that NS records are not inadvertently deleted. (You can force
	deletion by putting an empty NS RRset into newfile.)

	Example:

	# Compute diff to delete all RRsets (except NS RRset at zone apex)
	\$ $0 \\
	    <(curl -sS https://desec.io/api/v1/domains/:domain/rrsets/ -H "Authorization: Token \$TOKEN") \\
	    - <<< '[]'
EOM
    exit 1
fi

# Check dependencies
if [ ! -x "$(which jq 2>/dev/null)" ]; then
  echo "please install: jq (https://stedolan.github.io/jq/download/)" >&2
  exit 1
fi

# Do /dev/stdin mapping as jq does not support it out of the box
if  [ "$1" = "-" ]
then
    oldfile=/dev/stdin
else
    oldfile=$1
fi

if  [ "$2" = "-" ]
then
    newfile=/dev/stdin
else
    newfile=$2
fi

# Quoting the EOM delimiter prevents variable expansion inside the heredoc
read -r -d '' FILTER_COMMAND <<- 'EOM'
	# Prepare and sanitize
	{old: $old[0] | map({subname: .subname, type: .type, ttl: .ttl, records: .records}),
	 new: $new[0] | map({subname: .subname, type: .type, ttl: .ttl, records: .records})}
	# Keep apex NS RRset even if not provided in new list
	| del(.old[] | select(.type == "NS" and .subname == ""))
	# Sort records values within each RRset to facilitate equality checking
	| with_entries(.value |= (.[].records |= sort))
	# 1) Take new RRsets and skip unchanged ones, based on (type, subname, ttl, records)
	# 2) Include removed RRsets for deletion, based on (type, subname) only
	| (.new - .old)
	  + (  (.old | map({subname: .subname, type: .type}))
	     - (.new | map({subname: .subname, type: .type}))
	    | map(.records |= []))
EOM

jq -c -n --slurpfile old $oldfile --slurpfile new $newfile "$FILTER_COMMAND"
