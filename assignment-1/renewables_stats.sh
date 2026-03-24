#!/bin/bash
to_comparable_number() {
    local value="$1"
    local whole
    local fraction

    if [[ "$value" == *.* ]]; then
        whole="${value%%.*}"
        fraction="${value#*.}"
    else
        whole="$value"
        fraction=""
    fi

    while [ "${#fraction}" -lt 4 ]; do
        fraction="${fraction}0"
    done

    fraction="${fraction:0:4}"
    echo "${whole}${fraction}"
}

if [ "$#" -ne 4 ]; then
    echo "Error: Expected exactly 4 arguments" >&2
    exit 1
fi

input_file="$1"
query="$2"
energy_type="$3"
operation="$4"

if [ ! -s "$input_file" ]; then
    echo "Error: The specified input file $input_file does not exist or is empty" >&2
    exit 1
fi

if [ "$energy_type" != "solar_wind" ] && [ "$energy_type" != "coal" ]; then
    echo "Error: Unknown energy source $energy_type. Expected 'solar_wind' or 'coal'" >&2
    exit 1
fi

if [ "$operation" != "min" ] && [ "$operation" != "max" ]; then
    echo "Error: Unknown operations $operation. Expected 'min' or 'max'" >&2
    exit 1
fi

is_year=0
is_code=0

if [[ "$query" =~ ^[0-9]{4}$ ]]; then
    is_year=1
elif [[ "$query" =~ ^[A-Z]{3}$ ]]; then
    is_code=1
else
    echo "Error: The second argument must be either a four-digit year or a three-letter ISO country code" >&2
    exit 1
fi

best_value=""
best_value_cmp=""
best_country=""
best_code=""
best_year=""
found_match=0

tail -n +2 "$input_file" |
while IFS=, read -r country code year solar_wind_value coal_value
do
    if [ "$energy_type" = "solar_wind" ]; then
        current_value="$solar_wind_value"
        energy_label="solar and wind"
    else
        current_value="$coal_value"
        energy_label="coal"
    fi

    match=0

    if [ "$is_year" -eq 1 ] && [ "$year" = "$query" ]; then
        match=1
    fi

    if [ "$is_code" -eq 1 ] && [ "$code" = "$query" ]; then
        match=1
    fi

    if [ "$match" -eq 1 ]; then
        found_match=1
        current_cmp="$(to_comparable_number "$current_value")"

        if [ -z "$best_value" ]; then
            best_value="$current_value"
            best_value_cmp="$current_cmp"
            best_country="$country"
            best_code="$code"
            best_year="$year"
        else
            should_replace=0

            if [ "$operation" = "max" ] && [ "$current_cmp" -gt "$best_value_cmp" ]; then
                should_replace=1
            fi

            if [ "$operation" = "min" ] && [ "$current_cmp" -lt "$best_value_cmp" ]; then
                should_replace=1
            fi

            if [ "$should_replace" -eq 1 ]; then
                best_value="$current_value"
                best_value_cmp="$current_cmp"
                best_country="$country"
                best_code="$code"
                best_year="$year"
            fi
        fi
    fi

    echo "FOUND=$found_match"
    echo "BEST_VALUE=$best_value"
    echo "BEST_VALUE_CMP=$best_value_cmp"
    echo "BEST_COUNTRY=$best_country"
    echo "BEST_CODE=$best_code"
    echo "BEST_YEAR=$best_year"
    echo "ENERGY_LABEL=$energy_label"
done > .renewables_temp_result

found_match="$(grep '^FOUND=' .renewables_temp_result | tail -n 1 | cut -d'=' -f2)"
best_value="$(grep '^BEST_VALUE=' .renewables_temp_result | tail -n 1 | cut -d'=' -f2-)"
best_country="$(grep '^BEST_COUNTRY=' .renewables_temp_result | tail -n 1 | cut -d'=' -f2-)"
best_code="$(grep '^BEST_CODE=' .renewables_temp_result | tail -n 1 | cut -d'=' -f2-)"
best_year="$(grep '^BEST_YEAR=' .renewables_temp_result | tail -n 1 | cut -d'=' -f2-)"
energy_label="$(grep '^ENERGY_LABEL=' .renewables_temp_result | tail -n 1 | cut -d'=' -f2-)"

rm -f .renewables_temp_result

if [ "$found_match" != "1" ]; then
    echo "Error: No matching data found for $query" >&2
    exit 1
fi

if [ "$operation" = "max" ]; then
    operation_word="maximum"
else
    operation_word="minimum"
fi

if [ "$is_year" -eq 1 ]; then
    echo "The $operation_word amount of electrical energy produced from $energy_label in $query was $best_value TWh by $best_country ($best_code)"
else
    echo "The $operation_word amount of electrical energy produced from $energy_label for $best_country ($best_code) was $best_value TWh in $best_year"
fi
