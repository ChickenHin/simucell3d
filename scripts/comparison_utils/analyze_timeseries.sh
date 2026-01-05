#!/bin/bash

# analyze_timeseries.sh
# Post-run analysis script for comparison timeseries data
# Merges v1 and current timeseries, computes derived metrics, and generates summary statistics

set -e

# Check arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <output_directory>"
  echo "  output_directory: Comparison run output directory containing metrics/"
  exit 1
fi

OUTPUT_DIR="$1"

# Check if timeseries files exist
if [[ ! -f "$OUTPUT_DIR/metrics/v1_timeseries.csv" ]]; then
  echo "ERROR: v1 timeseries file not found: $OUTPUT_DIR/metrics/v1_timeseries.csv"
  exit 1
fi

if [[ ! -f "$OUTPUT_DIR/metrics/current_timeseries.csv" ]]; then
  echo "ERROR: Current timeseries file not found: $OUTPUT_DIR/metrics/current_timeseries.csv"
  exit 1
fi

echo "Analyzing timeseries data from: $OUTPUT_DIR/metrics/"
echo ""

# Create merged comparison timeseries
echo "Merging v1.0 and current timeseries..."
awk -F',' 'BEGIN {OFS=","}
  # Print header
  NR==1 {
    print "elapsed_sec,v1_iter,current_iter,speedup,v1_cells,current_cells,v1_divs,current_divs,v1_phase,current_phase,v1_cov,current_cov,v1_cpu,current_cpu,v1_total_ms,current_total_ms"
    next
  }
  # Read v1 data into array
  NR==FNR {
    v1_iter[$1]=$2
    v1_cells[$1]=$3
    v1_divs[$1]=$4
    v1_phase[$1]=$6
    v1_total_ms[$1]=$7
    v1_cov[$1]=$12
    v1_cpu[$1]=$19
    next
  }
  # Match current data with v1 data by elapsed_sec
  $1 in v1_iter {
    elapsed=$1
    current_iter=$2
    current_cells=$3
    current_divs=$4
    current_phase=$6
    current_total_ms=$7
    current_cov=$12
    current_cpu=$19

    # Calculate speedup
    if (v1_iter[elapsed] > 0 && current_iter > 0) {
      speedup = current_iter / v1_iter[elapsed]
    } else {
      speedup = 0
    }

    print elapsed, v1_iter[elapsed], current_iter, speedup, v1_cells[elapsed], current_cells, v1_divs[elapsed], current_divs, v1_phase[elapsed], current_phase, v1_cov[elapsed], current_cov, v1_cpu[elapsed], current_cpu, v1_total_ms[elapsed], current_total_ms
  }
' "$OUTPUT_DIR/metrics/v1_timeseries.csv" "$OUTPUT_DIR/metrics/current_timeseries.csv" \
  > "$OUTPUT_DIR/metrics/comparison_timeseries.csv"

MERGED_ROWS=$(wc -l < "$OUTPUT_DIR/metrics/comparison_timeseries.csv")
MERGED_ROWS=$((MERGED_ROWS - 1))  # Subtract header
echo "  ✓ Merged timeseries saved: $OUTPUT_DIR/metrics/comparison_timeseries.csv ($MERGED_ROWS data points)"

# Detect phase transitions
echo ""
echo "Phase transitions:"
echo "  v1.0:"
awk -F',' 'NR>1 && $6 != phase {
  if (phase != "") print "    " phase " → " $6 " at " $1 "s (" $1/60 " minutes)"
  phase=$6
} END {if (phase != "") print "    Final phase: " phase}' "$OUTPUT_DIR/metrics/v1_timeseries.csv"

echo "  Current:"
awk -F',' 'NR>1 && $6 != phase {
  if (phase != "") print "    " phase " → " $6 " at " $1 "s (" $1/60 " minutes)"
  phase=$6
} END {if (phase != "") print "    Final phase: " phase}' "$OUTPUT_DIR/metrics/current_timeseries.csv"

# Calculate average iteration rates
echo ""
echo "Average iteration rates:"
V1_AVG_RATE=$(awk -F',' 'NR>1 {sum+=$5; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/v1_timeseries.csv")
CURRENT_AVG_RATE=$(awk -F',' 'NR>1 {sum+=$5; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/current_timeseries.csv")
echo "  v1.0:    $V1_AVG_RATE it/s"
echo "  Current: $CURRENT_AVG_RATE it/s"

# Calculate average speedup
echo ""
echo "Average speedup:"
AVG_SPEEDUP=$(awk -F',' 'NR>1 && $4 > 0 {sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/comparison_timeseries.csv")
echo "  ${AVG_SPEEDUP}x (current/v1.0)"

# Final iteration counts
echo ""
echo "Final iteration counts:"
V1_FINAL_ITER=$(tail -1 "$OUTPUT_DIR/metrics/v1_timeseries.csv" | cut -d',' -f2)
CURRENT_FINAL_ITER=$(tail -1 "$OUTPUT_DIR/metrics/current_timeseries.csv" | cut -d',' -f2)
echo "  v1.0:    $V1_FINAL_ITER iterations"
echo "  Current: $CURRENT_FINAL_ITER iterations"

# Final cell counts
echo ""
echo "Final cell counts:"
V1_FINAL_CELLS=$(tail -1 "$OUTPUT_DIR/metrics/v1_timeseries.csv" | cut -d',' -f3)
CURRENT_FINAL_CELLS=$(tail -1 "$OUTPUT_DIR/metrics/current_timeseries.csv" | cut -d',' -f3)
echo "  v1.0:    $V1_FINAL_CELLS cells"
echo "  Current: $CURRENT_FINAL_CELLS cells"

# Total divisions
echo ""
echo "Total cell divisions:"
V1_TOTAL_DIVS=$(tail -1 "$OUTPUT_DIR/metrics/v1_timeseries.csv" | cut -d',' -f4)
CURRENT_TOTAL_DIVS=$(tail -1 "$OUTPUT_DIR/metrics/current_timeseries.csv" | cut -d',' -f4)
echo "  v1.0:    $V1_TOTAL_DIVS divisions"
echo "  Current: $CURRENT_TOTAL_DIVS divisions"

# Average CoV (workload heterogeneity)
echo ""
echo "Average CoV (workload heterogeneity):"
V1_AVG_COV=$(awk -F',' 'NR>1 && $12 != "" {sum+=$12; count++} END {if(count>0) printf "%.4f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/v1_timeseries.csv")
CURRENT_AVG_COV=$(awk -F',' 'NR>1 && $12 != "" {sum+=$12; count++} END {if(count>0) printf "%.4f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/current_timeseries.csv")
echo "  v1.0:    $V1_AVG_COV"
echo "  Current: $CURRENT_AVG_COV"

# Average CPU utilization
echo ""
echo "Average CPU utilization:"
V1_AVG_CPU=$(awk -F',' 'NR>1 && $19 != "" {sum+=$19; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/v1_timeseries.csv")
CURRENT_AVG_CPU=$(awk -F',' 'NR>1 && $19 != "" {sum+=$19; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/current_timeseries.csv")
echo "  v1.0:    ${V1_AVG_CPU}%"
echo "  Current: ${CURRENT_AVG_CPU}%"

# Performance trend analysis (first half vs second half)
echo ""
echo "Performance trend (speedup over time):"
TOTAL_SAMPLES=$(wc -l < "$OUTPUT_DIR/metrics/comparison_timeseries.csv")
TOTAL_SAMPLES=$((TOTAL_SAMPLES - 1))  # Subtract header
HALFWAY=$((TOTAL_SAMPLES / 2))

FIRST_HALF_SPEEDUP=$(awk -F',' -v half="$HALFWAY" 'NR>1 && NR<=half+1 && $4 > 0 {sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/comparison_timeseries.csv")
SECOND_HALF_SPEEDUP=$(awk -F',' -v half="$HALFWAY" 'NR>half+1 && $4 > 0 {sum+=$4; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$OUTPUT_DIR/metrics/comparison_timeseries.csv")

echo "  First half:  ${FIRST_HALF_SPEEDUP}x"
echo "  Second half: ${SECOND_HALF_SPEEDUP}x"

if (( $(echo "$SECOND_HALF_SPEEDUP > $FIRST_HALF_SPEEDUP" | bc -l) )); then
  TREND="improving"
  DELTA=$(awk "BEGIN {printf \"%.2f\", ($SECOND_HALF_SPEEDUP - $FIRST_HALF_SPEEDUP) / $FIRST_HALF_SPEEDUP * 100}")
  echo "  Trend: Performance $TREND (+${DELTA}%)"
elif (( $(echo "$SECOND_HALF_SPEEDUP < $FIRST_HALF_SPEEDUP" | bc -l) )); then
  TREND="degrading"
  DELTA=$(awk "BEGIN {printf \"%.2f\", ($FIRST_HALF_SPEEDUP - $SECOND_HALF_SPEEDUP) / $FIRST_HALF_SPEEDUP * 100}")
  echo "  Trend: Performance $TREND (-${DELTA}%)"
else
  echo "  Trend: Stable"
fi

# Generate summary report
echo ""
echo "Generating summary report..."

cat > "$OUTPUT_DIR/metrics/TIMESERIES_ANALYSIS.txt" <<EOF
Timeseries Analysis Summary
===========================

Analysis Date: $(date)
Data Points: $MERGED_ROWS samples

## Performance Summary

Average Speedup:         ${AVG_SPEEDUP}x (current/v1.0)
First Half Speedup:      ${FIRST_HALF_SPEEDUP}x
Second Half Speedup:     ${SECOND_HALF_SPEEDUP}x
Trend:                   $TREND

## Iteration Throughput

v1.0 Average Rate:       $V1_AVG_RATE it/s
Current Average Rate:    $CURRENT_AVG_RATE it/s
v1.0 Final Iterations:   $V1_FINAL_ITER
Current Final Iterations: $CURRENT_FINAL_ITER

## Biological Metrics

v1.0 Final Cells:        $V1_FINAL_CELLS
Current Final Cells:     $CURRENT_FINAL_CELLS
v1.0 Total Divisions:    $V1_TOTAL_DIVS
Current Total Divisions: $CURRENT_TOTAL_DIVS

## Computational Metrics

v1.0 Average CoV:        $V1_AVG_COV
Current Average CoV:     $CURRENT_AVG_COV
v1.0 Average CPU:        ${V1_AVG_CPU}%
Current Average CPU:     ${CURRENT_AVG_CPU}%

## Output Files

- comparison_timeseries.csv: Merged timeseries with speedup calculations
- v1_timeseries.csv: Raw v1.0 metrics
- current_timeseries.csv: Raw current metrics

EOF

echo "  ✓ Summary report saved: $OUTPUT_DIR/metrics/TIMESERIES_ANALYSIS.txt"

echo ""
echo "Timeseries analysis complete!"
