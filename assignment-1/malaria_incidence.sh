#!/bin/bash
DATA_FILE="incidenceOfMalaria.csv"

# Remove any bracketed text from a country name and trim trailing spaces.
normalise_country() {
    local name="$1"

    # Remove everything from the first " (" onward, if present.
    name="${name%% (*}"

    # Trim trailing spaces
    while [[ "$name" == *" " ]]; do
        name="${name% }"
    done

    echo "$name"
}

# Join array items with comma+space
join_with_comma() {
    local result=""
    local item

    for item in "$@"; do
        if [ -z "$result" ]; then
            result="$item"
        else
            result="$result, $item"
        fi
    done

    echo "$result"
}

# Basic anti-bugging checks
if [ "$#" -ne 1 ]; then
    echo "Error: Expected exactly one argument" >&2
    exit 1
fi

if [ ! -s "$DATA_FILE" ]; then
    echo "Error: The file $DATA_FILE does not exist or is empty" >&2
    exit 1
fi

query="$1"

max_value=-1
found_match=0
results=()

# Skip header row, then process each data row
tail -n +2 "$DATA_FILE" | while IFS=, read -r location indicator period tooltip
do
    country="$(normalise_country "$location")"
    year="$period"
    value="$tooltip"

    # Decide whether input is a year or a country
    if [[ "$query" =~ ^[0-9]+$ ]]; then
        if [ "$year" = "$query" ]; then
            found_match=1

            if [ "$value" -gt "$max_value" ]; then
                max_value="$value"
                results=("$country")
            elif [ "$value" -eq "$max_value" ]; then
                results+=("$country")
            fi
        fi
    else
        if [ "$country" = "$query" ]; then
            found_match=1

            if [ "$value" -gt "$max_value" ]; then
                max_value="$value"
                results=("$year")
            elif [ "$value" -eq "$max_value" ]; then
                results+=("$year")
            fi
        fi
    fi

    # Export current state so it survives the pipeline subshell
    echo "FOUND=$found_match"
    echo "MAX=$max_value"
    echo -n "RESULTS="
    join_with_comma "${results[@]}"
done > .malaria_temp_result

# Read back saved values
found_match="$(grep '^FOUND=' .malaria_temp_result | tail -n 1 | cut -d'=' -f2)"
max_value="$(grep '^MAX=' .malaria_temp_result | tail -n 1 | cut -d'=' -f2)"
result_line="$(grep '^RESULTS=' .malaria_temp_result | tail -n 1 | cut -d'=' -f2-)"

rm -f .malaria_temp_result

if [ "$found_match" != "1" ]; then
    echo "Error: No matching data found for $query" >&2
    exit 1
fi

if [[ "$query" =~ ^[0-9]+$ ]]; then
    echo "For the year $query, the highest incidence had a rate of $max_value per 1000, for the following countries: $result_line"
else
    echo "For the country $query, the highest incidence had a rate of $max_value per 1,000, for the following years: $result_line"
fi

