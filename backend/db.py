"""MySQL access for the travel planner.

Reads connection settings from environment variables so passwords stay out of Git.
Defaults match a local MySQL install; override with e.g.
    export DB_PASSWORD=yourpassword
"""

import os

import mysql.connector

from graph import Graph


def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "travel_planner"),
    )


def get_cities():
    """Return all cities as [{id, name, lat, lng}, ...]."""
    conn = get_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("SELECT id, name, lat, lng FROM cities ORDER BY name")
        rows = cur.fetchall()
    finally:
        conn.close()
    # DECIMAL columns come back as Decimal; convert so JSON serialization is clean
    return [
        {"id": r["id"], "name": r["name"], "lat": float(r["lat"]), "lng": float(r["lng"])}
        for r in rows
    ]


def load_graph():
    """Build a Graph from the v_edges view.

    v_edges already contains every route in both directions, so edges are
    added with bidirectional=False. Every city is added as a node first so
    isolated cities (like Port Blair without its flight) still exist.
    """
    graph = Graph()
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT id FROM cities")
        for (city_id,) in cur.fetchall():
            graph.add_city(city_id)

        cur.execute(
            "SELECT src, dst, mode, distance_km, cost_inr, time_hr FROM v_edges"
        )
        for src, dst, mode, distance, cost, time in cur.fetchall():
            graph.add_edge(src, dst, float(distance), float(cost), float(time))
    finally:
        conn.close()
    return graph


if __name__ == "__main__":
    # Quick check: run `python db.py`
    g = load_graph()
    print("cities:", len(g.cities()))          # expect 26
    print("directed edges:", g.edge_count())   # expect 90