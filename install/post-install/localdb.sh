# Update localdb so locate can find the installed system files immediately.
# plocate ships updatedb as a separate binary and neither it nor mlocate is in
# every base set, so no-op when it is absent.
if ! command -v updatedb >/dev/null 2>&1; then
  echo "updatedb not installed; skipping localdb refresh"
  return 0
fi

updatedb