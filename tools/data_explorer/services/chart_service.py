"""Chart service — build Plotly figures server-side with GraphFit colors."""

from __future__ import annotations

import json
from typing import Any

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

from graphfit import OrangeColors, OrangeColormaps

# ---------------------------------------------------------------------------
# Orange Plotly template (matches notebook ORANGE_TEMPLATE exactly)
# ---------------------------------------------------------------------------

ORANGE_TEMPLATE = go.layout.Template(layout=go.Layout(
    font=dict(family="Helvetica Neue, Arial, sans-serif", color=OrangeColors.GREY_800),
    paper_bgcolor="#141414",
    plot_bgcolor="#1e1e1e",
    colorway=OrangeColormaps.categorical_cmap(),
    title=dict(font=dict(size=16, color="#ffffff")),
    xaxis=dict(
        gridcolor="#333333",
        linecolor=OrangeColors.GREY_700,
        zerolinecolor="#333333",
        tickfont=dict(color="#cccccc"),
        title=dict(font=dict(color="#cccccc")),
    ),
    yaxis=dict(
        gridcolor="#333333",
        linecolor=OrangeColors.GREY_700,
        zerolinecolor="#333333",
        tickfont=dict(color="#cccccc"),
        title=dict(font=dict(color="#cccccc")),
    ),
    legend=dict(font=dict(color="#cccccc")),
))


def _apply_style(fig: go.Figure) -> go.Figure:
    """Apply Orange template + dark-mode margins."""
    fig.update_layout(template=ORANGE_TEMPLATE, margin=dict(t=50, b=40, l=50, r=30))
    return fig


# ---------------------------------------------------------------------------
# Chart builders (one per type)
# ---------------------------------------------------------------------------

def _build_bar_count(df: pd.DataFrame, x: str, top_n: int, **_kw) -> go.Figure:
    counts = (
        df[x].astype("string").fillna("(NA)")
        .value_counts(dropna=False).head(top_n)
        .reset_index()
    )
    counts.columns = [x, "count"]
    return px.bar(
        counts, x=x, y="count",
        title=f"Distribution de {x} (top {top_n})",
        color=x,
        color_discrete_sequence=OrangeColormaps.categorical_cmap(),
    )


def _build_stacked_bar(df: pd.DataFrame, x: str, color: str | None, top_n: int, **_kw) -> go.Figure:
    if not color:
        return _build_bar_count(df, x, top_n)

    agg = (
        df.assign(**{
            x: df[x].astype("string").fillna("(NA)"),
            color: df[color].astype("string").fillna("(NA)"),
        })
        .groupby([x, color]).size().reset_index(name="count")
    )
    top_x = agg.groupby(x)["count"].sum().nlargest(top_n).index
    agg = agg[agg[x].isin(top_x)]
    fig = px.bar(
        agg, x=x, y="count", color=color,
        title=f"{x} par {color} (top {top_n})",
        color_discrete_sequence=OrangeColormaps.categorical_cmap(),
    )
    fig.update_layout(barmode="stack")
    return fig


def _build_hist(df: pd.DataFrame, x: str, **_kw) -> go.Figure:
    if not pd.api.types.is_numeric_dtype(df[x]):
        raise ValueError(f"{x} doit etre numerique pour un histogramme")
    return px.histogram(
        df, x=x, nbins=30,
        title=f"Histogramme {x}",
        color_discrete_sequence=[OrangeColors.ORANGE],
    )


def _build_scatter(df: pd.DataFrame, x: str, y: str, color: str | None, **_kw) -> go.Figure:
    if not y:
        raise ValueError("Scatter: choisir X et Y")
    kw: dict[str, Any] = dict(x=x, y=y, title=f"Scatter {x} vs {y}")
    if color and color in df.columns:
        kw["color"] = color
        kw["color_discrete_sequence"] = OrangeColormaps.categorical_cmap()
    else:
        kw["color_discrete_sequence"] = [OrangeColors.BLUE_500]
    return px.scatter(df, **kw)


def _build_line(df: pd.DataFrame, x: str, y: str, color: str | None, **_kw) -> go.Figure:
    if not y:
        raise ValueError("Line: choisir X et Y")
    kw: dict[str, Any] = dict(x=x, y=y, title=f"Line {y} par {x}")
    if color and color in df.columns:
        kw["color"] = color
        kw["color_discrete_sequence"] = OrangeColormaps.categorical_cmap()
    else:
        kw["color_discrete_sequence"] = [OrangeColors.ORANGE]
    return px.line(df.sort_values(x), **kw)


def _build_box(df: pd.DataFrame, x: str, y: str, color: str | None, **_kw) -> go.Figure:
    target = y or x
    if not pd.api.types.is_numeric_dtype(df[target]):
        raise ValueError(f"{target} doit etre numerique pour un boxplot")
    kw: dict[str, Any] = dict(y=target, title=f"Boxplot {target}")
    if color and color in df.columns:
        kw["x"] = color
        kw["color"] = color
        kw["color_discrete_sequence"] = OrangeColormaps.categorical_cmap()
    else:
        kw["color_discrete_sequence"] = [OrangeColors.BLUE_300]
    return px.box(df, **kw)


def _build_pie(df: pd.DataFrame, x: str, top_n: int, **_kw) -> go.Figure:
    counts = (
        df[x].astype("string").fillna("(NA)")
        .value_counts(dropna=False).head(top_n)
        .reset_index()
    )
    counts.columns = [x, "count"]
    fig = px.pie(
        counts, names=x, values="count",
        title=f"Repartition {x} (top {top_n})",
        color_discrete_sequence=OrangeColormaps.categorical_cmap(),
    )
    fig.update_traces(textposition="inside", textinfo="percent+label")
    return fig


def _build_heatmap(df: pd.DataFrame, columns: list[str], **_kw) -> go.Figure:
    num_cols = [c for c in columns if c in df.columns and pd.api.types.is_numeric_dtype(df[c])]
    if len(num_cols) < 2:
        raise ValueError(f"Heatmap: au moins 2 colonnes numeriques ({len(num_cols)} trouvee(s))")

    corr = df[num_cols].corr()
    blue_colors = OrangeColormaps.blue_cmap()
    n = len(blue_colors)
    colorscale = [[i / (n - 1), c] for i, c in enumerate(blue_colors)] if n > 1 else "Blues"

    fig = go.Figure(data=go.Heatmap(
        z=corr.values,
        x=corr.columns.tolist(),
        y=corr.index.tolist(),
        colorscale=colorscale,
        text=corr.values.round(2),
        texttemplate="%{text}",
        zmin=-1, zmax=1,
    ))
    fig.update_layout(title=f"Matrice de correlation ({len(num_cols)} colonnes)")
    return fig


def _build_treemap(df: pd.DataFrame, x: str, top_n: int, **_kw) -> go.Figure:
    counts = (
        df[x].astype("string").fillna("(NA)")
        .value_counts(dropna=False).head(top_n)
        .reset_index()
    )
    counts.columns = [x, "count"]
    return px.treemap(
        counts, path=[x], values="count",
        title=f"Treemap {x} (top {top_n})",
        color_discrete_sequence=OrangeColormaps.categorical_cmap(),
    )


# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

_BUILDERS = {
    "bar_count": _build_bar_count,
    "stacked_bar": _build_stacked_bar,
    "hist": _build_hist,
    "scatter": _build_scatter,
    "line": _build_line,
    "box": _build_box,
    "pie": _build_pie,
    "heatmap": _build_heatmap,
    "treemap": _build_treemap,
}


def build_chart(
    chart_type: str,
    columns: list[str],
    rows: list[list],
    x: str = "",
    y: str = "",
    color: str | None = None,
    top_n: int = 15,
) -> dict:
    """Build a Plotly figure and return its JSON representation.

    Returns:
        Plotly figure as a dict (data + layout), ready for Plotly.react() on the client.
    """
    if chart_type not in _BUILDERS:
        raise ValueError(f"Type de graphe inconnu: {chart_type}")

    df = pd.DataFrame(rows, columns=columns)

    if not x and columns:
        x = columns[0]

    builder = _BUILDERS[chart_type]
    fig = builder(df=df, x=x, y=y, color=color, top_n=top_n, columns=columns)
    fig = _apply_style(fig)

    return json.loads(fig.to_json())
