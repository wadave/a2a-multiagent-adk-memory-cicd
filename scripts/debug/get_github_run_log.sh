run_id=22076167324
if [ -z "$run_id" ]; then echo "run id not found"; exit 1; fi
gh run view $run_id --log-failed
