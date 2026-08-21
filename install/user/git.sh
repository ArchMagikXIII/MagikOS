# Set identification from install inputs
if [[ -n ${MAGIKOS_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$MAGIKOS_USER_NAME"
fi

if [[ -n ${MAGIKOS_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$MAGIKOS_USER_EMAIL"
fi
