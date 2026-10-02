#!/usr/bin/env bash

script_cmdline() {
    local param
    for param in $(</proc/cmdline); do
        case "${param}" in
            script=*)
                echo "${param#*=}"
                return 0
                ;;
        esac
    done
}

automated_script() {
    local script rt
    script="$(script_cmdline)"
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script}" =~ ^((http|https|ftp|tftp)://) ]]; then
            printf '%s: downloading %s\n' "$0" "${script}"
            systemd-run --pty --quiet -p Wants=network-online.target -p After=network-online.target \
                curl "${script}" --location --retry-connrefused --retry 10 --fail -s -o /tmp/startup_script
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            printf '%s: executing automated script\n' "$0"
            /tmp/startup_script
        fi
        return 0
    fi

    # No script= directive: treat the first tty1 shell as the installer boot
    # (the Omarchy-style flow). Launch the gum configurator, which collects the
    # install intents and hands off to magikos-install. Skip on smoke-test
    # builds, which drive the installer over the serial console instead.
    if [[ -e /opt/magikos-smoke.sh ]]; then
        return 0
    fi
    if [[ -x /root/magikos/installer/configurator ]]; then
        printf '%s: starting MagikOS configurator\n' "$0"
        /root/magikos/installer/configurator
        printf '%s: configurator exited; returning to shell\n' "$0"
    fi
}

if [[ $(tty) == "/dev/tty1" ]]; then
    automated_script
fi