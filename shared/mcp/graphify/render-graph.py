#!/usr/bin/env python3
"""Render a graphify knowledge graph to a PNG (no browser needed).

Headless-friendly: reads <project>/graphify-out/graph.json and draws a
force-directed layout colored by community, sized by degree. Use this to "show"
the graph when no display/browser is available (e.g. on a remote/dev box).

Usage:
    render-graph.py <project_dir> [out.png]
    render-graph.py <graph.json> [out.png]

Env:
    GRAPHIFY_PY   python with networkx+matplotlib (default: auto-detect; the
                  financial-terminal venv has both). Set MPLCONFIGDIR to a
                  writable dir if ~/.config is read-only.
"""
import os, sys, json, glob

def pick_python():
    if os.environ.get("GRAPHIFY_PY"):
        return os.environ["GRAPHIFY_PY"]
    # Prefer a venv known to have networkx + matplotlib, then system python.
    candidates = [
        "/home/ai-dev/dev-team/projects/financial-terminal/.venv/bin/python",
        sys.executable,
        "/usr/bin/python3",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return "python3"

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    target = sys.argv[1]
    # Accept a graph.json directly or a project dir.
    if os.path.isfile(target) and target.endswith("graph.json"):
        graph_path = target
    else:
        graph_path = os.path.join(target, "graphify-out", "graph.json")
    if not os.path.isfile(graph_path):
        sys.exit(f"render-graph.py: graph.json not found at {graph_path}\n"
                 f"Build it first: cd <project> && ~/.local/bin/graphify update <project>")
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        os.path.dirname(graph_path), "graph-render.png")

    # Make matplotlib's config dir writable (read-only /home/ai-dev/.config).
    os.environ.setdefault("MPLCONFIGDIR", "/tmp/mplcache")
    os.makedirs(os.environ["MPLCONFIGDIR"], exist_ok=True)

    import subprocess, textwrap
    code = textwrap.dedent("""
        import os, json
        os.environ.setdefault("MPLCONFIGDIR", "/tmp/mplcache")
        os.makedirs(os.environ["MPLCONFIGDIR"], exist_ok=True)
        import matplotlib; matplotlib.use("Agg")
        import matplotlib.pyplot as plt, networkx as nx
        G = nx.node_link_graph(json.load(open(__graph_path__)), edges="links")
        pos = nx.spring_layout(G, seed=42)
        comm = {n: d.get("community", 0) for n, d in G.nodes(data=True)}
        cmap = plt.get_cmap("tab10"); nodes = list(G.nodes())
        colors = [cmap(comm[n] % 10) for n in nodes]
        sizes  = [300 + 6 * G.degree(n) for n in nodes]
        fig, ax = plt.subplots(figsize=(12, 10), dpi=120)
        nx.draw_networkx_nodes(G, pos, node_color=colors, node_size=sizes, alpha=.9, ax=ax)
        nx.draw_networkx_edges(G, pos, alpha=.35, ax=ax)
        labels = {n: (G.nodes[n].get("label") or str(n))[:24] for n in nodes}
        nx.draw_networkx_labels(G, pos, labels=labels, font_size=7, ax=ax)
        ax.set_title(f"Graphify: {len(G)} nodes, {G.number_of_edges()} edges (colored by community)",
                     fontsize=14)
        ax.set_axis_off()
        plt.tight_layout(); plt.savefig(__out__, bbox_inches="tight", facecolor="white")
        print(f"Rendered {len(G)} nodes, {G.number_of_edges()} edges -> {__out__}")
    """).replace("__graph_path__", json.dumps(graph_path)).replace("__out__", json.dumps(out))

    py = pick_python()
    r = subprocess.run([py, "-c", code], check=False)
    sys.exit(r.returncode)

if __name__ == "__main__":
    main()
