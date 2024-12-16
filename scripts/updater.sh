#!/bin/bash

# Function to update dependencies based on the backend type
update_dependencies() {
  local backend_path=$1
  local backend_type=$2

  echo "Updating dependencies for ${backend_path} (${backend_type})"

  case ${backend_type} in
    "rust")
      cd "${backend_path}" || exit 1
      cargo update
      cd - || exit 1
      ;;
    "go")
      cd "${backend_path}" || exit 1
      go get -u all
      go mod tidy
      cd - || exit 1
      ;;
    "c_sharp")
      cd "${backend_path}" || exit 1
      find . -name "*.csproj" -print0 | while IFS= read -r -d $'\0' csproj_file; do
        dotnet list "${csproj_file}" package --outdated
        #Consider adding `dotnet outdated` if you have it installed for a more advanced way to update.
        #dotnet restore "${csproj_file}" # Restore to fetch the latest versions mentioned in the .csproj
      done
      cd - || exit 1
      ;;
    "dart")
      cd "${backend_path}" || exit 1
      flutter pub upgrade --major-versions
      cd - || exit 1
      ;;
    "python")
      cd "${backend_path}" || exit 1
      # Using pip-review to update packages (install it if you don't have it: pip install pip-review)
      pip install pip-review
      pip-review --auto
      cd - || exit 1
      ;;
    "javascript")
        cd "${backend_path}" || exit 1
        npx npm-check-updates -u
        npm install
        cd - || exit 1
        ;;

    *)
      echo "Unsupported backend type: ${backend_type}"
      ;;
  esac
}

# Main script

echo "Starting dependency update process..."
cd ..
# --- Rust ---
echo "Processing Rust backends..."
find backends/rust -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d $'\0' rust_backend; do
  update_dependencies "${rust_backend}" "rust"
done

# --- Go ---
echo "Processing Go backends..."
find backends/go -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d $'\0' go_backend; do
  update_dependencies "${go_backend}" "go"
done

# --- C# ---
echo "Processing C# backends..."
update_dependencies "backends/c_sharp/dot-net" "c_sharp"

# --- Dart ---
echo "Processing Dart backends..."
find backends/dart -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d $'\0' dart_backend; do
  update_dependencies "${dart_backend}" "dart"
done

# --- Python ---
echo "Processing Python backends..."
find backends/python -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d $'\0' python_backend; do
  update_dependencies "${python_backend}" "python"
done

# --- JavaScript ---
echo "Processing JavaScript backends..."
find backends/javascript -mindepth 2 -maxdepth 2 -type d -print0 | while IFS= read -r -d $'\0' js_backend; do
  update_dependencies "${js_backend}" "javascript"
done

echo "Dependency update process completed."