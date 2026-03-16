#!/usr/bin/env python3
# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Gianluca Bellocchi <gianluca.bellocchi@unimore.it>

"""Validate inter-flow traffic YAML files for structural consistency.

This checker combines:
- Generic schema/sanity checks (critical count, rw consistency, duplicates, bursts).
- h-series checks for files named rt_inter_flow_<N>h.yml.
"""

from __future__ import annotations

import argparse
import colorsys
import glob
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Sequence, Set, Tuple

import yaml


Coord = Tuple[int, int]
Link = Tuple[Coord, Coord]


@dataclass
class Flow:
    name: str
    initiator: Coord
    endpoint: Coord
    rw: str
    narrow_number: int
    narrow_length: int
    wide_number: int
    wide_length: int

    @property
    def active(self) -> bool:
        return self.wide_number > 0 or self.narrow_number > 0


@dataclass
class ConflictPortion:
    flow_index: int
    initiator: Coord
    endpoint: Coord
    shared_nodes: List[Coord]
    shared_links: List[Link]

    @property
    def conflicts(self) -> bool:
        return bool(self.shared_nodes or self.shared_links)


def xy_route_nodes(src: Coord, dst: Coord) -> List[Coord]:
    """Return the XY route as an ordered list of visited routers (inclusive)."""
    x0, y0 = src
    x1, y1 = dst

    nodes: List[Coord] = [(x0, y0)]

    # First move on X while keeping Y fixed.
    if x1 != x0:
        step_x = 1 if x1 > x0 else -1
        for x in range(x0 + step_x, x1 + step_x, step_x):
            nodes.append((x, y0))

    # Then move on Y while keeping X fixed at destination X.
    if y1 != y0:
        step_y = 1 if y1 > y0 else -1
        for y in range(y0 + step_y, y1 + step_y, step_y):
            nodes.append((x1, y))

    return nodes


def route_links(nodes: Sequence[Coord]) -> Set[Link]:
    links: Set[Link] = set()
    for i in range(len(nodes) - 1):
        links.add((nodes[i], nodes[i + 1]))
    return links


def canonical_link(link: Link) -> Link:
    """Convert a directed link to an undirected canonical representation."""
    a, b = link
    if a <= b:
        return a, b
    return b, a


def collect_xy_conflicts(flows: Sequence[Flow]) -> Tuple[List[str], List[ConflictPortion], List[Coord], Set[Link]]:
    """Collect overlap portions between active interferers and critical XY route."""
    issues: List[str] = []
    portions: List[ConflictPortion] = []

    critical = [f for f in flows if f.name == "critical"]
    if len(critical) != 1:
        return issues, portions, [], set()

    crit = critical[0]
    crit_nodes_ordered = xy_route_nodes(crit.initiator, crit.endpoint)
    crit_nodes = set(crit_nodes_ordered)
    crit_links = {canonical_link(link) for link in route_links(crit_nodes_ordered)}

    if crit.initiator in crit_nodes:
        crit_nodes.remove(crit.initiator)

    for i, flow in enumerate(flows):
        if flow.name == "critical" or not flow.active:
            continue

        nodes = xy_route_nodes(flow.initiator, flow.endpoint)
        links = {canonical_link(link) for link in route_links(nodes)}

        shared_nodes = sorted(set(nodes) & crit_nodes)
        shared_links = sorted(links & crit_links)
        portions.append(
            ConflictPortion(
                flow_index=i,
                initiator=flow.initiator,
                endpoint=flow.endpoint,
                shared_nodes=shared_nodes,
                shared_links=shared_links,
            )
        )

        if not shared_nodes and not shared_links:
            issues.append(
                "flow[{}] initiator {} -> endpoint {} does not overlap the critical XY path".format(
                    i, flow.initiator, flow.endpoint
                )
            )

    return issues, portions, crit_nodes_ordered, crit_links


def _as_coord(value: Any, field_name: str) -> Coord:
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f"{field_name} must be a list of length 2")
    if not all(isinstance(v, int) for v in value):
        raise ValueError(f"{field_name} must contain integers")
    return int(value[0]), int(value[1])


def _as_int(value: Any, field_name: str) -> int:
    if not isinstance(value, int):
        raise ValueError(f"{field_name} must be an integer")
    return value


def load_flows(path: Path) -> List[Flow]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or "traffic_flows" not in data:
        raise ValueError("Missing top-level 'traffic_flows' list")

    raw_flows = data["traffic_flows"]
    if not isinstance(raw_flows, list):
        raise ValueError("'traffic_flows' must be a list")

    flows: List[Flow] = []
    for idx, raw in enumerate(raw_flows):
        if not isinstance(raw, dict):
            raise ValueError(f"flow[{idx}] must be a mapping")

        try:
            name = raw["name"]
            initiator = _as_coord(raw["initiator"], f"flow[{idx}].initiator")
            endpoint = _as_coord(raw["endpoint"], f"flow[{idx}].endpoint")
            rw = raw["rw"]
            narrow = raw["narrow_burst"]
            wide = raw["wide_burst"]

            if not isinstance(name, str):
                raise ValueError(f"flow[{idx}].name must be a string")
            if not isinstance(rw, str):
                raise ValueError(f"flow[{idx}].rw must be a string")
            if not isinstance(narrow, dict):
                raise ValueError(f"flow[{idx}].narrow_burst must be a mapping")
            if not isinstance(wide, dict):
                raise ValueError(f"flow[{idx}].wide_burst must be a mapping")

            flow = Flow(
                name=name,
                initiator=initiator,
                endpoint=endpoint,
                rw=rw,
                narrow_number=_as_int(narrow["number"], f"flow[{idx}].narrow_burst.number"),
                narrow_length=_as_int(narrow["length"], f"flow[{idx}].narrow_burst.length"),
                wide_number=_as_int(wide["number"], f"flow[{idx}].wide_burst.number"),
                wide_length=_as_int(wide["length"], f"flow[{idx}].wide_burst.length"),
            )
        except KeyError as exc:
            raise ValueError(f"flow[{idx}] missing field: {exc}") from exc

        flows.append(flow)

    return flows


def check_generic(path: Path, flows: Sequence[Flow]) -> List[str]:
    issues: List[str] = []

    if not flows:
        issues.append("No traffic flows found")
        return issues

    critical = [f for f in flows if f.name == "critical"]
    if len(critical) != 1:
        issues.append(f"Expected exactly 1 critical flow, found {len(critical)}")

    rw_values = {f.rw for f in flows}
    if len(rw_values) > 1:
        issues.append(f"Mixed rw modes in one file: {sorted(rw_values)}")

    active_flows = [f for f in flows if f.active]
    initiators: Set[Coord] = set()
    for flow in active_flows:
        if flow.initiator in initiators:
            issues.append(f"Duplicate active initiator {flow.initiator}")
        initiators.add(flow.initiator)

    # Enforce the burst template used by all provided files.
    for i, flow in enumerate(flows):
        if flow.narrow_number != 0 or flow.narrow_length != 0:
            issues.append(
                f"flow[{i}] has non-zero narrow burst ({flow.narrow_number}, {flow.narrow_length})"
            )

        if flow.active:
            if flow.wide_number != 32:
                issues.append(f"flow[{i}] active wide_burst.number is {flow.wide_number}, expected 32")
            if flow.wide_length != 256:
                issues.append(f"flow[{i}] active wide_burst.length is {flow.wide_length}, expected 256")
        else:
            if flow.wide_number != 0:
                issues.append(f"flow[{i}] inactive wide_burst.number is {flow.wide_number}, expected 0")
            if flow.wide_length != 256:
                issues.append(f"flow[{i}] inactive wide_burst.length is {flow.wide_length}, expected 256")

    return issues


def check_h_series(path: Path, flows: Sequence[Flow]) -> List[str]:
    issues: List[str] = []
    m = re.fullmatch(r"rt_inter_flow_(\d+)h\.yml", path.name)
    if not m:
        return issues

    hops = int(m.group(1))
    critical = [f for f in flows if f.name == "critical"]
    if len(critical) != 1:
        return issues
    crit = critical[0]

    expected_crit_src = (1, 1)
    expected_crit_dst = (1, hops + 1)
    if crit.initiator != expected_crit_src:
        issues.append(
            f"Critical initiator is {crit.initiator}, expected {expected_crit_src} for {hops}h"
        )
    if crit.endpoint != expected_crit_dst:
        issues.append(
            f"Critical endpoint is {crit.endpoint}, expected {expected_crit_dst} for {hops}h"
        )

    active_inits: Set[Coord] = {f.initiator for f in flows if f.active and f.name != "critical"}

    d = expected_crit_dst[1]
    expected_inits: Set[Coord] = {(1, 0), (0, 1), (2, 1), (0, d), (2, d), (1, d + 1)}
    for y in range(2, d):
        expected_inits.update({(0, y), (1, y), (2, y)})

    missing = sorted(expected_inits - active_inits)
    extra = sorted(active_inits - expected_inits)
    if missing:
        issues.append(f"Missing expected active interferer initiators: {missing}")
    if extra:
        issues.append(f"Unexpected active interferer initiators: {extra}")

    expected_active_total = 3 * hops + 4
    actual_active_total = sum(1 for f in flows if f.active)
    if actual_active_total != expected_active_total:
        issues.append(
            f"Active flow count is {actual_active_total}, expected {expected_active_total} for {hops}h"
        )

    return issues


def check_xy_conflicts(flows: Sequence[Flow]) -> List[str]:
    """Check that every active interferer overlaps with the critical XY route.

    Overlap is accepted when at least one router on the critical route is shared
    (excluding the critical source), or when one directed link is shared.
    """
    issues, _, _, _ = collect_xy_conflicts(flows)
    return issues


def check_be_single_hop_overlap(portions: Sequence[ConflictPortion]) -> Tuple[List[str], Dict[str, int]]:
    """Check BE overlap depth with CR links.

    Expected behavior for the provided scenarios is one shared CR link per active BE
    (destination node contention is handled separately).
    """
    issues: List[str] = []
    stats = {
        "be_total": 0,
        "be_shared_links_0": 0,
        "be_shared_links_1": 0,
        "be_shared_links_gt1": 0,
    }

    for p in portions:
        stats["be_total"] += 1
        n_shared = len(p.shared_links)
        if n_shared == 0:
            stats["be_shared_links_0"] += 1
        elif n_shared == 1:
            stats["be_shared_links_1"] += 1
        else:
            stats["be_shared_links_gt1"] += 1
            issues.append(
                "flow[{}] initiator {} -> endpoint {} shares {} CR links (expected at most 1): {}".format(
                    p.flow_index,
                    p.initiator,
                    p.endpoint,
                    n_shared,
                    p.shared_links,
                )
            )

    return issues, stats


def _coord_to_list(coord: Coord) -> List[int]:
    return [coord[0], coord[1]]


def _link_to_list(link: Link) -> List[List[int]]:
    return [_coord_to_list(link[0]), _coord_to_list(link[1])]


def distinct_colors(n: int) -> List[Tuple[float, float, float]]:
    """Generate blue-green RGB shades for BE stream plotting."""
    if n <= 0:
        return []
    colors: List[Tuple[float, float, float]] = []
    # Restrict hue to blue-green range to keep BE streams stylistically grouped.
    hue_start = 0.48  # cyan-green
    hue_end = 0.63    # blue
    for i in range(n):
        if n == 1:
            h = (hue_start + hue_end) / 2.0
        else:
            h = hue_start + (hue_end - hue_start) * (i / float(n - 1))
        s = 0.72
        v = 0.88
        colors.append(colorsys.hsv_to_rgb(h, s, v))
    return colors


def save_conflict_portions(
    path: Path,
    flows: Sequence[Flow],
    portions: Sequence[ConflictPortion],
    crit_nodes: Sequence[Coord],
    crit_links: Set[Link],
    out_dir: Path,
) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    critical = [f for f in flows if f.name == "critical"]
    critical_flow = critical[0] if critical else None
    payload = {
        "scenario": path.name,
        "critical": {
            "initiator": _coord_to_list(critical_flow.initiator) if critical_flow else None,
            "endpoint": _coord_to_list(critical_flow.endpoint) if critical_flow else None,
            "xy_route_nodes": [_coord_to_list(n) for n in crit_nodes],
            "xy_route_links": [_link_to_list(l) for l in sorted(crit_links)],
        },
        "interferers": [
            {
                "flow_index": p.flow_index,
                "initiator": _coord_to_list(p.initiator),
                "endpoint": _coord_to_list(p.endpoint),
                "conflicts": p.conflicts,
                "shared_nodes": [_coord_to_list(n) for n in p.shared_nodes],
                "shared_links": [_link_to_list(l) for l in p.shared_links],
            }
            for p in portions
        ],
    }

    out_path = out_dir / f"{path.stem}_xy_conflicts.json"
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def render_mesh_image(
    path: Path,
    flows: Sequence[Flow],
    portions: Sequence[ConflictPortion],
    crit_nodes: Sequence[Coord],
    out_dir: Path,
) -> None:
    """Render a per-scenario 2D mesh image with overlaps highlighted."""
    try:
        import matplotlib.pyplot as plt
    except ImportError as exc:
        raise RuntimeError("matplotlib is required for --render-mesh-dir") from exc

    out_dir.mkdir(parents=True, exist_ok=True)

    active_flows = [f for f in flows if f.active]
    interferer_flows = [f for f in active_flows if f.name != "critical"]
    interferer_colors = distinct_colors(len(interferer_flows))

    all_coords: Set[Coord] = set()
    for flow in active_flows:
        all_coords.add(flow.initiator)
        all_coords.add(flow.endpoint)
        all_coords.update(xy_route_nodes(flow.initiator, flow.endpoint))

    if not all_coords:
        all_coords = {(0, 0)}

    xs = [x for x, _ in all_coords]
    ys = [y for _, y in all_coords]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)

    fig_w = max(6.0, (max_x - min_x + 2) * 0.8)
    fig_h = max(4.0, (max_y - min_y + 2) * 0.8)
    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    square_marker_size = 120
    marker_text_style = {
        "color": "white",
        "fontsize": 7,
        "fontweight": "bold",
        "fontfamily": "DejaVu Sans",
        "ha": "center",
        "va": "center",
    }
    critical_path_color = "#2a9d8f"
    critical_emphasis_color = "#d00000"
    segment_ticks: Dict[Link, List[Tuple[Tuple[float, float, float] | str, Coord, Coord, Coord]]] = {}

    # Draw mesh nodes.
    mesh_x = []
    mesh_y = []
    for x in range(min_x, max_x + 1):
        for y in range(min_y, max_y + 1):
            mesh_x.append(x)
            mesh_y.append(y)
    ax.scatter(mesh_x, mesh_y, s=18, color="#b8b8b8", alpha=0.40, zorder=1)

    # Draw active interferer routes with distinct dotted colors.
    color_by_initiator = {}
    for idx, flow in enumerate(interferer_flows):
        color = interferer_colors[idx]
        color_by_initiator[flow.initiator] = color
        nodes = xy_route_nodes(flow.initiator, flow.endpoint)
        for a, b in zip(nodes[:-1], nodes[1:]):
            key = canonical_link((a, b))
            segment_ticks.setdefault(key, []).append((color, a, b, flow.initiator))
        ax.plot(
            [n[0] for n in nodes],
            [n[1] for n in nodes],
            color=color,
            linewidth=1.8,
            linestyle=":",
            alpha=0.55,
            zorder=2,
            label="BE",
        )

    # Draw critical route in solid green.
    if crit_nodes:
        critical_src = crit_nodes[0]
        for a, b in zip(crit_nodes[:-1], crit_nodes[1:]):
            key = canonical_link((a, b))
            segment_ticks.setdefault(key, []).append((critical_emphasis_color, a, b, critical_src))
        ax.plot(
            [n[0] for n in crit_nodes],
            [n[1] for n in crit_nodes],
            color=critical_path_color,
            linewidth=3.0,
            linestyle="-",
            alpha=0.60,
            zorder=4,
            label="critical path",
        )

    # Draw direction ticks: one arrow per stream on each segment, offset on shared links.
    for entries in segment_ticks.values():
        # Balance arrows symmetrically around the segment centerline.
        n_entries = len(entries)
        step = 0.09
        for j, (color, a, b, initiator) in enumerate(entries):
            x0, y0 = a
            x1, y1 = b
            dx = x1 - x0
            dy = y1 - y0
            length = (dx ** 2 + dy ** 2) ** 0.5
            if length == 0:
                continue

            ux = dx / length
            uy = dy / length
            # Perpendicular offset so shared segments show one arrow per stream.
            px = -uy
            py = ux
            offset = (j - (n_entries - 1) / 2.0) * step

            mx = (x0 + x1) / 2.0 + offset * px
            my = (y0 + y1) / 2.0 + offset * py
            half = 0.18
            sx = mx - half * ux
            sy = my - half * uy
            ex = mx + half * ux
            ey = my + half * uy

            ax.annotate(
                "",
                xy=(ex, ey),
                xytext=(sx, sy),
                arrowprops={
                    "arrowstyle": "-|>",
                    "color": color,
                    "lw": 1.25,
                    "alpha": 0.95,
                    "shrinkA": 0.0,
                    "shrinkB": 0.0,
                    "mutation_scale": 10.0,
                },
                zorder=6,
            )

    # Mark initiators only.
    interferer_marker_label_used = False
    critical_endpoint: Coord | None = None
    for flow in active_flows:
        if flow.name == "critical":
            critical_endpoint = flow.endpoint
            ax.scatter(
                flow.initiator[0],
                flow.initiator[1],
                marker="s",
                s=square_marker_size,
                color=critical_emphasis_color,
                edgecolors="black",
                linewidths=0.7,
                zorder=7,
                label="critical initiator (CR)",
            )
            ax.text(
                flow.initiator[0],
                flow.initiator[1],
                "CR",
                zorder=8,
                **marker_text_style,
            )
        else:
            marker_color = color_by_initiator.get(flow.initiator, "#264653")
            ax.scatter(
                flow.initiator[0],
                flow.initiator[1],
                marker="s",
                s=square_marker_size,
                color=marker_color,
                edgecolors="black",
                linewidths=0.5,
                alpha=0.95,
                zorder=6,
                label="interferer initiator (BE)" if not interferer_marker_label_used else None,
            )
            ax.text(
                flow.initiator[0],
                flow.initiator[1],
                "BE",
                zorder=7,
                **marker_text_style,
            )
            interferer_marker_label_used = True

    # Mark critical destination as memory node (blue square with centered M).
    if critical_endpoint is not None:
        ax.scatter(
            critical_endpoint[0],
            critical_endpoint[1],
            marker="s",
            s=square_marker_size,
            color="#1d4ed8",
            edgecolors="black",
            linewidths=0.6,
            zorder=7,
            label="memory endpoint (M)",
        )
        ax.text(
            critical_endpoint[0],
            critical_endpoint[1],
            "M",
            zorder=8,
            **marker_text_style,
        )

    ax.set_title(f"XY conflicts: {path.name}")
    ax.set_xlabel("X")
    ax.set_ylabel("Y")
    ax.set_aspect("equal", adjustable="box")
    ax.grid(True, color="#d9d9d9", linewidth=0.6, alpha=0.7)
    ax.set_xlim(min_x - 0.5, max_x + 0.5)
    ax.set_ylim(min_y - 0.5, max_y + 0.5)

    handles, labels = ax.get_legend_handles_labels()
    if handles:
        unique = {}
        for handle, label in zip(handles, labels):
            if label not in unique:
                unique[label] = handle
        ax.legend(
            unique.values(),
            unique.keys(),
            fontsize=8,
            loc="upper left",
            bbox_to_anchor=(1.02, 1.0),
            borderaxespad=0.0,
        )

    out_path = out_dir / f"{path.stem}_xy_conflicts.png"
    fig.tight_layout()
    fig.savefig(out_path, dpi=180, bbox_inches="tight")
    plt.close(fig)


def run(paths: Sequence[Path], save_conflicts_dir: Path | None, render_mesh_dir: Path | None) -> int:
    any_issue = False
    for path in paths:
        print(f"\n== {path} ==")
        try:
            flows = load_flows(path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            any_issue = True
            print(f"ERROR: {exc}")
            continue

        issues = []
        issues.extend(check_generic(path, flows))
        issues.extend(check_h_series(path, flows))
        xy_issues, portions, crit_nodes, crit_links = collect_xy_conflicts(flows)
        issues.extend(xy_issues)
        hop_issues, hop_stats = check_be_single_hop_overlap(portions)
        issues.extend(hop_issues)

        if save_conflicts_dir is not None:
            save_conflict_portions(path, flows, portions, crit_nodes, crit_links, save_conflicts_dir)

        if render_mesh_dir is not None:
            render_mesh_image(path, flows, portions, crit_nodes, render_mesh_dir)

        if issues:
            any_issue = True
            for issue in issues:
                print(f"ANOMALY: {issue}")
        else:
            print("OK: no anomalies found")

        print("INFO: BE vs CR shared-link overlap summary")
        print(f"  active BE flows: {hop_stats['be_total']}")
        print(
            "  BE with 0 shared CR links: "
            f"{hop_stats['be_shared_links_0']} (no direct CR-link contention)"
        )
        print(
            "  BE with exactly 1 shared CR link: "
            f"{hop_stats['be_shared_links_1']} (matches your intended construction)"
        )
        print(
            "  BE with >1 shared CR links: "
            f"{hop_stats['be_shared_links_gt1']} (multi-hop CR contention)"
        )

    print()
    if any_issue:
        print("Validation finished with anomalies.")
        return 1

    print("Validation finished successfully.")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate rt_inter_flow traffic YAML files")
    parser.add_argument(
        "paths",
        nargs="*",
        help="Input YAML files. If omitted, checks rt_inter_flow*.yml in current directory.",
    )
    parser.add_argument(
        "--save-conflicts-dir",
        type=Path,
        default=Path("out/xy_conflicts"),
        help="Optional output directory for per-scenario XY conflict JSON files.",
    )
    parser.add_argument(
        "--render-mesh-dir",
        type=Path,
        default=Path("out/xy_mesh_images"),
        help="Optional output directory for per-scenario XY conflict mesh PNG files.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.paths:
        paths = [Path(p) for p in args.paths]
    else:
        paths = [Path(p) for p in sorted(glob.glob("rt_inter_flow*.yml"))]

    if not paths:
        print("No files found. Provide paths or run in traffic directory.")
        return 2

    return run(paths, args.save_conflicts_dir, args.render_mesh_dir)


if __name__ == "__main__":
    sys.exit(main())