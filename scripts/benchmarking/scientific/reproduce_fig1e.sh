#!/usr/bin/env bash
# Reproduce Nature paper Figure 1e: Scaling Validation (125K cells)
#
# WARNING: This is a long-running benchmark (estimated 12-24 hours).
# It validates SimuCell3D's ability to handle large-scale tissue simulations.
#
# Expected result: Tissue grows from initial cells to ~125K cells,
# demonstrating scaling behavior consistent with the Nature paper.
#
# Usage: ./reproduce_fig1e.sh [BUILD_DIR]
#   BUILD_DIR: path to build directory (default: PROJECT_ROOT/build)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="${1:-$PROJECT_ROOT/build}"
SIMUCELL3D="$BUILD_DIR/simucell3d"
RESULTS_DIR="$PROJECT_ROOT/simulation_results/nature_fig1e"

# Verify binary exists
if [[ ! -x "$SIMUCELL3D" ]]; then
    echo "ERROR: simucell3d binary not found at $SIMUCELL3D"
    echo "Please build first: cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j\$(nproc)"
    exit 1
fi

echo "========================================="
echo "Nature Figure 1e Reproduction"
echo "Scaling Validation (~125K cells)"
echo "========================================="
echo ""
echo "WARNING: This benchmark may take 12-24 hours to complete."
echo "Press Ctrl+C within 10 seconds to cancel..."
sleep 10

# Set OpenMP environment for maximum performance
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$(nproc)}"
export OMP_PROC_BIND=close
export OMP_PLACES=cores
export OMP_WAIT_POLICY=passive
export OMP_DYNAMIC=false

echo "Using $OMP_NUM_THREADS threads"
echo ""

mkdir -p "$RESULTS_DIR"

PARAM_FILE="$PROJECT_ROOT/parameters/benchmarks/fig1e_scaling.xml"
if [[ ! -f "$PARAM_FILE" ]]; then
    echo "WARNING: Parameter file not found: $PARAM_FILE"
    echo "Using default dynamic parameters as fallback"
    PARAM_FILE="$PROJECT_ROOT/parameters/core/parameters_default_dynamic.xml"
fi

echo "Parameter file: $PARAM_FILE"
echo "Output: $RESULTS_DIR"
echo "Started at: $(date)"
echo ""

# Run with diagnostics export for performance monitoring
time "$SIMUCELL3D" "$PARAM_FILE" --schedule=adaptive \
    --diagnostics-csv="$RESULTS_DIR/diagnostics.csv" \
    2>&1 | tee "$RESULTS_DIR/simulation.log"

echo ""
echo "========================================="
echo "Figure 1e reproduction complete!"
echo "Finished at: $(date)"
echo "Results: $RESULTS_DIR"
echo ""
echo "Validation criteria:"
echo "  - Final cell count approaches 125K"
echo "  - Cell growth rate matches biological timescale"
echo "  - Compare with baselines/nature_paper/fig1e/"
echo ""
echo "Performance diagnostics: $RESULTS_DIR/diagnostics.csv"
echo "========================================="
