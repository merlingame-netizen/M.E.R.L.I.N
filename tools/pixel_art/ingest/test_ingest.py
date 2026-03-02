"""Test the full ingestion pipeline on the ChatGPT Bestiole image."""

import os
import sys

# Add project root to path
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
sys.path.insert(0, ROOT)
TOOLS = os.path.join(ROOT, 'tools')
sys.path.insert(0, TOOLS)

from pixel_art.ingest import ingest_character
from pixel_art.ingest.image_analyzer import analyze_image, print_analysis
from pixel_art.ingest.polygon_extractor import extract_facets


def test_analyze():
    """Test image analysis on the Bestiole ChatGPT image."""
    img_path = os.path.join(
        os.path.expanduser('~'), 'Downloads',
        'ChatGPT Image 1 mars 2026, 14_11_35.png'
    )

    if not os.path.exists(img_path):
        print(f"  [SKIP] Image not found: {img_path}")
        return

    print("\n" + "=" * 50)
    print("  TEST 1: Image Analysis")
    print("=" * 50)

    analysis = analyze_image(img_path, color_tolerance=15)
    print_analysis(analysis)

    assert analysis.estimated_facets > 10, f"Expected >10 facets, got {analysis.estimated_facets}"
    assert analysis.symmetry_score > 0.5, f"Expected symmetry > 0.5, got {analysis.symmetry_score}"
    print("  [PASS] Analysis OK")


def test_extract():
    """Test facet extraction."""
    img_path = os.path.join(
        os.path.expanduser('~'), 'Downloads',
        'ChatGPT Image 1 mars 2026, 14_11_35.png'
    )

    if not os.path.exists(img_path):
        print(f"  [SKIP] Image not found: {img_path}")
        return

    print("\n" + "=" * 50)
    print("  TEST 2: Facet Extraction")
    print("=" * 50)

    facets = extract_facets(img_path, color_tolerance=15, min_area=100, max_vertices=8)

    print(f"\n  Extracted {len(facets)} facets:")
    for f in facets[:15]:  # Show first 15
        print(f"    {f.name:15s}  color={f.color}  area={f.area:>5}  "
              f"centroid=({f.centroid[0]:.0f},{f.centroid[1]:.0f})  z={f.z_order}")

    if len(facets) > 15:
        print(f"    ... and {len(facets) - 15} more")

    assert len(facets) >= 10, f"Expected >=10 facets, got {len(facets)}"
    print(f"\n  [PASS] Extraction OK — {len(facets)} facets")


def test_full_pipeline():
    """Test the complete ingest pipeline: image -> extract -> animate -> export."""
    img_path = os.path.join(
        os.path.expanduser('~'), 'Downloads',
        'ChatGPT Image 1 mars 2026, 14_11_35.png'
    )

    if not os.path.exists(img_path):
        print(f"  [SKIP] Image not found: {img_path}")
        return

    print("\n" + "=" * 50)
    print("  TEST 3: Full Pipeline (Bestiole)")
    print("=" * 50)

    result = ingest_character(
        img_path,
        anatomy='quadruped',
        animation='idle',
        frame_count=12,
        target_size=128,
        color_tolerance=15,
        min_area=100,
        max_vertices=8,
        verbose=True,
        export=True,
    )

    print(f"\n  Results:")
    print(f"    Facets: {len(result['facets'])}")
    print(f"    Groups: {list(result['groups'].keys())}")
    print(f"    Frames: {len(result['frames'])}")
    if 'files' in result:
        for f in result['files'].get('files', []):
            print(f"    File: {os.path.basename(f)}")

    assert len(result['frames']) == 12, f"Expected 12 frames, got {len(result['frames'])}"
    print(f"\n  [PASS] Full pipeline OK")


if __name__ == '__main__':
    test_analyze()
    test_extract()
    test_full_pipeline()
    print("\n  ALL TESTS PASSED")
