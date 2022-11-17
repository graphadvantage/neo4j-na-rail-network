//data loading scripts
//CALL apoc.load.json("nodesNA_test.geojson")
//CALL apoc.load.json('routesNA_test.geojson')

NARN data dictonary values (Node.net)
A	Abandoned
F	Ferry
I	Major industrial lead
M	Main lead
O	Non-Mainline Active track
R	Abandoned line that has been physically removed
S	Passing sidings
T	Trail on former rail right-of-way
X	Out of Service
Y	Yard Tracks
Z	Tourist, museum, or science passenger service

//load nodes
CALL apoc.periodic.iterate(
"
CALL apoc.load.json('North_American_Rail_Nodes.geojson') YIELD value
RETURN value
","
UNWIND value.features as m
WITH m.geometry.coordinates AS point,
apoc.map.clean(m.properties,[],[' ']) AS map
WITH point, map, keys(map) AS keys
WITH point, reduce(m = {}, k IN keys | apoc.map.setValues(m,[apoc.text.camelCase(k),map[k]])) AS map
CREATE (n:Node {objectid: map.objectid})
SET n+=map,
n.nodepoint = point({latitude: point[1], longitude: point[0]})
",{batchSize: 1000, parallel:true}) YIELD batches, total
RETURN batches, total;

//load routes
CALL apoc.periodic.iterate(
"
CALL apoc.load.json('North_American_Rail_Lines.geojson') YIELD value
RETURN value
","
UNWIND value.features AS m
WITH
head(head(m.geometry.coordinates)) AS start,
last(last(m.geometry.coordinates)) AS end,
reduce(p =[], i IN apoc.coll.flatten(m.geometry.coordinates) | p + [point({latitude: i[1], longitude: i[0]})]) AS polyline,
apoc.map.clean(m.properties,[],[' ']) AS map
WITH start, end, polyline, map, keys(map) AS keys
WITH start, end, polyline, reduce(m = {}, k IN keys | apoc.map.setValues(m,[apoc.text.camelCase(k),map[k]])) AS map
CREATE (n:Route {objectid: map.objectid})
SET n+=map,
n.startpoint = point({latitude: start[1], longitude: start[0]}),
n.endpoint = point({latitude: end[1], longitude: end[0]}),
n.polyline = polyline
",{batchSize: 1000, parallel:true}) YIELD batches, total
RETURN batches, total;

//Set an index to speed node search
CREATE RANGE INDEX FOR (n:Node) ON n.franodeid;

//Begin refactoring Route Nodes as Rels - map FROM using dynamic label
MATCH (r:Route)
SET r:ProcessMe;
CALL apoc.periodic.iterate(
"
MATCH (r:Route:ProcessMe)
RETURN r
","
MATCH (n:Node {franodeid: r.frfranode})
MERGE (n)<-[:FROM]-(r)
REMOVE r:ProcessMe
",{batchSize: 1000}) YIELD batches, total
RETURN batches, total;

//Begin refactoring Route Nodes as Rels - map TO using dynamic label
MATCH (r:Route)
SET r:ProcessMe;
CALL apoc.periodic.iterate(
"
MATCH (r:Route:ProcessMe)
RETURN r
","
MATCH (n:Node {franodeid: r.tofranode})
MERGE (n)<-[:TO]-(r)
REMOVE r:ProcessMe
",{batchSize: 1000}) YIELD batches, total
RETURN batches, total;

//Complete refactoring Route Nodes as Rels - map CONNECTS using dynamic label
MATCH (r:Route)
SET r:ProcessMe;
CALL apoc.periodic.iterate(
"
MATCH (f:Node)<-[:FROM]-(r:Route:ProcessMe)-[:TO]->(t:Node)
RETURN f,r,t
","
MERGE (f)-[c:CONNECTS {fraarcid: r.fraarcid}]->(t)
WITH r,c
SET c+=r
REMOVE r:ProcessMe
",{batchSize: 1000, iterateList:true}) YIELD batches, total
RETURN batches, total;

//Delete Route nodes since we no longer need them
CALL apoc.periodic.iterate(
"
MATCH (r:Route)
RETURN r
","
DETACH DELETE r
",{batchSize: 1000, iterateList:true}) YIELD batches, total
RETURN batches, total;

//Delete out of service track
MATCH ()-[r]-()
WHERE r.net IN ['A','R','T','X','Z']
DELETE r;

//pick up Main, Industrial and Active track
CALL apoc.periodic.iterate(
"
MATCH (n1:Node)-[c:CONNECTS]->(n2:Node)
WHERE c.net IS NOT NULL
AND c.net IN ['M','I','O']
AND NOT EXISTS((n1)-[:CONNECTS_MIO]-(n2))
RETURN n1,c,n2
","
MERGE (n1)-[c1:CONNECTS_MIO {fraarcid: c.fraarcid}]->(n2)
SET c1+=c
",{iterateList:true, batchSize: 1000}) YIELD batches, total
RETURN batches, total;

//Double Stack Routes
CALL apoc.periodic.iterate(
"
MATCH (n1:Node)-[c:CONNECTS]->(n2:Node)
WHERE c.imRtType = 'DS'
AND NOT EXISTS((n1)-[:CONNECTS_DS]-(n2))
RETURN n1,c,n2
","
MERGE (n1)-[c1:CONNECTS_DS {fraarcid: c.fraarcid}]->(n2)
SET c1+=c
",{iterateList:true, batchSize: 1000}) YIELD batches, total
RETURN batches, total;

//Make Yard Nodes
CALL apoc.periodic.iterate(
"
MATCH (n:Node)-[r:CONNECTS]-()
WHERE r.yardname IS NOT NULL
AND NOT ( (n)-[:HAS_YARD]->() )
RETURN n,r
","
MERGE (y:Yard {yardname: r.yardname, stcntyfips: r.stcntyfips})
SET
y.stateab = r.stateab,
y.stfips = r.stfips,
y.cntyfips=r.cntyfips,
y.yardnamestateab = y.yardname +' - ' + y.stateab
WITH n,y
MERGE (n)-[:HAS_YARD]->(y)
",{batchSize: 1000}) YIELD batches, total
RETURN batches, total;

//Searchable index for NeoDash
CREATE TEXT INDEX FOR (n:Yard) ON n.yardnamestateab;

//Determine Yard Ownership
MATCH (y:Yard)<-[:HAS_YARD]-(n:Node)-[r:CONNECTS]-()
WITH y, apoc.convert.toSet(COLLECT(DISTINCT r.rrowner1)+COLLECT(DISTINCT r.rrowner2)+COLLECT(DISTINCT r.rrowner3)) as rrowners
SET y.rrowners=rrowners;

//Create Owner
MATCH (y:Yard)
WITH apoc.convert.toSet(apoc.coll.flatten(COLLECT(y.rrowners))) AS owners
UNWIND owners AS owner
MERGE (n:Owner {rrowner: owner});

//Set Yard centroid for plotting by first computing midpoints for yard routes
MATCH (y:Yard)<-[:HAS_YARD]-(n:Node)-[r:CONNECTS]-()
WHERE y.yardname = r.yardname
WITH DISTINCT y,r,(r.startpoint.x+r.endpoint.x)/2.0 AS midx, (r.startpoint.y+r.endpoint.y)/2.0 AS midy
WITH y, AVG(midx) AS centroidx, AVG(midy) AS centroidy
SET
y.centroid = point({latitude:centroidy, longitude:centroidx}),
y.lat = centroidy,
y.lng = centroidx,
y:Node;

//Connect Yards to Nodes networks
CALL apoc.periodic.iterate(
"
MATCH (y:Yard)
WHERE NOT (y)-[:CONNECTS]-()
WITH y
MATCH (y)<-[:HAS_YARD]-(n:Node)-[r1*1]-()
RETURN y, apoc.coll.toSet(COLLECT(TYPE(r1[0]))) AS rels, COLLECT(n) AS nodes
","
UNWIND nodes as n
UNWIND rels AS relType
WITH y,n,relType
CAll apoc.merge.relationship(y,relType,{miles:0.0,km:0.0},{},n,{}) YIELD rel
RETURN rel
",{iterateList:true, batchSize: 1000}) YIELD batches, total
RETURN batches, total;

//Add gds projections as nodes for NeoDash parameters
CALL gds.graph.list() YIELD graphName
WITH COLLECT(graphName) as graphs
UNWIND graphs as graphName
MERGE (n:Network {network: graphName});


//** DANGER ZONE ** The DS Network seems like it has missing data, here we are inferring from network neighbors to complete the paths
// Missing DS segments on main lines
MATCH path = (n:Node)-[:CONNECTS_DS]-(n1:Node)-[r:CONNECTS]-(n2:Node)-[:CONNECTS_DS]-(n3)
WHERE  NOT (n1)-[:CONNECTS_DS]-(n2) AND NOT (n:Yard OR n1:Yard OR n2:Yard OR n3:Yard)
WITH n1,n2,r
MERGE (n1)-[c:CONNECTS_DS]->(n2)
SET c+=r, c.imRtType = "DS-INFERRED"

//** DANGER ZONE ** The DS Network seems like it has missing data, here we are inferring from network neighbors to complete the paths
// Missing DS segments near Yards
MATCH path = (n:Node)-[:CONNECTS_DS]-(n1:Node)-[r:CONNECTS]-(n2:Node)-[:CONNECTS_DS]-(n3)
WHERE (n:Yard OR n1:Yard OR n2:Yard OR n3:Yard) AND NOT (n1)-[:CONNECTS_DS]-(n2)
WITH n1,n2,r
MERGE (n1)-[c:CONNECTS_DS]->(n2)
SET c+=r, c.imRtType = "DS-INFERRED"
