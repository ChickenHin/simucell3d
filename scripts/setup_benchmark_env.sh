#!/bin/bash
# Production-ready OpenMP configuration for SimuCell3D benchmarks

# Detect physical cores (avoid hyperthreading for memory-bound workloads)
PHYSICAL_CORES=$(lscpu | grep 'Core(s) per socket' | awk '{print $4}')
SOCKETS=$(lscpu | grep 'Socket(s)' | awk '{print $2}')
TOTAL_CORES=$((PHYSICAL_CORES * SOCKETS))

echo "Detected $TOTAL_CORES physical cores ($PHYSICAL_CORES cores × $SOCKETS sockets)"

# Configure OpenMP environment
export OMP_NUM_THREADS=$TOTAL_CORES
export OMP_PROC_BIND=close        # Bind threads to adjacent cores for cache locality
export OMP_PLACES=cores            # Use physical cores (not hyperthreads)
export OMP_WAIT_POLICY=passive     # Reduce CPU spinning when idle
export OMP_DYNAMIC=false           # Disable dynamic thread adjustment

echo "OpenMP Configuration:"
echo "  OMP_NUM_THREADS=$OMP_NUM_THREADS"
echo "  OMP_PROC_BIND=$OMP_PROC_BIND"
echo "  OMP_PLACES=$OMP_PLACES"
echo "  OMP_WAIT_POLICY=$OMP_WAIT_POLICY"
echo "  OMP_DYNAMIC=$OMP_DYNAMIC"
