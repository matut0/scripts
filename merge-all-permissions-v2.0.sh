#!/bin/bash

ORG_ID="xxxxxxxxxxx"   # Replace with your actual GCP Organization ID
USER_FILE="user_list.txt"  # Input file containing list of users (one per line)
OUTPUT_FILE="iam_report_merge.txt"
TEMP_FILE="iam_temp_report.txt"

# Ensure the user file exists
if [[ ! -f "$USER_FILE" ]]; then
    echo "Error: User file '$USER_FILE' not found!"
    exit 1
fi

# Clear output files
echo "IAM Role and Permissions Report" > "$OUTPUT_FILE"
> "$TEMP_FILE"  # Empty the temp file

# Read user list into a variable (line by line)
USER_LIST=()
while IFS= read -r user; do
    USER_LIST+=("$user")
done < "$USER_FILE"

echo ${USER_LIST[@]}

# Function to fetch the full resource name with its hierarchy
get_resource_name() {
    local resource_type=$1
    local resource_id=$2
    local parent_id=""
    local display_name=""

    case $resource_type in
        "Organization")
            echo "organizations/$resource_id"
            ;;
        "Folder")
            display_name=$(gcloud resource-manager folders describe "$resource_id" --format="value(displayName)" 2>/dev/null)
            parent_id=$(gcloud resource-manager folders describe "$resource_id" --format="value(parent)" 2>/dev/null)
            [[ -z "$display_name" ]] && display_name="Folder-$resource_id"
            [[ -z "$parent_id" ]] && echo "$display_name ($resource_id)" || echo "$(get_resource_name folders ${parent_id#folders/}) > $display_name ($resource_id)"
            ;;
        "Project")
            display_name=$(gcloud projects describe "$resource_id" --format="value(name)" 2>/dev/null)
            parent_id=$(gcloud projects describe "$resource_id" --format="value(parent)" 2>/dev/null)
            [[ -z "$display_name" ]] && display_name="Project-$resource_id"
            [[ -z "$parent_id" ]] && echo "$display_name ($resource_id)" || echo "$(get_resource_name ${parent_id%%/*} ${parent_id##*/}) > $display_name ($resource_id)"
            ;;
        *)
            echo "$resource_type/$resource_id"
            ;;
    esac
}

# Function to collect IAM bindings and store them in a temp file
collect_iam_bindings() {
    local resource_type=$1
    local resource_id=$2
    local level_name=$3

    local resource_name
    resource_name=$(get_resource_name "$level_name" "$resource_id")

    gcloud $resource_type get-iam-policy "$resource_id" --format=json | jq -r '
        .bindings[] | "\(.role) \(.members | join(", "))"
    ' | while IFS= read -r line; do
        role=$(echo "$line" | awk '{print $1}')
        members=$(echo "$line" | cut -d' ' -f2-)

        # Check if any member is in the user list
        for user in "${USER_LIST[@]}"; do
            if echo "$members" | grep -qw "user:$user"; then
                #echo -e "$resource_name|$role|user:$user" >> "$TEMP_FILE"
                echo -e "$role" >> "$TEMP_FILE"
            fi
        done
    done
}

# Recursive function to process all folders inside a folder
process_folders_recursively() {
    local PARENT_FOLDER_ID=$1
    collect_iam_bindings "resource-manager folders" "$PARENT_FOLDER_ID" "Folder"

    for SUBFOLDER_ID in $(gcloud resource-manager folders list --folder="$PARENT_FOLDER_ID" --format="value(ID)"); do
        process_folders_recursively "$SUBFOLDER_ID"
    done
}

# Process organization-level IAM
collect_iam_bindings "organizations" "$ORG_ID" "Organization"

# Process all top-level folders in the Organization
for FOLDER_ID in $(gcloud resource-manager folders list --organization="$ORG_ID" --format="value(ID)"); do
    process_folders_recursively "$FOLDER_ID"
done

# Process IAM for all projects
for PROJECT_ID in $(gcloud alpha projects list --organization="$ORG_ID" --format="value(projectId)"); do
    collect_iam_bindings "projects" "$PROJECT_ID" "Project"
done

echo -e "\n===== Unique IAM Roles for the provided user list =====" >> "$OUTPUT_FILE"

# Merge and write IAM data to output file
sort "$TEMP_FILE" | uniq | while IFS='' read -r role; do
    # echo -e "$role: $members" >> "$OUTPUT_FILE"
    echo -e "$role " >> "$OUTPUT_FILE"
done

echo "IAM report saved in $OUTPUT_FILE"
# rm "$TEMP_FILE"  # Clean up temp file
