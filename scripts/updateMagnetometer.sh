#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/magnetometer-env.sh"
REPOSITORY=${MAGNETOMETER_GITHUB_REPOSITORY:-UKradioastro/UKRAA_Magnetometer}
WORK_DIR=$(mktemp -d)
SCRIPT_COPY="$WORK_DIR/updateMagnetometer.sh"

cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
	echo "Please run this updater with sudo."
	exit 1
fi
if [ "$FILE_OWNER" = root ] || [ "$(stat -c %U "$BASE_PATH")" != "$FILE_OWNER" ]; then
	echo "Specify the account that owns $BASE_PATH with MAGNETOMETER_FILE_OWNER." >&2
	exit 1
fi

if [ "${1:-}" = "--run-installer" ]; then
	bash "$BASE_PATH/install/install.sh"
	/bin/bash "$BASE_PATH/scripts/runPostUpdateChecks.sh"
	exit $?
fi

if [ ! -d "$BASE_PATH/scripts" ]; then
	echo "Installation not found: $BASE_PATH/scripts"
	exit 1
fi

cp "$0" "$SCRIPT_COPY"
chmod 700 "$SCRIPT_COPY"

release_json=$(curl -fsSL -H 'Accept: application/vnd.github+json' \
	"https://api.github.com/repos/$REPOSITORY/releases/latest")
release_info=$(printf '%s' "$release_json" | /usr/bin/python3 -c '
import json
import sys

release = json.load(sys.stdin)
print(release["tag_name"])
')
release_tag=$(printf '%s\n' "$release_info" | sed -n '1p')
archive_url="https://github.com/$REPOSITORY/archive/refs/tags/$release_tag.zip"

if [ -z "$release_tag" ]; then
	echo "GitHub latest release did not provide a tag."
	exit 1
fi

current_version=$(tr -d '[:space:]' < "$BASE_PATH/VERSION" 2>/dev/null || true)
if [ "$current_version" = "$release_tag" ]; then
	echo "UKRAA Magnetometer is already up to date at $current_version."
	exit 0
fi

archive_path="$WORK_DIR/release.zip"
echo "Downloading UKRAA Magnetometer $release_tag..."
curl -fL --retry 3 -o "$archive_path" "$archive_url"
unzip -q "$archive_path" -d "$WORK_DIR"

source_dir=$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d ! -name '.*' | head -n 1)
if [ -z "$source_dir" ] || [ ! -f "$source_dir/VERSION" ] || [ ! -f "$source_dir/install/install.sh" ]; then
	echo "Downloaded archive does not contain a valid UKRAA Magnetometer release."
	exit 1
fi

downloaded_version=$(tr -d '[:space:]' < "$source_dir/VERSION")
if [ "$downloaded_version" != "$release_tag" ]; then
	echo "Release tag $release_tag does not match VERSION $downloaded_version."
	exit 1
fi

echo "Updating code from $current_version to $downloaded_version..."
for path in scripts install WWW docs images README.md VERSION CHANGELOG.md LICENSE; do
	if [ -e "$source_dir/$path" ]; then
		if [ -d "$source_dir/$path" ]; then
			install -d -o "$FILE_OWNER" -g "$FILE_GROUP" "$BASE_PATH/$path"
			cp -a "$source_dir/$path/." "$BASE_PATH/$path/"
			chown -R "$FILE_OWNER:$FILE_GROUP" "$BASE_PATH/$path"
		else
			install -o "$FILE_OWNER" -g "$FILE_GROUP" -m 644 "$source_dir/$path" "$BASE_PATH/$path"
		fi
	fi
done

echo "Running installer for $downloaded_version..."
bash "$SCRIPT_COPY" --run-installer