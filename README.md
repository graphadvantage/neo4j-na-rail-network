# neo4j-na-rail-network
## North American Rail Network in Neo4j + GDS + NeoDash

A small Neo4j Graph Data Science demo of shortest path route finding between railroad yards in the North American Rail Network (NARN).

Two networks are projected - the main lines network and the double stack network (for tall intermodal cars with doublestacked shipping containers). The double stack network avoid low bridges and tunnels that can only accommodate regular height trains.

The graph is composed of nodes and routes loaded in geojson format. The load script refactors the route nodes into relationships and also extracts the yards, owners and networks as entities for use in NeoDash parameters.

Download [North_American_Rail_Nodes.geojson](https://hub.arcgis.com/datasets/usdot::north-american-rail-network-nodes/explore)

Download [North_American_Rail_Lines.geojson](https://hub.arcgis.com/datasets/usdot::north-american-rail-network-lines/explore)

The NARN data dictionary


#### Build (for Neo4j 5)


1. in `neo4j.conf` settings uncomment `server.directories.import=import`

1. copy the `apoc.conf` file to /conf

1. copy data files to /import

1. run the queries in `load.cyp`

1. open NeoDash (latest) and import `dashboard.json`
