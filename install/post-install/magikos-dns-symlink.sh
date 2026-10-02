# magikos-dns re-execs itself from /usr/bin/magikos-dns when elevating to root
# (the path the sudoers rule names). The package only installs the script to
# /usr/share/magikos/bin/, so without this symlink every provider change fails
# with "Error accessing /usr/bin/magikos-dns: No such file or directory".
ln -sf /usr/share/magikos/bin/magikos-dns /usr/bin/magikos-dns
