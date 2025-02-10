#!/bin/bash

ORG_ID="xxxxxxxxx"   # Replace with your actual GCP Organization ID
USER_FILE="user_list.txt"  # Input file containing list of users (one per line)
OUTPUT_FILE="iam_report_by_user.txt"

# Ensure the user file exists
if [[ ! -f "$USER_FILE" ]]; then
    echo "Error: User file '$USER_FILE' not found!"
    exit 1
fi

# Clear output file
echo "IAM Role and Permissions Report" > "$OUTPUT_FILE"

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

# Function to check IAM bindings for a given resource
fetch_iam_bindings() {
    local resource_type=$1
    local resource_id=$2
    local level_name=$3
    local user_email=$4

    local resource_name
    resource_name=$(get_resource_name "$level_name" "$resource_id")

    echo -e "\n===== $level_name: $resource_name =====" >> "$OUTPUT_FILE"

    gcloud $resource_type get-iam-policy "$resource_id" --format=json | jq -r --arg user "$user_email" '
        .bindings[] | select(.members[]? | startswith("user:'$user'")) | .role' >> "$OUTPUT_FILE"
}

# Recursive function to process all folders inside a folder
process_folders_recursively() {
    local PARENT_FOLDER_ID=$1
    local user_email=$2

    fetch_iam_bindings "resource-manager folders" "$PARENT_FOLDER_ID" "Folder" "$user_email"

    # Find subfolders and process them recursively
    for SUBFOLDER_ID in $(gcloud resource-manager folders list --folder="$PARENT_FOLDER_ID" --format="value(ID)"); do
        process_folders_recursively "$SUBFOLDER_ID" "$user_email"
    done
}

# Iterate through each user in the file
while IFS= read -r user_email; do

    echo -e "\n ####### User: $user_email #######" >> "$OUTPUT_FILE"

    # Fetch roles at the Organization level
    fetch_iam_bindings "organizations" "$ORG_ID" "Organization" "$user_email"

    # Fetch roles for all top-level folders in the Organization
    for FOLDER_ID in $(gcloud resource-manager folders list --organization="$ORG_ID" --format="value(ID)"); do
        process_folders_recursively "$FOLDER_ID" "$user_email"
    done

    # Fetch roles at the Project level
    for PROJECT_ID in $(gcloud alpha projects list --organization="$ORG_ID" --format="value(projectId)"); do
        fetch_iam_bindings "projects" "$PROJECT_ID" "Project" "$user_email"
    done
done < "$USER_FILE"

echo "IAM report saved in $OUTPUT_FILE"
