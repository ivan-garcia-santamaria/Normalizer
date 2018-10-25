#!/bin/bash
# Update ingress with potential new host
NEW_HOST=$1
INGRESS_NAME=$2
SERVICE_NAME=$3
NAMESPACE_NAME=$4

echo "Running update-ingress for New host: $NEW_HOST, ingress: $INGRESS_NAME, service: $SERVICE_NAME"
echo " Downloading existing ingress config"
kubectl get ingress "$INGRESS_NAME" -n=$NAMESPACE_NAME -o json > original_json
existing_hosts=()
exisiting_host_names=()

echo " $ kubectl get ingress $INGRESS_NAME -n=$NAMESPACE_NAME -o json > original json && cat original_json"
cat original_json

name="$SERVICE_NAME"
potential_new_host="$NEW_HOST"
new_hosts=()

echo "Looping through json values1"
cat original_json | jq ['.spec.rules[] | .host']
for value in $(cat original_json | jq ['.spec.rules[] | .host']); 
do 
  # Replace all commas with ""
  value=${value/,/""}
  existing_host_names+=("$value")
  echo "Looping v1: value:$value"
  #printf 'Array: %s' "${existing_host_names[*]}"
done
echo "Right after values1"
i=0
for existing_host in "${existing_host_names[@]}"; do
   echo "Looping through existing host: $existing_host == $potential_new_host"
   if [[ "$existing_host" == "\"$potential_new_host\"" ]] ; then
       i=1
   fi
done
if [[ "$i" == 0 ]] ; then
    new_hosts+=("$potential_new_host")
fi

echo "Looping through json values2"
for value2 in $(cat original_json | jq ['.spec.rules[] | .']);
do
  existing_hosts+=("$value2")
  #echo "existing host! $values2"
  #printf 'Array: %s' "{existing_hosts[*]}"
done

echo "Original json"
#cat original_json

echo "Existing host names"
printf '%s\n' "${existing_host_names[@]}"
echo "New hosts"
printf '%s\n' "${new_hosts[@]}"
echo "Existing hosts before adding"
printf '%s\n' "${existing_hosts[@]}"
echo "Hosts after adding new ones"

output_json=""
for existing_host in "${existing_hosts[@]}"; do
    output_json=("$output_json$existing_host")
done

output_json=${output_json::-1}

i=0
for new_host in "${new_hosts[@]}"; do
    output_json=("$output_json,{\"host\":\"$new_host\",\"http\":{ \"paths\": [{ \"backend\":{ \"serviceName\":\"$SERVICE_NAME-laravel-web\",\"servicePort\":80} }, { \"backend\":{ \"serviceName\":\"$SERVICE_NAME-laravel-web\",\"servicePort\":443} } ]} }")
i=1
done
printf '%s]\n' "$output_json" > new_json

if [[  "$i" == 1 ]] ; then
    echo "Ingress json has changed and should be updated."
    echo "OLD:"
    cat original_json
    echo "PATCH: \"spec\": {\"rules\": $output_json]}"
    kubectl patch ingress "$INGRESS_NAME" -n=$NAMESPACE_NAME -p="\"spec\": {\"rules\": $output_json]}"
else
    echo "Ingress json has not changed and will not be updated."
fi
