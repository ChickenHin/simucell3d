#!/bin/bash

# metrics_daemon.sh
# Background daemon for continuous per-minute metrics sampling during comparison runs
# Launched by comparison launch scripts (12hour/24hour)
# Samples metrics from both v1.0 and current simulations every 60 seconds

set -e

# Check arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <output_directory>"
  echo "  output_directory: Comparison run output directory"
  exit 1
fi

OUTPUT_DIR="$1"
START_TIME=$(date +%s)

# Source sampling utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/sample_metrics.sh"

# Ensure metrics directory exists
mkdir -p "$OUTPUT_DIR/metrics"

# Initialize timeseries CSV files
echo "Initializing timeseries CSV files..."
initialize_timeseries_csv "$OUTPUT_DIR/metrics/v1_timeseries.csv"
initialize_timeseries_csv "$OUTPUT_DIR/metrics/current_timeseries.csv"

# Read configuration from PID files
echo "Reading simulation configuration..."
if [[ ! -f "$OUTPUT_DIR/v1.pid" ]]; then
  echo "ERROR: v1.pid not found. Ensure v1.0 simulation has been launched."
  exit 1
fi

if [[ ! -f "$OUTPUT_DIR/current.pid" ]]; then
  echo "ERROR: current.pid not found. Ensure current simulation has been launched."
  exit 1
fi

V1_PID=$(cat "$OUTPUT_DIR/v1.pid")
CURRENT_PID=$(cat "$OUTPUT_DIR/current.pid")

# Simulation paths
V1_LOG="$OUTPUT_DIR/logs/v1.log"
CURRENT_LOG="$OUTPUT_DIR/logs/current.log"
V1_SIM_DIR="$OUTPUT_DIR/sim_v1"
CURRENT_SIM_DIR="$OUTPUT_DIR/sim_current"

echo "Metrics daemon started at $(date)"
echo "  v1.0 PID: $V1_PID"
echo "  Current PID: $CURRENT_PID"
echo "  Sampling interval: 60 seconds"
echo "  Output: $OUTPUT_DIR/metrics/"
echo ""

# Sampling loop
SAMPLE_COUNT=0
while true; do
  # Check if both processes are still running
  V1_RUNNING=false
  CURRENT_RUNNING=false

  if kill -0 $V1_PID 2>/dev/null; then
    V1_RUNNING=true
  fi

  if kill -0 $CURRENT_PID 2>/dev/null; then
    CURRENT_RUNNING=true
  fi

  # Exit if both stopped
  if ! $V1_RUNNING && ! $CURRENT_RUNNING; then
    echo "Both simulations have stopped. Exiting metrics daemon."
    break
  fi

  # Sample metrics from both simulations
  SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
  echo "[Sample $SAMPLE_COUNT @ $(date +%H:%M:%S)] Collecting metrics..."

  # Sample v1.0 (even if stopped, to maintain timeline alignment)
  sample_metrics "v1" "$OUTPUT_DIR" "$V1_SIM_DIR" "$V1_LOG" "$V1_PID" "$START_TIME"

  # Sample current
  sample_metrics "current" "$OUTPUT_DIR" "$CURRENT_SIM_DIR" "$CURRENT_LOG" "$CURRENT_PID" "$START_TIME"

  # Show status
  if $V1_RUNNING; then
    echo "  v1.0: Running"
  else
    echo "  v1.0: Stopped"
  fi

  if $CURRENT_RUNNING; then
    echo "  Current: Running"
  else
    echo "  Current: Stopped"
  fi

  # Calculate division rates
  V1_DIV_RATE=$(calculate_division_rate "$OUTPUT_DIR/metrics/v1_timeseries.csv" 60)
  CURRENT_DIV_RATE=$(calculate_division_rate "$OUTPUT_DIR/metrics/current_timeseries.csv" 60)

  echo "  Division rates: v1.0=${V1_DIV_RATE}/min, current=${CURRENT_DIV_RATE}/min"
  echo ""

  # Wait 60 seconds before next sample
  sleep 60
done

# Final summary
TOTAL_SAMPLES=$(wc -l < "$OUTPUT_DIR/metrics/v1_timeseries.csv")
TOTAL_SAMPLES=$((TOTAL_SAMPLES - 1))  # Subtract header

echo ""
echo "Metrics sampling completed at $(date)"
echo "  Total samples collected: $TOTAL_SAMPLES"
echo "  Duration: $(($(date +%s) - START_TIME)) seconds"
echo "  Output files:"
echo "    - $OUTPUT_DIR/metrics/v1_timeseries.csv"
echo "    - $OUTPUT_DIR/metrics/current_timeseries.csv"
