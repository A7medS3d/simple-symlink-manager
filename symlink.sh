#!/bin/bash

APP_DIR="$HOME/.symlink_manager"
PROFILE_FILE="$APP_DIR/profiles.json"

# Create app directory if not exists
mkdir -p "$APP_DIR"

# Initialize profiles JSON if missing
if [ ! -f "$PROFILE_FILE" ]; then
  echo '{"LastProfile":"","Profiles":{}}' > "$PROFILE_FILE"
fi

# Load profiles JSON
load_profiles() {
  PROFILES_JSON=$(cat "$PROFILE_FILE")
}

# Save profiles JSON
save_profiles() {
  echo "$PROFILES_JSON" > "$PROFILE_FILE"
}

show_info() {
  zenity --info --title="Info" --text="$1"
}

show_error() {
  zenity --error --title="Error" --text="$1"
}

select_profile() {
  local keys
  keys=($(echo "$PROFILES_JSON" | jq -r '.Profiles | keys[]'))
  if [ ${#keys[@]} -eq 0 ]; then
    show_info "No profiles available."
    echo ""
    return
  fi
  zenity --list --title="Select Profile" --text="Choose a profile:" --column="Profile" "${keys[@]}"
}

edit_profile() {
  local edit_name="$1"
  local is_edit=0
  local source_dir=""
  local target_dir=""
  if [ -n "$edit_name" ]; then
    is_edit=1
    source_dir=$(echo "$PROFILES_JSON" | jq -r --arg p "$edit_name" '.Profiles[$p].Source')
    target_dir=$(echo "$PROFILES_JSON" | jq -r --arg p "$edit_name" '.Profiles[$p].Target')
  fi

  local name
  name=$(zenity --entry --title="$([ $is_edit -eq 1 ] && echo 'Edit Profile' || echo 'New Profile')" --text="Profile name:" --entry-text="$edit_name")
  [ -z "$name" ] && return 1

  local source
  source=$(zenity --file-selection --directory --title="Select Source Directory" --filename="$source_dir/")
  [ -z "$source" ] && return 1

  local target
  target=$(zenity --file-selection --directory --title="Select Target Directory" --filename="$target_dir/")
  [ -z "$target" ] && return 1

  # Validate directories
  if [ ! -d "$source" ]; then
    show_error "Source directory does not exist."
    return 1
  fi
  if [ ! -d "$target" ]; then
    show_error "Target directory does not exist."
    return 1
  fi

  # Update profiles JSON
  load_profiles

  if [ $is_edit -eq 1 ] && [ "$name" != "$edit_name" ]; then
    # Remove old profile name if changed
    PROFILES_JSON=$(echo "$PROFILES_JSON" | jq --arg p "$edit_name" 'del(.Profiles[$p])')
  fi

  PROFILES_JSON=$(echo "$PROFILES_JSON" | jq --arg p "$name" --arg s "$source" --arg t "$target" \
    '.Profiles[$p] = {Source:$s, Target:$t} | .LastProfile = $p')

  save_profiles

  show_info "Profile saved."
  return 0
}

delete_profile() {
  local profile="$1"
  load_profiles
  PROFILES_JSON=$(echo "$PROFILES_JSON" | jq --arg p "$profile" 'del(.Profiles[$p])')
  PROFILES_JSON=$(echo "$PROFILES_JSON" | jq '.LastProfile=""')
  save_profiles
  show_info "Profile '$profile' deleted."
}

create_symlinks() {
  local source_dir="$1"
  local target_dir="$2"

  if [ ! -d "$source_dir" ]; then
    show_error "Source directory does not exist."
    return 1
  fi
  if [ ! -d "$target_dir" ]; then
    show_error "Target directory does not exist."
    return 1
  fi

  # List all items in source directory
  local items=()
  while IFS= read -r -d '' item; do
    items+=("$item")
  done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -print0 | sort -z)

  if [ ${#items[@]} -eq 0 ]; then
    show_info "Source directory is empty."
    return 1
  fi

  # Prepare checklist for zenity
  local checklist=()
  for item in "${items[@]}"; do
    baseitem=$(basename "$item")
    checklist+=(TRUE "$baseitem")
  done

  local selected
  selected=$(zenity --list --checklist --title="Select Items" --text="Select items to create symlinks for:" --column="Select" --column="Item" "${checklist[@]}" --height=500 --width=600)
  [ $? -ne 0 ] && return 1
  if [ -z "$selected" ]; then
    show_info "No items selected."
    return 1
  fi

  # Process selected items
  IFS="|" read -r -a selected_items <<< "$selected"

  # Confirm creation
  zenity --question --title="Confirm Symlink Creation" --text="Create ${#selected_items[@]} symlinks from:\n$source_dir\nto:\n$target_dir?"
  if [ $? -ne 0 ]; then
    return 1
  fi

  local count=0
  for sel in "${selected_items[@]}"; do
    src="$source_dir/$sel"
    dest="$target_dir/$sel"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
      rm -rf "$dest"
    fi

    ln -s "$src" "$dest" && ((count++))
  done

  show_info "Created $count symlink(s)."
  return 0
}

delete_symlinks_in_target() {
  local profile_name="$1"
  local target_dir=$(echo "$PROFILES_JSON" | jq -r --arg p "$profile_name" '.Profiles[$p].Target')

  if [ ! -d "$target_dir" ]; then
    show_error "Target directory does not exist."
    return
  fi

  mapfile -t symlinks < <(find "$target_dir" -maxdepth 1 -type l -printf "%f\n" | sort)

  if [ ${#symlinks[@]} -eq 0 ]; then
    show_info "No symlinks found in target directory."
    return
  fi

  # Ask if user wants to delete all symlinks or select specific ones
  local choice
  choice=$(zenity --list --radiolist --title="Delete Symlinks" --text="Choose deletion mode:" \
    --column "Select" --column "Option" \
    TRUE "Delete All Symlinks" FALSE "Select Symlinks Individually" --height=150 --width=400)

  if [ "$choice" = "Delete All Symlinks" ]; then
    # Confirm delete all
    if zenity --question --title="Confirm Delete All" --text="Are you sure you want to delete ALL symlinks in $target_dir?"; then
      local deleted=0
      for link in "${symlinks[@]}"; do
        rm -f "$target_dir/$link" && ((deleted++))
      done
      show_info "Deleted all $deleted symlink(s)."
    else
      show_info "Deletion cancelled."
    fi
  elif [ "$choice" = "Select Symlinks Individually" ]; then
    # Build checklist options
    local checklist=()
    for link in "${symlinks[@]}"; do
      checklist+=(FALSE "$link")
    done

    selected=$(zenity --list --checklist --title="Delete Symlinks" --text="Select symlinks to delete:" --column="Select" --column="Symlink" "${checklist[@]}" --height=400 --width=500)
    [ $? -ne 0 ] && return

    IFS="|" read -r -a to_delete <<< "$selected"
    if [ ${#to_delete[@]} -eq 0 ]; then
      show_info "No symlinks selected."
      return
    fi

    # Confirm delete selected
    if zenity --question --title="Confirm Delete" --text="Delete selected symlinks?"; then
      local deleted=0
      for link in "${to_delete[@]}"; do
        rm -f "$target_dir/$link" && ((deleted++))
      done
      show_info "Deleted $deleted symlink(s)."
    else
      show_info "Deletion cancelled."
    fi
  else
    # User canceled the choice dialog
    return
  fi
}



main_menu() {
  while true; do
    load_profiles

    # Build profile list for zenity menu
    local keys
    keys=($(echo "$PROFILES_JSON" | jq -r '.Profiles | keys[]'))
    local options=()
    for k in "${keys[@]}"; do
      options+=("$k" "")
    done

    # Add action options
    options+=("➕ New Profile" "")
    options+=("✏️ Edit Profile" "")
    options+=("❌ Delete Profile" "")
    options+=("🗑️ Delete Symlinks" "")
    options+=("🚪 Exit" "")

    action=$(zenity --list --title="Symlink Manager" --text="Select a profile or action:" --column="Option" --height=500 --width=400 "${options[@]}")

    [ -z "$action" ] && exit 0

    case "$action" in
      "➕ New Profile")
        edit_profile "" || true
        ;;
      "✏️ Edit Profile")
        selected=$(select_profile)
        if [ -n "$selected" ]; then
          edit_profile "$selected" || true
        fi
        ;;
      "❌ Delete Profile")
        selected=$(select_profile)
        if [ -n "$selected" ]; then
          zenity --question --title="Confirm Delete" --text="Are you sure you want to delete the profile '$selected'?"
          if [ $? -eq 0 ]; then
            delete_profile "$selected"
          fi
        fi
        ;;
      "🗑️ Delete Symlinks")
        selected=$(select_profile)
        if [ -n "$selected" ]; then
          delete_symlinks_in_target "$selected"
        fi
        ;;
      "🚪 Exit")
        exit 0
        ;;
      *)
        # Assume profile selected - validate and run symlink creation
        profile="$action"
        source_dir=$(echo "$PROFILES_JSON" | jq -r --arg p "$profile" '.Profiles[$p].Source')
        target_dir=$(echo "$PROFILES_JSON" | jq -r --arg p "$profile" '.Profiles[$p].Target')
        if [ -d "$source_dir" ] && [ -d "$target_dir" ]; then
          create_symlinks "$source_dir" "$target_dir"
        else
          show_error "Invalid profile directories."
        fi
        ;;
    esac
  done
}

# Start the app
main_menu
