# keycloak-image/tools

`cyber-topology.gen.awk` draws the login background artwork
(`themes/stooge/login/resources/img/cyber-topology.svg`): a jittered mesh of
nodes and links standing for a monitored network. It is deterministic, with no
`rand()`, so regenerating produces byte-identical output.

Regenerate after changing the node grid, jitter, or link threshold:

```
awk -f tools/cyber-topology.gen.awk > themes/stooge/login/resources/img/cyber-topology.svg
```

The beacon rings and the rotating sweep are NOT in the SVG. They are CSS in
`themes/stooge/login/resources/css/stooge.css`, anchored to the same point, so
the two stay aligned at any viewport aspect ratio.
