#!/bin/bash

if [ -z "$2" ]
  then
    cat <<- EOM
	Usage: $0 zone filename

	Replace DNS records in \`zone\` with the ones given in \`filename\` by applying a
	minimal diff. The file is expected to contain a JSON array of RRset objects as
	described at https://desec.readthedocs.io/en/latest/#rrset-field-reference.
	If the filename is equal to a dash -, it is mapped to stdin.

	The script requires rrsets_diff.sh and fetch_zone.py, available at
	https://github.com/desec-io/desec-tools/. The \$TOKEN environment variable is
	required to contain a deSEC API token.

	Note: The NS RRset at the zone apex (no subdomain) is touched only if it is
	contained in the file. Otherwise, it will be ignored so that NS records are
	not inadvertently deleted. (You can force deletion using an empty NS RRset.)

	Examples:

	# Copy records from domain1.example to domain2.example (needs to exist)
	\$ $0 domain2.example <( \\
	        curl -sS -H@- <<< "Authorization: Token \${TOKEN}" \\
	            https://desec.io/api/v1/domains/domain1.example/rrsets/ \\
	    )

	# Update the Public Suffix List zone (except NS RRset at zone apex)
	# Requires psl-dns_parse from https://pypi.org/project/psl-dns/
	\$ psl-dns_parse <(curl -sS https://publicsuffix.org/list/public_suffix_list.dat) \\
	    | $0 query.publicsuffix.zone -
EOM
    exit 1
fi

if [ -z "$TOKEN" ]; then
        echo 'Please set $TOKEN'
        exit 3
fi

# Check dependencies
if [ ! -x "$(which curl 2>/dev/null)" ]; then
  echo "please install: curl" >&2
  exit 2
fi

if [ ! -x "./rrsets_diff.sh" ]; then
  echo "please install: rrsets_diff.sh (https://github.com/desec-io/desec-tools/)" >&2
  exit 2
fi

if [ ! -x "./fetch_zone.py" ]; then
  echo "please install: fetch_zone.py (https://github.com/desec-io/desec-tools/)" >&2
  exit 2
fi


zone=$1
filename=$2

API_URL=https://desec.io/api/v1/domains/$zone/rrsets/
AUTH_HEADER="Authorization: Token ${TOKEN}"

timestamp=$(date +%Y-%m-%d_%H.%M.%S)

# curl --fail-with-body available since version 7.76 (released in 2021)
./rrsets_diff.sh <(./fetch_zone.py $zone) $filename \
| tee patch_zone.$timestamp.json \
| curl -sS --fail-with-body -X PATCH ${API_URL} -H@<(cat <<< "${AUTH_HEADER}") -H 'Content-Type: application/json' --data @-

