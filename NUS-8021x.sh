#!/bin/bash
##
## NUS 802.1X configuration script
## Last updated by Christopher Lim on 30 Oct 2019
##


TITLE="NUS Wired 802.1X"
PROFILE_NAME=NUS
CA_CERT_URL=https://dl.cacerts.digicert.com/DigiCertGlobalRootCA.crt
CA_CERT_PATH=/etc/nus
CA_CERT_FILE=8021x-wired.crt


# Check for root privilege and necessary commands
[ "$EUID" -eq 0 ] || { echo "Please run with root privileges."; exit 1; }

command -v nmcli > /dev/null 2>&1 
[ $? -eq 0 ] || { echo "nmcli not found. NetworkManager required."; exit 1; }

command -v openssl > /dev/null 2>&1 
[ $? -eq 0 ] || { echo "openssl not found."; exit 1; }

whiptail --title "${TITLE}" --yesno "This will configure your system for NUS Wired 802.1X. Proceed?" 8 70
[ $? -eq 0 ] || { echo "Configuration cancelled"; exit 2; }


# Prompt user for inputs
IFACE=$(whiptail --title "${TITLE}" --menu "Select interface to configure." 15 70 5 `nmcli device | tail -n+2 | grep ethernet | awk '{print $1, $2}'` --nocancel --noitem 3>&1 1>&2 2>&3)
USER=$(whiptail --title "${TITLE}" --inputbox "Provide your NUSNET Username for authentication to NUS Wired network." 9 70 "nusstf\\" --nocancel 3>&1 1>&2 2>&3)
PASS=$(whiptail --title "${TITLE}" --passwordbox "Provide ${USER} password for authentication to NUS Wired network." 8 70 --nocancel 3>&1 1>&2 2>&3)


# Download CA Cert
echo "Downloading CA Cert..."
mkdir -p "${CA_CERT_PATH}"
curl -s "${CA_CERT_URL}" -o "${CA_CERT_PATH}/${CA_CERT_FILE}"
if [ $? -ne 0 ]
then
	echo "Unable to download from ${CA_CERT_URL}"
	echo "Using stored DigiCertGlobalRootCA.crt"
	openssl base64 -d <<- 'EOF' > "${CA_CERT_PATH}/${CA_CERT_FILE}"
	MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBhMQswCQYDVQQG
	EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSAw
	HgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBDQTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAw
	MDAwMDBaMGExCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
	dy5kaWdpY2VydC5jb20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkq
	hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsBCSDMAZOn
	TjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97nh6Vfe63SKMI2tavegw5
	BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt43C/dxC//AH2hdmoRBBYMql1GNXRor5H
	4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7PT19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y
	7vrTC0LUq7dBMtoM1O/4gdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQAB
	o2MwYTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbRTLtm
	8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUwDQYJKoZIhvcNAQEF
	BQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/EsrhMAtudXH/vTBH1jLuG2cenTnmCmr
	EbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIt
	tep3Sp+dWOIrWcBAI+0tKIJFPnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886
	UAb3LujEV0lsYSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk
	CAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
	EOF
fi

chmod 755 "${CA_CERT_PATH}"
chmod 644 "${CA_CERT_PATH}/${CA_CERT_FILE}"
chown -R root:root "${CA_CERT_PATH}"


# Configure connection profile
echo "Configuring connection profile..."
nmcli connection show "${PROFILE_NAME}" 2>/dev/null >/dev/null
[ $? -eq 0 ] && { echo "Deleting old connection profile..."; nmcli connection delete "${PROFILE_NAME}" >/dev/null; }

nmcli connection add con-name "${PROFILE_NAME}" \
	ifname "${IFACE}" \
	type 802-3-ethernet \
	802-1x.eap peap \
	802-1x.phase2-auth mschapv2 \
	802-1x.ca-cert "${CA_CERT_PATH}/${CA_CERT_FILE}" \
	802-1x.identity "${USER}" \
	802-1x.password "${PASS}"


# Enable connection profile
echo "Reconnecting ${IFACE}..."
nmcli -t -f GENERAL.STATE device show "${IFACE}" | grep "(connected)" >/dev/null
[ $? -eq 0 ] && nmcli device disconnect "${IFACE}"
nmcli device connect "${IFACE}"

echo "Enabling NUS 802.1X connection..."
nmcli connection up "${PROFILE_NAME}" 2>/dev/null
