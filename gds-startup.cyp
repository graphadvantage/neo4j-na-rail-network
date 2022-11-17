// for reference or manual execution.
// Are already included in apoc.conf to do projections on db startup

CALL apoc.warmup.run();

CALL gds.graph.project('main-lines-network', 'Node', {
  relType: {
    type: 'CONNECTS_MIO',
    orientation: 'UNDIRECTED',
    properties: {
      miles: {
        property: 'miles',
        defaultValue: 1
      }
    }
  }
}, {});

CALL gds.graph.project('double-stack-network', 'Node', {
  relType: {
    type: 'CONNECTS_DS',
    orientation: 'UNDIRECTED',
    properties: {
      miles: {
        property: 'miles',
        defaultValue: 1
      }
    }
  }
}, {});
