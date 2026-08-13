"""
Phi_3: Canonical labeling via iterative partition refinement.

BLOCKERS FIXED:
  1. No runtime hash() — structural tuples only (deterministic across processes)
  2. Synchronous refinement — all reads from color_prev (iteration-k guaranteed)
  3. Canonical SCC ordering via structural signatures, not Tarjan IDs
  4. Tarjan SCC IDs discarded after partition computation

Freeze gate: numerical hypothesis absent from all precomparison canonicalization stages.
"""

import copy
from typing import Tuple, Dict, List, Any


# ---------------------------------------------------------------------------
# Type stubs (replace with your actual Representation class)
# ---------------------------------------------------------------------------

class Vertex:
    def __init__(self, op_type, parameters, canonical_label=None, scc_internal_rank=None):
        self.op_type = op_type
        self.parameters = parameters
        self.canonical_label = canonical_label
        self.scc_internal_rank = scc_internal_rank


class Representation:
    def __init__(self):
        self.vertices: Dict[int, Vertex] = {}
        self.edges: List[Tuple[int, int]] = []


# ---------------------------------------------------------------------------
# Graph helpers
# ---------------------------------------------------------------------------

def predecessors(R: Representation, v: int) -> List[int]:
    return [u for (u, w) in R.edges if w == v]

def successors(R: Representation, v: int) -> List[int]:
    return [w for (u, w) in R.edges if u == v]

def in_degree(R: Representation, v: int) -> int:
    return len(predecessors(R, v))

def out_degree(R: Representation, v: int) -> int:
    return len(successors(R, v))

def edges(R: Representation):
    return R.edges


# ---------------------------------------------------------------------------
# Tarjan SCC (used only to compute the partition; IDs are discarded)
# ---------------------------------------------------------------------------

def tarjan_sccs(R: Representation) -> List[List[int]]:
    index_counter = [0]
    stack = []
    lowlinks = {}
    index = {}
    on_stack = {}
    sccs = []

    def strongconnect(v):
        index[v] = index_counter[0]
        lowlinks[v] = index_counter[0]
        index_counter[0] += 1
        stack.append(v)
        on_stack[v] = True

        for w in successors(R, v):
            if w not in index:
                strongconnect(w)
                lowlinks[v] = min(lowlinks[v], lowlinks[w])
            elif on_stack.get(w, False):
                lowlinks[v] = min(lowlinks[v], index[w])

        if lowlinks[v] == index[v]:
            scc = []
            while True:
                w = stack.pop()
                on_stack[w] = False
                scc.append(w)
                if w == v:
                    break
            sccs.append(scc)

    for v in R.vertices:
        if v not in index:
            strongconnect(v)

    return sccs


# ---------------------------------------------------------------------------
# Condensation DAG helpers
# ---------------------------------------------------------------------------

def build_condensation_dag(R: Representation, sccs: List[List[int]]) -> Dict:
    node_to_scc = {}
    for scc_id, scc in enumerate(sccs):
        for v in scc:
            node_to_scc[v] = scc_id

    condensation = {i: {"predecessors": set(), "successors": set()} for i in range(len(sccs))}
    for (u, v) in R.edges:
        su, sv = node_to_scc[u], node_to_scc[v]
        if su != sv:
            condensation[su]["successors"].add(sv)
            condensation[sv]["predecessors"].add(su)

    return condensation


def predecessors_in_condensation(condensation: Dict, scc_id: int) -> set:
    return condensation[scc_id]["predecessors"]


# ---------------------------------------------------------------------------
# Main canonicalization function
# ---------------------------------------------------------------------------

def Phi_3_canonical(R: Representation) -> Tuple[Representation, str]:
    """
    Canonical labeling via iterative partition refinement.

    Returns (R_labeled, status) where status is:
      "RESOLVED"                   — canonical labeling assigned
      "UNRESOLVED_AUTOMORPHISM"    — structurally identical nodes; halt
      "ERROR_CYCLE_IN_CONDENSATION"— internal error (should not occur)
    """
    sccs = tarjan_sccs(R)
    condensation = build_condensation_dag(R, sccs)
    scc_set = [set(scc) for scc in sccs]

    # =========================================================================
    # STEP 1: Refine partition within each SCC
    # =========================================================================

    for scc_id, scc in enumerate(sccs):
        scc_nodes = set(scc)

        # Base color: structural tuple, no hash()
        color = {}
        for v in scc:
            color[v] = (
                R.vertices[v].op_type,
                tuple(sorted(R.vertices[v].parameters.items())),
                in_degree(R, v),
                out_degree(R, v),
            )

        # Iterative refinement — synchronous: all reads from color_prev
        max_iterations = len(scc) + 10
        for _ in range(max_iterations):
            color_prev = color
            color = {}

            for v in scc:
                preds_colors = tuple(sorted([
                    color_prev[u]
                    for u in predecessors(R, v) if u in scc_nodes
                ]))
                succs_colors = tuple(sorted([
                    color_prev[w]
                    for w in successors(R, v) if w in scc_nodes
                ]))
                # Structural tuple — NOT hash()
                color[v] = (color_prev[v], preds_colors, succs_colors)

            if color == color_prev:
                break

        # Rank distinct signatures lexicographically — deterministic, no hashing
        distinct_sigs = sorted(set(color.values()))
        sig_to_rank = {sig: rank for rank, sig in enumerate(distinct_sigs)}

        # Detect unresolved automorphisms
        rank_to_nodes: Dict[int, List[int]] = {}
        for v in scc:
            rank = sig_to_rank[color[v]]
            rank_to_nodes.setdefault(rank, []).append(v)

        for rank, nodes in rank_to_nodes.items():
            if len(nodes) > 1:
                return R, "UNRESOLVED_AUTOMORPHISM"

        for v in scc:
            R.vertices[v].scc_internal_rank = sig_to_rank[color[v]]

    # =========================================================================
    # STEP 2: Build structural signatures for each SCC
    # Tarjan IDs are discarded here; identity is based purely on structure.
    # =========================================================================

    scc_sigs = {}
    for scc_id, scc in enumerate(sccs):
        scc_nodes = set(scc)

        node_ranks = tuple(sorted([
            R.vertices[v].scc_internal_rank for v in scc
        ]))

        internal_edges = tuple(sorted([
            (R.vertices[u].scc_internal_rank, R.vertices[v].scc_internal_rank)
            for (u, v) in edges(R) if u in scc_nodes and v in scc_nodes
        ]))

        incoming = tuple(sorted([
            R.vertices[u].scc_internal_rank
            for u in scc
            for v in successors(R, u)
            if v not in scc_nodes
        ]))

        outgoing = tuple(sorted([
            R.vertices[v].scc_internal_rank
            for v in scc
            for u in predecessors(R, v)
            if u not in scc_nodes
        ]))

        scc_sigs[scc_id] = (node_ranks, internal_edges, incoming, outgoing)

    # =========================================================================
    # STEP 3: Canonical topological order of condensation DAG
    # Selection is by structural signature — not by SCC ID or insertion order.
    # =========================================================================

    processed_sccs: set = set()
    scc_canonical_order = []

    for _ in range(len(sccs)):
        available = [
            scc_id for scc_id in range(len(sccs))
            if scc_id not in processed_sccs
            and all(
                pred_id in processed_sccs
                for pred_id in predecessors_in_condensation(condensation, scc_id)
            )
        ]

        if not available:
            return R, "ERROR_CYCLE_IN_CONDENSATION"

        available_sigs = sorted([(scc_sigs[scc_id], scc_id) for scc_id in available])

        # Unresolved tie at same topological level → HALT
        if len(available_sigs) > 1 and available_sigs[0][0] == available_sigs[1][0]:
            return R, "UNRESOLVED_AUTOMORPHISM"

        best_scc_id = available_sigs[0][1]
        scc_canonical_order.append(best_scc_id)
        processed_sccs.add(best_scc_id)

    # =========================================================================
    # STEP 4: Assign canonical labels in order
    # =========================================================================

    R_labeled = copy.deepcopy(R)
    global_label = 0

    for scc_id in scc_canonical_order:
        scc = sccs[scc_id]
        for v in sorted(scc, key=lambda x: R.vertices[x].scc_internal_rank):
            R_labeled.vertices[v].canonical_label = global_label
            global_label += 1

    return R_labeled, "RESOLVED"
