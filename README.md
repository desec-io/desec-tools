# Miscellaneous tools for the deSEC DNS platform
A loose collection of tools automating some routine DNS management tasks

## patch_zone.sh – Replace all RRsets in a domain

```
Usage: ./patch_zone.sh zone filename

Replace DNS records in `zone` with the ones given in `filename` by applying a
minimal diff. The file is expected to contain a JSON array of RRset objects as
described at https://desec.readthedocs.io/en/latest/#rrset-field-reference.
If the filename is equal to a dash -, it is mapped to stdin.

The script requires rrsets_diff.sh from https://github.com/desec-utils/tools/.
The $TOKEN environment variable is required to contain a deSEC API token.

Note: The NS RRset at the zone apex (no subdomain) is touched only if it is
contained in the file. Otherwise, it will be ignored so that NS records are
not inadvertently deleted. (You can force deletion using an empty NS RRset.)

Examples:

# Copy records from domain1.example to domain2.example (needs to exist)
$ ./patch_zone.sh domain2.example <( \
        curl -sS -H@- <<< "Authorization: Token ${TOKEN}" \
            https://desec.io/api/v1/domains/domain1.example/rrsets/ \
    )

# Update the Public Suffix List zone (except NS RRset at zone apex)
# Requires psl-dns_parse from https://pypi.org/project/psl-dns/
$ psl-dns_parse <(curl -sS https://publicsuffix.org/list/public_suffix_list.dat) \
    | ./patch_zone.sh query.publicsuffix.zone -
```

## rrsets_diff.sh – Compute diffs of RRset lists

```
Usage: ./rrsets_diff.sh oldfile newfile

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
$ ./rrsets_diff.sh \
    <(curl -sS https://desec.io/api/v1/domains/:domain/rrsets/ -H "Authorization: Token $TOKEN") \
    - <<< '[]'
```
