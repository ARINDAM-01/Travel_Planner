"""Dijkstra's shortest path on the travel-planner Graph."""

import heapq
import math

from graph import CRITERIA


def dijkstra(graph, src, dst, criterion):
    """Return (path, total) from src to dst, or (None, inf) if unreachable.

    path is a list of city ids [src, ..., dst]; total is the sum of the chosen
    criterion ('distance', 'cost' or 'time') along that path.
    Raises ValueError for an unknown criterion or an unknown city id.
    """
    if criterion not in CRITERIA:
        raise ValueError(
            f"Unknown criterion '{criterion}'. Use one of: {', '.join(CRITERIA)}"
        )
    if not graph.has_city(src) or not graph.has_city(dst):
        raise ValueError("Unknown city id")

    best = {src: 0.0}        # best known total from src to each city
    prev = {}                # prev[v] = city we came from on the best path to v
    visited = set()          # cities whose best total is final
    heap = [(0.0, src)]      # min-heap of (total so far, city)

    while heap:
        d, u = heapq.heappop(heap)
        if u in visited:     # stale entry: u was already finalised with a better total
            continue
        visited.add(u)
        if u == dst:         # dst is final, no need to explore further
            break

        for edge in graph.neighbors(u):
            v = edge[0]
            if v in visited:
                continue
            nd = d + graph.weight(edge, criterion)
            if nd < best.get(v, math.inf):   # found a cheaper way to reach v
                best[v] = nd
                prev[v] = u
                heapq.heappush(heap, (nd, v))

    if dst not in visited:
        return None, math.inf

    path = [dst]
    while path[-1] != src:   # walk back from dst to src using prev
        path.append(prev[path[-1]])
    path.reverse()
    return path, best[dst]