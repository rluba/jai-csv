# Tiny CSV module for Jai

This tiny module has just two primary functions:

* `csv_parse` parses a CSV string into an array of any given type.
* `csv_escape` escapes a value (if needed) so that it can be safely written in to a CSV column.

Currently, `csv_parse` can only parse into string, float, and integer members.

See [`module.jai`](./module.jai) for details.

## Memory model

You’re responsible for freeing everything (including strings) in the result array.
Using a Pool allocator around your `parse_csv` calls might be a good idea.
