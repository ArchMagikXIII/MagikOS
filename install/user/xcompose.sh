# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run magikos-restart-xcompose to apply changes

# Include fast emoji access
include "/usr/share/magikos/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$MAGIKOS_USER_NAME"
<Multi_key> <space> <e> : "$MAGIKOS_USER_EMAIL"
EOF
