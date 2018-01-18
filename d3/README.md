# d3 directory

This is where I worked on getting the live-updating demo from d3-flame-graph to work:

https://github.com/spiermar/d3-flame-graph

Not much here -- a modified demo javascript and an example (different) JSON file.

Used jq to combine multiple files:

```
jq 'with_entries(.key |= (. | tostring)) /var/www/html/perf-tests/1513826211-21432/*json
```

