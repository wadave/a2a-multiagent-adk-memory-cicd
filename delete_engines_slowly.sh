#!/bin/bash
while read p; do
  echo "Deleting $p"
  curl -X DELETE -H "Authorization: Bearer $(gcloud auth print-access-token)" "https://us-central1-aiplatform.googleapis.com/v1beta1/$p?force=true"
  sleep 10
done < all_engines.txt
