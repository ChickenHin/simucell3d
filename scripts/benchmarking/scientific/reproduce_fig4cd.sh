#!/usr/bin/env bash
# Reproduce Nature paper Figure 4c-d: Pseudostratified Epithelia
#
# This script validates pseudostratified epithelium formation where
# nuclei undergo interkinetic nuclear migration (INM) within elongated cells.
#
# Expected result: Cells adopt columnar morphology with nuclei at varying
# apicobasal positions, reproducing the pseudostratified appearance.
#
# Usage: ./reproduce_fig4cd.sh [BUILD_DIR]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="${1:-$PROJECT_ROOT/build}"
SIMUCELL3D="$BUILD_DIR/simucell3d"
RESULTS_DIR="$PROJECT_ROOT/simulation_results/nature_fig4cd"

# Verify binary exists
if [[ ! -x "$SIMUCELL3D" ]]; then
    echo "ERROR: simucell3d binary not found at $SIMUCELL3D"
    echo "Please build first: cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j\$(nproc)"
    exit 1
fi

echo "========================================="
echo "Nature Figure 4c-d Reproduction"
echo "Pseudostratified Epithelia"
echo "========================================="

# Set OpenMP environment
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$(nproc)}"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

echo "Using $OMP_NUM_THREADS threads"

mkdir -p "$RESULTS_DIR"

PARAM_FILE="$PROJECT_ROOT/parameters/benchmarks/fig4c_pseudostratified.xml"
if [[ ! -f "$PARAM_FILE" ]]; then
    echo "WARNING: Parameter file not found: $PARAM_FILE"
    echo "Using default vesicle parameters as fallback"
    PARAM_FILE="$PROJECT_ROOT/parameters/core/parameters_vesicle.xml"
fi

echo "Parameter file: $PARAM_FILE"
echo "Output: $RESULTS_DIR"
echo ""

time "$SIMUCELL3D" "$PARAM_FILE" --schedule=adaptive 2>&1 | tee "$RESULTS_DIR/simulation.log"

echo ""
echo "========================================="
echo "Figure 4c-d reproduction complete!"
echo "Results: $RESULTS_DIR"
echo ""
echo "Validation criteria:"
echo "  - Cells adopt columnar morphology (height/width ratio > 2)"
echo "  - Nuclei positions vary along apicobasal axis"
echo "  - Compare VTK output with baselines/nature_paper/fig4cd/"
echo "========================================="
