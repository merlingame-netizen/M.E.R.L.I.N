"""PBI Visual Adapter — Pixel-precise PBIR visual control via CLI-Anything.

Manipulates report.json visuals: position, color, text, data bindings.
Uses _pbir_engine for all PBIR operations.

Usage:
    python tools/cli.py pbi-visual list-visuals --report <report_dir>
    python tools/cli.py pbi-visual add-shape --report ... --x 0 --y 0 --w 100 --h 50 --fill "#FF7900"
    python tools/cli.py pbi-visual fix-vcobjects --report ... [--dry_run]
"""

from __future__ import annotations

from typing import Any

from adapters.base_adapter import BaseAdapter


class PBIVisualAdapter(BaseAdapter):
    """CLI adapter for pixel-precise PBI report visual manipulation."""

    def __init__(self) -> None:
        super().__init__("pbi-visual")

    def list_actions(self) -> dict[str, str]:
        return {
            "list-visuals":        "List all visuals on a page with positions and properties",
            "get-visual":          "Get full config of a single visual by ID",
            "add-shape":           "Add a shape (colored rectangle) to the page",
            "add-textbox":         "Add a textbox with styled text",
            "add-card":            "Add a card visual bound to a measure",
            "add-slicer":          "Add a slicer visual",
            "move-visual":         "Move or resize a visual by ID",
            "delete-visual":       "Delete a visual by ID",
            "set-fill":            "Change fill color of a shape",
            "set-text":            "Change text and style of a textbox",
            "set-page-bg":         "Set the page background color",
            "fix-vcobjects":       "Remove vcObjects from decorative types (fixes blue rendering)",
            "generate-cockpit":    "Generate full cockpit SAT v4 layout",
            "patch-theme":         "Patch custom theme to fix background override (show:false)",
            "dump-visual":         "Dump full JSON of a visual container for debugging",
            "validate-bindings":   "Validate card/slicer bindings against model.bim",
            "preview":             "Generate headless preview (evaluate → HTML → PNG)",
            "compare":             "Pixel-diff preview vs reference HTML screenshot",
            "health":              "Validate report.json is readable",
        }

    def health_probe(self) -> tuple[str, dict]:
        return "health", {}

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "list-visuals":     self._list_visuals,
            "get-visual":       self._get_visual,
            "add-shape":        self._add_shape,
            "add-textbox":      self._add_textbox,
            "add-card":         self._add_card,
            "add-slicer":       self._add_slicer,
            "move-visual":      self._move_visual,
            "delete-visual":    self._delete_visual,
            "set-fill":         self._set_fill,
            "set-text":         self._set_text,
            "set-page-bg":      self._set_page_bg,
            "fix-vcobjects":    self._fix_vcobjects,
            "generate-cockpit":    self._generate_cockpit,
            "patch-theme":         self._patch_theme,
            "dump-visual":         self._dump_visual,
            "validate-bindings":   self._validate_bindings,
            "preview":             self._preview,
            "compare":             self._compare,
            "health":              self._health,
        }
        handler = dispatch.get(action)
        if not handler:
            raise NotImplementedError(action)
        return handler(**kwargs)

    # ── Actions ──────────────────────────────────────────────────────────────

    def _list_visuals(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import list_visuals, load_report

        report_dir = self._require(kwargs, "report")
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        visuals = list_visuals(report, page)

        self.log(f"Found {len(visuals)} visuals on page {page}")
        return self.ok({"visuals": visuals, "count": len(visuals)})

    def _get_visual(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import get_visual, load_report

        report_dir = self._require(kwargs, "report")
        visual_id = self._require(kwargs, "visual_id")
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        vc = get_visual(report, page, visual_id)
        if not vc:
            return self.error(f"Visual '{visual_id}' not found")
        return self.ok(vc)

    def _add_shape(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import add_visual, load_report, save_report

        report_dir = self._require(kwargs, "report")
        x = int(self._require(kwargs, "x"))
        y = int(self._require(kwargs, "y"))
        w = int(kwargs.get("w", kwargs.get("width", 100)))
        h = int(kwargs.get("h", kwargs.get("height", 50)))
        fill = kwargs.get("fill", kwargs.get("fill_color", "#FFFFFF"))
        line_weight = int(kwargs.get("line_weight", 0))
        round_edge = int(kwargs.get("round_edge", 0))
        transparency = int(kwargs.get("transparency", 0))
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report, vid = add_visual(report, page, "shape", x, y, w, h,
                                  properties={
                                      "fill_color": fill,
                                      "fill_transparency": transparency,
                                      "line_weight": line_weight,
                                      "round_edge": round_edge,
                                  })
        save_report(report_dir, report)
        self.log(f"Added shape {vid} at ({x},{y}) {w}x{h} fill={fill}")
        return self.ok({"visual_id": vid})

    def _add_textbox(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import add_visual, load_report, save_report

        report_dir = self._require(kwargs, "report")
        x = int(self._require(kwargs, "x"))
        y = int(self._require(kwargs, "y"))
        w = int(kwargs.get("w", kwargs.get("width", 200)))
        h = int(kwargs.get("h", kwargs.get("height", 30)))
        text = kwargs.get("text", "")
        font_size = kwargs.get("font_size", "11pt")
        font_color = kwargs.get("font_color", "#000000")
        font_weight = kwargs.get("font_weight", "normal")
        font_family = kwargs.get("font_family", "Segoe UI")
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report, vid = add_visual(report, page, "textbox", x, y, w, h,
                                  properties={
                                      "text": text,
                                      "font_size": font_size,
                                      "font_color": font_color,
                                      "font_weight": font_weight,
                                      "font_family": font_family,
                                  })
        save_report(report_dir, report)
        self.log(f"Added textbox {vid} '{text[:30]}' at ({x},{y})")
        return self.ok({"visual_id": vid})

    def _add_card(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import add_visual, load_report, save_report

        report_dir = self._require(kwargs, "report")
        x = int(self._require(kwargs, "x"))
        y = int(self._require(kwargs, "y"))
        w = int(kwargs.get("w", kwargs.get("width", 111)))
        h = int(kwargs.get("h", kwargs.get("height", 35)))
        table = self._require(kwargs, "table")
        measure = self._require(kwargs, "measure")
        font_color = kwargs.get("font_color", "#FF7900")
        font_size = int(kwargs.get("font_size", 22))
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report, vid = add_visual(report, page, "card", x, y, w, h,
                                  properties={
                                      "font_color": font_color,
                                      "font_size": font_size,
                                  },
                                  bindings={
                                      "Values": [{"table": table, "measure": measure}],
                                  })
        save_report(report_dir, report)
        self.log(f"Added card {vid} [{table}.{measure}] at ({x},{y})")
        return self.ok({"visual_id": vid})

    def _add_slicer(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import add_visual, load_report, save_report

        report_dir = self._require(kwargs, "report")
        x = int(self._require(kwargs, "x"))
        y = int(self._require(kwargs, "y"))
        w = int(kwargs.get("w", kwargs.get("width", 130)))
        h = int(kwargs.get("h", kwargs.get("height", 63)))
        table = self._require(kwargs, "table")
        column = self._require(kwargs, "column")
        title = kwargs.get("title", column)
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report, vid = add_visual(report, page, "slicer", x, y, w, h,
                                  properties={},
                                  bindings={
                                      "Fields": [{"table": table, "column": column}],
                                  },
                                  title=title)
        save_report(report_dir, report)
        self.log(f"Added slicer {vid} [{table}.{column}] at ({x},{y})")
        return self.ok({"visual_id": vid})

    def _move_visual(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import load_report, move_visual, save_report

        report_dir = self._require(kwargs, "report")
        visual_id = self._require(kwargs, "visual_id")
        page = int(kwargs.get("page", 0))

        x = int(kwargs["x"]) if "x" in kwargs else None
        y = int(kwargs["y"]) if "y" in kwargs else None
        w = int(kwargs.get("w") or kwargs.get("width") or 0) or None
        h = int(kwargs.get("h") or kwargs.get("height") or 0) or None

        report = load_report(report_dir)
        report = move_visual(report, page, visual_id, x=x, y=y, width=w, height=h)
        save_report(report_dir, report)
        self.log(f"Moved {visual_id} → x={x} y={y} w={w} h={h}")
        return self.ok({"visual_id": visual_id})

    def _delete_visual(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import delete_visual, load_report, save_report

        report_dir = self._require(kwargs, "report")
        visual_id = self._require(kwargs, "visual_id")
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report = delete_visual(report, page, visual_id)
        save_report(report_dir, report)
        self.log(f"Deleted {visual_id}")
        return self.ok({"deleted": visual_id})

    def _set_fill(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import load_report, save_report, set_fill_color

        report_dir = self._require(kwargs, "report")
        visual_id = self._require(kwargs, "visual_id")
        color = self._require(kwargs, "color")
        transparency = int(kwargs.get("transparency", 0))
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report = set_fill_color(report, page, visual_id, color, transparency)
        save_report(report_dir, report)
        self.log(f"Set fill {visual_id} → {color}")
        return self.ok({"visual_id": visual_id, "color": color})

    def _set_text(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import load_report, save_report, set_text

        report_dir = self._require(kwargs, "report")
        visual_id = self._require(kwargs, "visual_id")
        text = self._require(kwargs, "text")
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report = set_text(report, page, visual_id, text,
                          font_size=kwargs.get("font_size", "11pt"),
                          font_color=kwargs.get("font_color", "#000000"),
                          font_weight=kwargs.get("font_weight", "normal"),
                          font_family=kwargs.get("font_family", "Segoe UI"))
        save_report(report_dir, report)
        self.log(f"Set text {visual_id} → '{text[:30]}'")
        return self.ok({"visual_id": visual_id})

    def _set_page_bg(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import load_report, save_report, set_page_background

        report_dir = self._require(kwargs, "report")
        color = self._require(kwargs, "color")
        transparency = int(kwargs.get("transparency", 0))
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        report = set_page_background(report, page, color, transparency)
        save_report(report_dir, report)
        self.log(f"Set page {page} bg → {color}")
        return self.ok({"color": color})

    def _fix_vcobjects(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import (
            fix_decorative_vcobjects,
            load_report,
            save_report,
        )

        report_dir = self._require(kwargs, "report")
        dry_run = str(kwargs.get("dry_run", "false")).lower() in ("true", "1", "yes")

        report = load_report(report_dir)
        report, fixes = fix_decorative_vcobjects(report, dry_run=dry_run)

        if not dry_run and fixes:
            save_report(report_dir, report)

        mode = "DRY RUN" if dry_run else "APPLIED"
        self.log(f"{mode}: {len(fixes)} decorative visuals with vcObjects")
        for f in fixes:
            self.log(f"  {f['type']} '{f['id']}' at ({f['x']},{f['y']})")

        return self.ok({
            "mode": mode,
            "fixes_count": len(fixes),
            "fixes": fixes,
        })

    def _generate_cockpit(self, **kwargs: Any) -> dict:
        from adapters._cockpit_generator import generate_cockpit

        report_dir = self._require(kwargs, "report")
        template = kwargs.get("template", "cockpit_sat_v4")

        result = generate_cockpit(report_dir, template)
        self.log(f"Generated cockpit '{template}' → {result['visual_count']} visuals")
        return self.ok(result)

    def _patch_theme(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import patch_theme

        report_dir = self._require(kwargs, "report")
        bg_show = str(kwargs.get("background_show", "false")).lower() in ("true", "1", "yes")

        result = patch_theme(report_dir, background_show=bg_show)
        self.log(f"Patched {len(result['patched_files'])} theme file(s) — background.show={bg_show}")
        for f in result["patched_files"]:
            self.log(f"  {f}")
        return self.ok(result)

    def _dump_visual(self, **kwargs: Any) -> dict:
        from adapters._pbir_engine import dump_visual, load_report

        report_dir = self._require(kwargs, "report")
        visual_id = self._require(kwargs, "visual_id")
        page = int(kwargs.get("page", 0))

        report = load_report(report_dir)
        vc = dump_visual(report, page, visual_id)
        if not vc:
            return self.error(f"Visual '{visual_id}' not found on page {page}")
        self.log(f"Dumped visual '{visual_id}' (page {page})")
        return self.ok(vc)

    def _validate_bindings(self, **kwargs: Any) -> dict:
        import os

        from adapters._pbir_engine import load_report, validate_bindings

        report_dir = self._require(kwargs, "report")
        page = int(kwargs.get("page", 0))

        # Derive model.bim path: sibling .SemanticModel directory
        parent = os.path.dirname(report_dir.rstrip("/\\"))
        project_name = os.path.basename(parent)
        model_path = os.path.join(parent, f"{project_name}.SemanticModel", "model.bim")
        if not os.path.isfile(model_path):
            # Try common fallback
            model_path = kwargs.get("model", "")
            if not model_path or not os.path.isfile(model_path):
                return self.error(
                    f"model.bim not found. Tried: {model_path}. "
                    "Pass --model <path_to_model.bim> explicitly."
                )

        report = load_report(report_dir)
        results = validate_bindings(report, model_path, page)

        ok_count = sum(1 for r in results if r["status"] == "OK")
        err_count = sum(1 for r in results if r["status"] == "ERROR")
        self.log(f"Validated {len(results)} bindings: {ok_count} OK, {err_count} errors")
        for r in results:
            status_icon = "OK" if r["status"] == "OK" else "ERR"
            self.log(f"  [{status_icon}] {r['visual_id']}: {r.get('table','?')}.{r.get('field','?')}")
        return self.ok({
            "bindings": results,
            "total": len(results),
            "ok": ok_count,
            "errors": err_count,
        })

    def _preview(self, **kwargs: Any) -> dict:
        import os

        from adapters._pixel_compare import run_preview_pipeline

        report_dir = self._require(kwargs, "report")
        # Derive project dir (parent of .Report folder)
        project_dir = os.path.dirname(report_dir.rstrip("/\\"))
        out_dir = kwargs.get("out", os.path.join(os.path.expanduser("~"), "Downloads"))
        iteration = int(kwargs.get("iteration", 1))

        result = run_preview_pipeline(project_dir, out_dir, iteration)
        self.log(f"Preview pipeline: {result['measure_count']} measures evaluated")
        self.log(f"  HTML: {result['html_path']}")
        self.log(f"  PNG:  {result['png_path']}")
        return self.ok({
            "html_path": result["html_path"],
            "png_path": result["png_path"],
            "measures_path": result["measures_path"],
            "measure_count": result["measure_count"],
        })

    def _compare(self, **kwargs: Any) -> dict:
        import os

        from adapters._pixel_compare import compare_images, screenshot_html

        report_dir = self._require(kwargs, "report")
        reference = self._require(kwargs, "reference")
        out_dir = kwargs.get("out", os.path.join(os.path.expanduser("~"), "Downloads"))
        tolerance = int(kwargs.get("tolerance", 12))

        # Step 1: Generate preview HTML + measures (via pipeline)
        project_dir = os.path.dirname(report_dir.rstrip("/\\"))
        self.log("Step 1: Generating preview...")
        from adapters._pixel_compare import run_preview_pipeline
        preview = run_preview_pipeline(project_dir, out_dir, iteration=99)

        # Step 2: Screenshot preview HTML (.canvas only, no title bar)
        preview_png = os.path.join(out_dir, "preview_canvas.png")
        self.log("Step 2: Screenshotting preview canvas...")
        screenshot_html(preview["html_path"], preview_png, width=1280, height=720,
                        selector=".canvas")

        # Step 3: Screenshot the reference HTML (viewport clip)
        ref_png = os.path.join(out_dir, "reference_screenshot.png")
        self.log(f"Step 3: Screenshotting reference: {reference}")
        screenshot_html(reference, ref_png, width=1280, height=720)

        # Step 4: Pixel comparison
        diff_png = os.path.join(out_dir, "diff_result.png")
        self.log("Step 4: Pixel comparison...")
        result = compare_images(preview_png, ref_png, diff_png, tolerance=tolerance)

        self.log(f"Similarity: {result['similarity_pct']} ({result['diff_pixels']} diff pixels)")
        self.log(f"  Preview: {preview_png}")
        self.log(f"  Reference: {ref_png}")
        self.log(f"  Diff: {diff_png}")

        # Log worst regions
        for r in result["worst_regions"][:5]:
            if r["similarity"] < 0.99:
                self.log(f"  Region ({r['x']},{r['y']}) {r['w']}x{r['h']}: "
                         f"{r['similarity']:.1%} ({r['diff_pixels']} px)")

        return self.ok({
            "similarity": result["similarity"],
            "similarity_pct": result["similarity_pct"],
            "diff_pixels": result["diff_pixels"],
            "total_pixels": result["total_pixels"],
            "preview_png": preview_png,
            "reference_png": ref_png,
            "diff_png": diff_png,
            "worst_regions": result["worst_regions"][:10],
        })

    def _health(self, **kwargs: Any) -> dict:
        report_dir = kwargs.get("report", "")
        if not report_dir:
            return self.ok({"status": "adapter_loaded", "actions": len(self.list_actions())})

        from adapters._pbir_engine import list_visuals, load_report

        try:
            report = load_report(report_dir)
            sections = report.get("sections", [])
            page_count = len(sections)
            visual_count = sum(
                len(s.get("visualContainers", []))
                for s in sections
            )
            visuals = list_visuals(report, 0) if sections else []
            types = {}
            for v in visuals:
                t = v["type"]
                types[t] = types.get(t, 0) + 1

            return self.ok({
                "status": "healthy",
                "report_dir": report_dir,
                "pages": page_count,
                "total_visuals": visual_count,
                "types": types,
            })
        except Exception as exc:
            return self.error(f"Health check failed: {exc}")

    # ── Helpers ──────────────────────────────────────────────────────────────

    @staticmethod
    def _require(kwargs: dict, key: str) -> Any:
        """Require a kwarg, raising on missing."""
        val = kwargs.get(key)
        if val is None:
            raise ValueError(f"Missing required argument: --{key}")
        return val
