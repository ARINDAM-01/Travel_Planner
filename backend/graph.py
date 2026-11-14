"""Graph model for the travel planner.

Adjacency list: dict of city_id -> list of (neighbor_id, distance, cost, time).
"""

CRITERIA = {
            "distance": 1,
            "cost": 2,
            "time": 3
            }


class Graph:
    def __init__(self):
        # city_id -> list of (neighbor_id, distance_km, cost_inr, time_hr)
        self.adj = {}

    def add_city(self, city_id):
        """Make sure a city exists as a node (even with no routes)."""
        self.adj.setdefault(city_id, [])

    def add_edge(self, src, dst, distance, cost, time, bidirectional=False):
        """Add a route src -> dst. Set bidirectional=True to add dst -> src too.

        If you load from the v_edges view (which already has both directions),
        leave bidirectional=False, otherwise every edge is stored twice.
        """
        if distance <= 0 or time <= 0 or cost < 0:
            raise ValueError("distance and time must be > 0, cost must be >= 0")
        self.add_city(src)
        self.add_city(dst)
        self.adj[src].append((dst, float(distance), float(cost), float(time)))
        if bidirectional:
            self.adj[dst].append((src, float(distance), float(cost), float(time)))

    def neighbors(self, city_id):
        """Return the list of edges leaving city_id (empty list if unknown)."""
        return self.adj.get(city_id, [])

    @staticmethod
    def weight(edge, criterion):
        """Return the weight of an edge for 'distance', 'cost' or 'time'."""
        try:
            return edge[CRITERIA[criterion]]
        except KeyError:
            raise ValueError(
                f"Unknown criterion '{criterion}'. Use one of: {', '.join(CRITERIA)}"
            )

    def has_city(self, city_id):
        return city_id in self.adj

    def cities(self):
        return list(self.adj.keys())

    def edge_count(self):
        """Number of directed edges stored."""
        return sum(len(edges) for edges in self.adj.values())