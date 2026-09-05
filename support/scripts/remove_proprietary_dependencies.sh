#!/bin/sh

# This script removes proprietary dependencies from the project.
#
# Portable across GNU sed (Linux runners) and BSD sed (macOS runners): the
# two have incompatible `sed -i` syntax, so every edit goes through a temp
# file instead.

set -e

cd app

# Portable in-place edit: `sed -i 'script' file` differs between GNU and BSD.
sed_inplace() {
  script=$1
  file=$2
  sed "$script" "$file" >"$file.tmp"
  mv "$file.tmp" "$file"
}

REGEX_A='s|// \[FOSS_REMOVE_START\]|/*|'
REGEX_B='s|// \[FOSS_REMOVE_END\]|*/|'

# Remove lines from pubspec.yaml
sed_inplace '/# \[FOSS_REMOVE\]/d' pubspec.yaml

# Comment out parts in Dart files
sed_inplace "$REGEX_A" lib/config/init.dart
sed_inplace "$REGEX_B" lib/config/init.dart

sed_inplace "$REGEX_A" lib/pages/donation/donation_page.dart
sed_inplace "$REGEX_B" lib/pages/donation/donation_page.dart

sed_inplace "$REGEX_A" lib/pages/donation/donation_page_vm.dart
sed_inplace "$REGEX_B" lib/pages/donation/donation_page_vm.dart

# Remove files completely
rm lib/provider/purchase_provider.dart

# Refer to donationPageNoopVmProvider instead of donationPageVmProvider
sed_inplace 's/donationPageVmProvider/donationPageNoopVmProvider/g' lib/pages/donation/donation_page.dart

cd ..
echo "Proprietary dependencies removed."
