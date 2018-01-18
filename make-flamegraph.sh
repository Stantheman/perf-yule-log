#!/usr/bin/bash
set -eu

if [ ! -z "${1:-}" ]; then
  flame_pid="$1"
elif [ ! -z "${FLAME_PID:-}" ]; then
  flame_pid="$FLAME_PID"
else
  echo "usage: $0 <pid to trace>"
  echo "usage: FLAME_PID=<pid to trace> $0"
  echo "FREQ, PID_SECONDS, FLAMEGRAPH_OPTIONS are available env vars"
fi

frequency="${FREQ:=997}"
pid_seconds="${PID_SECONDS:=10}"
flamegraph_options=(--title ' ' --hash --minwidth=5 --width=600 ${FLAMEGRAPH_OPTIONS:-})

now_epoch=$(date +%s)
current_pid=$$
root_directory='/var/tmp/perf-tests'
this_run_dir="${root_directory}/$now_epoch-$current_pid"
if [ ! -d "$this_run_dir" ]; then
  mkdir -p "$this_run_dir"
fi

record_output="${this_run_dir}/perf-record.out"
script_output="${this_run_dir}/perf-script.out"
collapse_output="${this_run_dir}/collapse.out"
flamegraph_output="${this_run_dir}/flamegraph.svg"
meta_output="${this_run_dir}/meta.txt"
command_output="${this_run_dir}/command.log"
exec 19>"$command_output"
export BASH_XTRACEFD=19

echoerr() { 
  echo "$@" 1>&2;
  echo "$@" >> "$meta_output"
}

echoerr "This run is recorded to $this_run_dir"
echoerr "Directory time: $(date --date=@"$now_epoch")"
echoerr "The PID being traced is: $flame_pid"
echoerr "The current PID is $current_pid"

# get N perf record output files
set -x
perf record --freq "$frequency" -g --output "$record_output" --switch-output=1s --pid="$flame_pid" -- sleep "$pid_seconds" > "$command_output" 2>&1 || true
/usr/local/perf-map-agent/bin/create-java-perf-map.sh "$flame_pid" unfoldall || echo "Not collecting java samples"
set +x

# for all those output files, get the script and collapsed scripts
for i in ${record_output}.*; do
  name=$(echo "$i" | grep -o '[0-9]*$')
  per_script_output="${this_run_dir}/perf-script-$name.out"
  per_collapse_output="${this_run_dir}/collapsed_$name.out"
  per_collapse_burn_output="${this_run_dir}/burn_collapsed_$name.json"
  per_flamegraph_output="${this_run_dir}/flamegraph_$name.svg"

  # try to generate a script and skip if it's empty
  set -x
  perf script --max-stack 32 --input "$i" > "$per_script_output"
  if [ ! -s "$per_script_output" ]; then
    continue
  fi

  stackcollapse-perf.pl --addrs < "$per_script_output" | tee "$per_collapse_output" | flamegraph.pl "${flamegraph_options[@]}" > "$per_flamegraph_output"  || true

  # same thing but json for the D3 thing
  /usr/local/burn convert --type=folded --output="$per_collapse_burn_output" "$per_collapse_output"
  set +x
done

# this is probably fine ? ordering is probs fine
# set us up for the end where we can get a single big one
set -x
cat "${this_run_dir}/perf-script-"* > "$script_output"
cat "${this_run_dir}/collapsed_"* > "$collapse_output"

stackcollapse-perf.pl "$script_output" > "$collapse_output"
flamegraph.pl  "${flamegraph_options[@]}"  "$collapse_output" > "$flamegraph_output"
set +x
