# Miscellaneous tools for the deSEC DNS platform
A loose collection of tools automating some routine DNS management tasks

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
