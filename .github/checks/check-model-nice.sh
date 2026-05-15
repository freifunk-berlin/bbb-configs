#!/bin/bash

# Check that all model files have brand_nice and model_nice set,
# with the exception of x86 models

if [ "$#" -gt 0 ]; then
	model_files=("$@")
else
	model_files=(group_vars/model_*.yml)
fi

error_found=0

for file in "${model_files[@]}"; do
	if [ ! -f "$file" ]; then
		echo "File $file does not exist, skipping."
		continue
	fi

	if [[ "$file" == *"_x86"* ]]; then
		continue
	fi

	brand_nice=$(yq -r '.brand_nice // ""' "$file" 2>/dev/null || true)
	model_nice=$(yq -r '.model_nice // ""' "$file" 2>/dev/null || true)

	if [ -z "$brand_nice" ]; then
		echo "Error: $file missing 'brand_nice'"
		error_found=1
	fi

	if [ -z "$model_nice" ]; then
		echo "Error: $file missing 'model_nice'"
		error_found=1
	fi
done

if [ "$error_found" -eq 1 ]; then
	exit 1
else
	echo "All model files have brand_nice and model_nice set"
fi
