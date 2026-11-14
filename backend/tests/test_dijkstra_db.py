"""Dijkstra tests that run against the real MySQL database (no hardcoded graph).

Every expected value is computed independently inside the test (a Bellman-Ford
reference implementation), so the tests keep working if you edit the seed data.
Connection settings come from db.py (env vars / .env).
"""

import itertools
import math

import pytest

from algorithms.dijkstra import dijkstra
from db import get_cities, load_graph
from graph import Graph

CRITERIA = ["distance", "cost", "time"]


@pytest.fixture(scope="module")
def graph():
    try:
        return load_graph()
    except Exception as e:  # connection / auth / missing view
        pytest.fail(f"Could not load the graph from MySQL: {e}")


@pytest.fixture(scope="module")
def city_ids():
    return {c["name"]: c["id"] for c in get_cities()}


def bellman_ford(graph, src, criterion):
    """Independent reference: shortest totals from src to every city."""
    dist = {c: math.inf for c in graph.cities()}
    dist[src] = 0.0
    for _ in range(len(dist) - 1):
        changed = False
        for u in graph.cities():
            if dist[u] == math.inf:
                continue
            for edge in graph.neighbors(u):
                nd = dist[u] + graph.weight(edge, criterion)
                if nd < dist[edge[0]]:
                    dist[edge[0]] = nd
                    changed = True
        if not changed:
            break
    return dist


def cheapest_hop(graph, u, v, criterion):
    """Smallest weight among all edges u -> v (road and flight can both exist)."""
    weights = [graph.weight(e, criterion) for e in graph.neighbors(u) if e[0] == v]
    return min(weights) if weights else None


def test_graph_loaded(graph):
    assert len(graph.cities()) > 0
    assert graph.edge_count() > 0
    assert graph.edge_count() % 2 == 0  # v_edges stores both directions


@pytest.mark.parametrize("criterion", CRITERIA)
def test_matches_bellman_ford_for_all_pairs(graph, criterion):
    for src in graph.cities():
        reference = bellman_ford(graph, src, criterion)
        for dst in graph.cities():
            path, total = dijkstra(graph, src, dst, criterion)
            if reference[dst] == math.inf:
                assert path is None and total == math.inf
            else:
                assert total == pytest.approx(reference[dst]), (src, dst, criterion)


@pytest.mark.parametrize("criterion", CRITERIA)
def test_returned_path_is_valid(graph, criterion):
    for src, dst in itertools.permutations(graph.cities(), 2):
        path, total = dijkstra(graph, src, dst, criterion)
        if path is None:
            continue
        assert path[0] == src and path[-1] == dst
        assert len(path) == len(set(path)), "path repeats a city"
        hops = [cheapest_hop(graph, a, b, criterion) for a, b in zip(path, path[1:])]
        assert None not in hops, f"path uses a non-existent edge: {path}"
        assert sum(hops) == pytest.approx(total)


@pytest.mark.parametrize("criterion", CRITERIA)
def test_total_is_symmetric(graph, criterion):
    # every route is stored in both directions, so a->b must equal b->a
    for a, b in itertools.combinations(graph.cities(), 2):
        _, t1 = dijkstra(graph, a, b, criterion)
        _, t2 = dijkstra(graph, b, a, criterion)
        assert t1 == pytest.approx(t2)


@pytest.mark.parametrize("criterion", CRITERIA)
def test_src_equals_dst(graph, criterion):
    for c in graph.cities():
        assert dijkstra(graph, c, c, criterion) == ([c], 0.0)


@pytest.mark.parametrize("criterion", CRITERIA)
def test_never_worse_than_a_direct_edge(graph, criterion):
    for u in graph.cities():
        for edge in graph.neighbors(u):
            _, total = dijkstra(graph, u, edge[0], criterion)
            assert total <= graph.weight(edge, criterion) + 1e-9


def test_known_cities_are_reachable(graph, city_ids):
    path, total = dijkstra(graph, city_ids["Kolkata"], city_ids["Delhi"], "cost")
    assert path is not None and total < math.inf


def test_criterion_can_change_the_route(graph):
    """Flights make cost and time disagree somewhere in the seed data."""
    differs = False
    for src, dst in itertools.permutations(graph.cities(), 2):
        p_cost, _ = dijkstra(graph, src, dst, "cost")
        p_time, _ = dijkstra(graph, src, dst, "time")
        if p_cost != p_time:
            differs = True
            break
    assert differs, "cost and time gave identical routes for every pair"


def test_isolated_city_is_unreachable(graph, city_ids):
    """Copy the graph without Port Blair's routes and check it is cut off."""
    island = city_ids["Port Blair"]
    cut = Graph()
    for c in graph.cities():
        cut.add_city(c)
    for u in graph.cities():
        for v, dist, cost, time in graph.neighbors(u):
            if u != island and v != island:
                cut.add_edge(u, v, dist, cost, time)
    path, total = dijkstra(cut, city_ids["Kolkata"], island, "distance")
    assert path is None and total == math.inf


def test_unknown_city_and_criterion(graph):
    some = graph.cities()[0]
    with pytest.raises(ValueError):
        dijkstra(graph, some, max(graph.cities()) + 1000, "cost")
    with pytest.raises(ValueError):
        dijkstra(graph, some, some, "comfort")