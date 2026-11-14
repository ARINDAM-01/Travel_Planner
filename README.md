# Travel_Planner

# Graph-Based Travel Planner: 2-Day Build Plan (3 people + Claude)

**Stack:** MySQL 8 (use `travel_planner.sql`) + Python FastAPI + HTML/JS with Leaflet
**Team:** Lead (integration + API), A (algorithms), B (frontend + data)
**Rule:** Claude writes the first draft, a human reads it, runs it, and only then merges. Everyone must be able to explain their algorithm at the viva.

---

## Before you start (30 min, all three together)

1. Install: Python 3.11+, MySQL 8, Git, VS Code. Run `pip install fastapi uvicorn mysql-connector-python pytest`.
2. Lead creates a GitHub repo and invites A and B. Branches: `lead`, `algo`, `frontend`. Nobody commits to `main` directly.
3. Run `travel_planner.sql` once on every laptop so all three have the same database.
4. Agree on this folder layout:

```
travel-planner/
  backend/
    main.py            # FastAPI routes
    db.py              # MySQL connection + load_graph()
    graph.py           # Graph class
    algorithms/
      dijkstra.py
      traversal.py     # BFS, DFS, components
      kruskal.py
      tsp.py
    tests/
  frontend/
    index.html
    app.js
    style.css
  README.md
```

5. Agree on the API contract (do not change it without telling the others):
   - `GET /cities` returns `[{id, name, lat, lng}]`
   - `GET /route?src=1&dst=14&criterion=cost` returns `{path:[ids], total:number, criterion:"cost"}`
   - `GET /reachable?src=1&dst=26` returns `{reachable:true|false}`
   - `POST /trip` with `{stops:[ids], criterion}` returns `{order:[ids], total:number}`
   - `GET /mst?criterion=distance` returns `{edges:[[a,b],...], total:number}`

---

## DAY 1: Core graph + shortest route + map (about 9 hours)

### Block 1 (hours 0-2): Foundations in parallel

**Lead: `db.py` and `graph.py`**
1. Ask Claude: *"Write graph.py with a Graph class using an adjacency list: dict of city_id -> list of (neighbor_id, distance, cost, time). Methods: add_edge, neighbors(id), weight(edge, criterion). Criterion is 'distance', 'cost' or 'time'."*
2. Ask Claude: *"Write db.py with load_graph() that reads the v_edges view from MySQL (columns src, dst, mode, distance_km, cost_inr, time_hr) and returns a Graph, plus get_cities()."*
3. Run it and print the number of edges. It must be **90**. Fix the connection settings if not.
4. Push to `lead`. Tell A and B on the group chat: "Graph interface is ready, pull it."

**A: `dijkstra.py`** (works against the interface above; use a fake 4-node graph until the Lead pushes)
1. Ask Claude: *"Write dijkstra(graph, src, dst, criterion) using heapq. Return (path_list, total) or (None, inf) if unreachable. Explain each line."* Read the explanation. You need it for the viva.
2. Ask Claude for pytest tests: normal path, src == dst, unreachable node, two equal-cost paths.
3. Run `pytest`. Fix failures by pasting the traceback to Claude.

**B: dataset check + map shell**
1. Check the seed data: open 5 routes from the SQL file and compare with Google Maps. Note any big errors for the Lead to fix in the SQL.
2. Ask Claude: *"Write index.html + app.js that shows a Leaflet map of India, fetches /cities, draws a marker per city with its name, and fills two dropdowns (source, destination) plus a criterion selector (distance, cost, time) and a Find Route button."*
3. Use hard-coded fake city data until the API exists.

### Block 2 (hours 2-4): First API + traversal

**Lead: `main.py`**
1. Ask Claude: *"Write FastAPI main.py with CORS enabled, loading the graph at startup. Endpoints: GET /cities and GET /route that calls dijkstra."*
2. Run `uvicorn main:app --reload` and open `/docs`. Test `/route?src=1&dst=14&criterion=cost` in the browser.
3. Tell B the API is live on `localhost:8000`.

**A: `traversal.py`**
1. Ask Claude: *"Write bfs_reachable(graph, src, dst), dfs_component(graph, src), and connected_components(graph)."*
2. Tests: Kolkata to Delhi is reachable, and Port Blair is isolated if the Chennai flight is removed.
3. Give the Lead the function names so `/reachable` can be wired.

**B: connect map to API**
1. Replace fake data with `fetch('http://localhost:8000/cities')`.
2. Ask Claude: *"On Find Route click, call /route and draw the returned path as a highlighted polyline through the city coordinates. Show the total in a result box with units (km, INR or hours)."*

### Block 3 (hours 4-6): MST + error handling

**A: `kruskal.py`**
1. Ask Claude: *"Write a UnionFind class with path compression and union by rank, then kruskal(graph, criterion) returning (edge_list, total)."*
2. Check by hand on a 4-node example. The total must match what you compute on paper.

**Lead:**
1. Add `/reachable` and `/mst` endpoints.
2. Ask Claude to add proper errors: unknown city id returns 404, unreachable returns a clear message, bad criterion returns 422.

**B:**
1. Show friendly error messages in the UI (not raw JSON).
2. Add a "Check reachable" button and show Yes/No.

### Block 4 (hours 6-8): Integration

1. Everyone pushes to their branch. Lead merges `algo` and `frontend` into `main`, one at a time, and runs the app.
2. Whole team tests together: five random city pairs, on all three criteria. Write bugs in a shared list.
3. Fix the top bugs. Anything cosmetic goes to Day 2.

### Block 5 (hour 8-9): Day 1 checkpoint (must pass)
- [ ] Pick two cities, choose a criterion, get a path drawn on the map
- [ ] Unreachable and invalid input show clear messages
- [ ] `pytest` passes for Dijkstra, traversal and Kruskal
- [ ] `main` branch runs on all three laptops

If any box is unchecked, fix it first tomorrow morning before touching new features.

---

## DAY 2: Multi-stop trip + comparison + report (about 9 hours)

### Block 1 (hours 0-3): TSP / multi-stop

**A: `tsp.py`**
1. First compute the shortest-path distance between every pair of selected stops using Dijkstra (this builds the small complete graph).
2. Ask Claude: *"Write tsp_dp(dist_matrix) using bitmask DP that returns the best order and total cost. Also write tsp_nearest_neighbour(dist_matrix) and tsp_brute_force(dist_matrix) for comparison."*
3. Tests: with 4 stops all three must give the same total. With 8 stops, DP and brute force must match. Nearest-neighbour may be worse, and that is expected.
4. Cap DP at about 13 stops, and fall back to nearest-neighbour beyond that.

**Lead:**
1. Add `POST /trip`: take the stop ids, build the distance matrix via Dijkstra, call TSP, and return the order plus the full expanded path.
2. Save the trip into `trips` and `trip_stops`.

**B:**
1. Multi-select to add up to 8 stops, with a Plan Trip button.
2. Draw the whole tour with numbered markers (1, 2, 3...) and show the total.

### Block 2 (hours 3-5): Measurements for the report

**A:**
1. Ask Claude: *"Write a benchmark script that times brute force, bitmask DP and nearest-neighbour for 5, 8, 10, 12 stops on random subsets and prints a table."*
2. Run it. Paste the table into the report (it becomes your complexity comparison).

**Lead:**
1. Write the README: setup steps, how to run, API list.
2. Start the report outline (below).

**B:**
1. Add an MST view: draw the MST edges in a different colour and show the total.
2. Responsive cleanup: it must look fine on a projector.

### Block 3 (hours 5-7): Stretch goals (only if everything above works)
Pick one, in this order:
1. **Yen's k-shortest paths** (A): show the top 3 alternatives in the UI.
2. **Dijkstra step animation** (B): highlight nodes in the order they are visited.
3. **Mode filter** (Lead): checkbox to allow or exclude flights.

### Block 4 (hours 7-9): Final testing and report

1. **Edge-case test pass (all three):**
   - src == dst
   - Unreachable city (Port Blair with the flight route removed)
   - Single-stop and two-stop trips
   - Duplicate stops in a trip
   - Very long trip (should trigger the heuristic fallback)
2. **Report** (ask Claude to turn your notes and the benchmark table into prose, then edit it in your own words):
   - Problem statement and motivation
   - Graph model (nodes, edges, weights)
   - Data structures used and why: adjacency list, min-heap, Union-Find, bitmask table, hash map
   - Algorithms with time complexity: Dijkstra O((V+E) log V), BFS/DFS O(V+E), Kruskal O(E log E), TSP DP O(n^2 * 2^n)
   - Benchmark table and discussion
   - Screenshots, test cases, limitations, future work
3. **Rehearse the demo (15 min):** one path, one unreachable case, one 6-stop trip, one MST. Each person explains their own module.

---

## Working rules with Claude

- One chat per module, so context stays clean. Start each with the contract and the `Graph` interface.
- Always ask Claude to **explain** the code, not just write it, and ask "what is the time complexity and why?"
- When something fails, paste the full error plus the function that raised it.
- Never merge code you have not run and tested.
- Commit often: small commits after each working step so you can roll back.

## If you fall behind
Drop in this order: Dijkstra animation, Yen's, MST view, mode filter. **Never drop:** Dijkstra, reachability, TSP, tests, the report.
