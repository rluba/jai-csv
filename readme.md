# Tiny CSV parser for Jai

This tiny module has just one primary function, `csv_parse`. It parses a CSV string into an array of any given type.

Currently, `csv_parse` can only parse into `string` members, but that’s rather easy to extend, if you need other types. (PRs welcome.)

See [`module.jai`](./module.jai) for details.

## Memory model

You’re responsible for freeing everything (including strings) in the result array.
Using a Pool allocator around your `execute` calls might be a good idea.
