# neo4j-na-rail-network
## North American Rail Network Pathfinding
### with Neo4j 5 + GDS 2.2.3 + NeoDash 2.2.0

#### Summary

A small Neo4j Graph Data Science demo of shortest path route finding between railroad yards in the North American Rail Network (NARN).

Two networks are projected - the main lines network and the double stack network (for tall intermodal cars with double-stacked shipping containers). The double stack network avoids low bridges and tunnels that can only accommodate regular height trains.

The graph is composed of nodes and routes loaded from geojson formatted files. The load script refactors the route nodes into relationships and also extracts the yards, owners and networks as entities for use as NeoDash parameters.

The NARN data dictionary is included in the repo for reference.

#### PreReqs

1. [Neo4j Desktop](https://neo4j.com/download)

1. Install Neo4j Enterprise Edition 5.1

1. Install APOC plugin from the Desktop

1. Install GDS plugin from the Desktop

1. Open database settings (DBMS /conf `neo4j.conf`):

  * uncomment `server.directories.import=import`

  * configure `server.memory.heap.initial_size=6g`

  * configure `server.memory.heap.max_size=6g`

  * configure `server.memory.pagecache.size=2g`

1. Open the DBMS folder, copy the `apoc.conf` file to /conf

1. Restart Neo4j

#### Build (for Neo4j 5)

1. download and copy data files to DBMS /import folder

  * Download [North_American_Rail_Nodes.geojson](https://hub.arcgis.com/datasets/usdot::north-american-rail-network-nodes/explore)

  * Download [North_American_Rail_Lines.geojson](https://hub.arcgis.com/datasets/usdot::north-american-rail-network-lines/explore)


1. run the queries in `load.cyp`

1. open NeoDash (latest) and import `dashboard.json`

Final database size will be ~600MB.

Note that the `apoc.conf` file includes `apoc.initialize` statements to create graph projections on db start up.  These will fail until the graph database is built completely.  Once the graph is fully built, you can restart the db and the projections will generate automatically.  You can view these steps occurring in neo4j.log during startup.

If you don't like this behavior, you can always comment out the `apoc.initialize` commands and manually run the code in `gds-startup.cyp`.

#### NeoDash

The dashboard includes several reports.  Try using the 'main-lines-network' and 'TOLEDO MEGA TERMINAL - OH' and 'GENTILLY - LA' for start and end yards.

You can use 'NS' (Norfolk Southern) as the railroad owner. Also try the 'double-stack-network' to see longer, more expensive routes with different trackage ownerships.

NeoDash:

![NeoDash](narn-image.png)

#### Installing and Editing NeoDash
NeoDash is in Neo4j Desktop GraphApps sidebar menu.
If you don't see it there, you can install it from the Graph Apps Gallery.
If you want to edit the dashboard components, open up the NeoDash settings in the sidebar and turn off presentation mode.
