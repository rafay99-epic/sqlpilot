# shellcheck shell=bash
# Sizing SQL Server and the Docker VM from the Mac's RAM and CPUs.
# Sourced by setup.sh; defines functions only.

# Picks limits for a host with $1 GB RAM and $2 CPUs.
# Prints "<container MB> <container CPUs> <Docker VM MB>".
plan_resources() {
  local ram_gb=$1 ncpu=$2 mem cpus
  if   ((ram_gb <= 8));  then mem=$MIN_SQL_MB
  elif ((ram_gb <= 16)); then mem=4096
  elif ((ram_gb <= 32)); then mem=6144
  else                        mem=8192
  fi
  cpus=$((ncpu / 2))
  if ((cpus < 2)); then cpus=2; fi
  if ((cpus > 6)); then cpus=6; fi
  if ((ram_gb <= 8)); then cpus=2; fi
  echo "$mem $cpus $((mem + VM_OVERHEAD_MB + 256))"
}
