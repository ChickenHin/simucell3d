#!/bin/bash

# sample_metrics.sh
# Utility functions for sampling per-minute metrics from SimuCell3D simulations
# Used by metrics_daemon.sh for continuous monitoring during long comparison runs

# Function: sample_metrics
# Samples comprehensive metrics from a running simulation
# Args:
#   $1 - version ("v1" or "current")
#   $2 - output directory (comparison run output)
#   $3 - simulation directory (where simulation_statistics.csv and performance_diagnostics.csv are)
#   $4 - log file path
#   $5 - simulation process PID
#   $6 - start timestamp (Unix epoch seconds)
sample_metrics() {
  local version=$1
  local output_dir=$2
  local sim_dir=$3
  local log_file=$4
  local pid=$5
  local start_time=$6

  # Calculate elapsed time
  local timestamp=$(date +%s)
  local elapsed=$((timestamp - start_time))

  # Initialize variables with defaults
  local iteration=0
  local cell_count=0
  local divisions=0
  local cov=0
  local phase="UNKNOWN"
  local mesh_ms=0
  local contact_ms=0
  local polar_ms=0
  local integ_ms=0
  local total_ms=0
  local imbalance=0
  local avg_volume=0
  local avg_pressure=0
  local avg_contact=0
  local total_energy=0
  local kinetic_energy=0
  local cpu_percent=0
  local mem_mb=0

  # Extract iteration and cell count from log file
  if [[ -f "$log_file" ]]; then
    iteration=$(grep -oP 'iteration: \K[0-9]+' "$log_file" 2>/dev/null | tail -1)
    cell_count=$(grep -oP 'nb cells \K[0-9]+' "$log_file" 2>/dev/null | tail -1)

    # Set defaults if not found
    iteration=${iteration:-0}
    cell_count=${cell_count:-0}
  fi

  # Read performance_diagnostics.csv (last line)
  if [[ -f "$sim_dir/performance_diagnostics.csv" ]]; then
    local last_perf=$(tail -1 "$sim_dir/performance_diagnostics.csv")

    # Skip header line
    if [[ ! "$last_perf" =~ ^timestamp ]]; then
      # Parse CSV: timestamp,iteration,cells,divisions,cov,phase,mesh_ms,contact_ms,polar_ms,integ_ms,total_ms,imbalance_pct
      IFS=',' read -r _ perf_iter perf_cells divisions cov phase mesh_ms contact_ms polar_ms integ_ms total_ms imbalance <<< "$last_perf"

      # Use performance_diagnostics values if available
      iteration=${perf_iter:-$iteration}
      cell_count=${perf_cells:-$cell_count}
      divisions=${divisions:-0}
      cov=${cov:-0}
      phase=${phase:-"UNKNOWN"}
      mesh_ms=${mesh_ms:-0}
      contact_ms=${contact_ms:-0}
      polar_ms=${polar_ms:-0}
      integ_ms=${integ_ms:-0}
      total_ms=${total_ms:-0}
      imbalance=${imbalance:-0}
    fi
  fi

  # Read simulation_statistics.csv (aggregate last iteration's biological metrics)
  if [[ -f "$sim_dir/simulation_statistics.csv" ]] && [[ $iteration -gt 0 ]]; then
    # Extract all rows for current iteration, calculate averages
    # CSV format: iteration,cell_id,...,volume(col8),pressure(col10),contact_fraction(col11),kinetic_energy(col12),...,total_potential_energy(col17)

    avg_volume=$(awk -F',' -v iter="$iteration" '
      $1 == iter {sum+=$8; count++}
      END {if(count>0) printf "%.6e", sum/count; else print 0}
    ' "$sim_dir/simulation_statistics.csv")

    avg_pressure=$(awk -F',' -v iter="$iteration" '
      $1 == iter {sum+=$10; count++}
      END {if(count>0) printf "%.6e", sum/count; else print 0}
    ' "$sim_dir/simulation_statistics.csv")

    avg_contact=$(awk -F',' -v iter="$iteration" '
      $1 == iter {sum+=$11; count++}
      END {if(count>0) printf "%.6f", sum/count; else print 0}
    ' "$sim_dir/simulation_statistics.csv")

    total_energy=$(awk -F',' -v iter="$iteration" '
      $1 == iter {sum+=$17}
      END {printf "%.6e", sum}
    ' "$sim_dir/simulation_statistics.csv")

    kinetic_energy=$(awk -F',' -v iter="$iteration" '
      $1 == iter {sum+=$12}
      END {printf "%.6e", sum}
    ' "$sim_dir/simulation_statistics.csv")
  fi

  # Get system metrics from running process
  if kill -0 $pid 2>/dev/null; then
    cpu_percent=$(ps -p $pid -o %cpu= 2>/dev/null | awk '{print $1}')
    mem_mb=$(ps -p $pid -o rss= 2>/dev/null | awk '{print $1/1024}')

    cpu_percent=${cpu_percent:-0}
    mem_mb=${mem_mb:-0}
  fi

  # Calculate derived metrics
  local iters_per_sec=0
  if [[ $elapsed -gt 0 ]]; then
    iters_per_sec=$(awk "BEGIN {printf \"%.2f\", $iteration / $elapsed}")
  fi

  # Write to timeseries CSV
  echo "$elapsed,$iteration,$cell_count,$divisions,$iters_per_sec,$phase,$total_ms,$mesh_ms,$contact_ms,$polar_ms,$integ_ms,$cov,$imbalance,$avg_volume,$avg_pressure,$avg_contact,$total_energy,$kinetic_energy,$cpu_percent,$mem_mb" \
    >> "$output_dir/metrics/${version}_timeseries.csv"
}

# Function: initialize_timeseries_csv
# Creates CSV file with headers
# Args:
#   $1 - CSV file path
initialize_timeseries_csv() {
  local csv_file=$1

  echo "elapsed_sec,iteration,cells,divisions,iters_per_sec,phase,total_iteration_ms,mesh_ms,contact_ms,polar_ms,integ_ms,cov,thread_imbalance_pct,avg_volume,avg_pressure,avg_contact_fraction,total_energy,kinetic_energy,cpu_percent,memory_mb" \
    > "$csv_file"
}

# Function: calculate_division_rate
# Calculates divisions per minute from timeseries
# Args:
#   $1 - timeseries CSV file
#   $2 - lookback window in seconds (default 60)
calculate_division_rate() {
  local csv_file=$1
  local window=${2:-60}

  if [[ ! -f "$csv_file" ]]; then
    echo "0"
    return
  fi

  # Get last two rows and calculate division delta
  local rate=$(tail -2 "$csv_file" | awk -F',' -v window="$window" '
    NR==1 {prev_div=$4; prev_time=$1}
    NR==2 {
      time_delta = $1 - prev_time
      div_delta = $4 - prev_div
      if(time_delta > 0) {
        rate = (div_delta / time_delta) * 60
        printf "%.2f", rate
      } else {
        print 0
      }
    }
  ')

  echo "${rate:-0}"
}
