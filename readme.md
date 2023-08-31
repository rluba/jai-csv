# Tiny CSV module for Jai

This tiny module has just three primary functions:

* `csv_parse` parses a CSV string into an array of any given type.
* `csv_escape` escapes a value (if needed) so that it can be safely written in to a CSV column.
* `append_csv_escaped` is similar to `csv_escape` but directly appends the (potentially escaped) value to a `String_Builder`.

Currently, `csv_parse` can only parse into string, float, and integer members.

See [`module.jai`](./module.jai) for details.

## Memory model

You’re responsible for freeing everything (including strings) in the result array returned by `csv_parse`.
Using a Pool allocator around your `csv_parse` calls might be a good idea.
