#!/bin/bash

input=$(cat)

model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.cwd // empty')

printf '%s | %s' "$model_name" "${cwd##*/}"
