#!/bin/sh

function validate_file_signature() {
  FILE=$1
  SIG_FILE=$2
  ALS=( -md5 -sha1 -sha256 -sha512 )
  for algorithm in $ALS; do
    digest=$(openssl dgst $algorithm $FILE | sed 's/([^)]*)//g')
    grep -Fq "$digest" $SIG_FILE || echo "Failed to validate the signature of $FILE, exit." && exit 1
  done
}

PLATFORM=$1
if [ -z "$PLATFORM" ]; then
    ARCH="amd64"
else
    case "$PLATFORM" in
        linux/386)
            ARCH="32"
            ;;
        linux/amd64)
            ARCH="64"
            ;;
        linux/arm/v6)
            ARCH="arm32-v6"
            ;;
        linux/arm/v7)
            ARCH="arm32-v7a"
            ;;
        linux/arm64|linux/arm64/v8)
            ARCH="arm64-v8a"
            ;;
        linux/ppc64le)
            ARCH="ppc64le"
            ;;
        linux/s390x)
            ARCH="s390x"
            ;;
        *)
            ARCH=""
            ;;
    esac
fi
[ -z "${ARCH}" ] && echo "Error: Not supported OS Architecture" && exit 1


ZIP_FILE="Xray-linux-${ARCH}.zip"
DGST_FILE="${ZIP_FILE}.dgst"

echo "Downloading file: ${ZIP_FILE}"

curl -fsSL "https://github.com/XTLS/Xray-core/releases/latest/download/${ZIP_FILE}" -O
if [ $? -ne 0 ]; then
    echo "Error: Failed to download zip file: ${ZIP_FILE}" && exit 1
fi

echo "Downloading file: ${DGST_FILE}"
curl -fsSL "https://github.com/XTLS/Xray-core/releases/latest/download/${DGST_FILE}" -O
if [ $? -ne 0 ]; then
    echo "Error: Failed to download signature file: ${DGST_FILE}" && exit 1
fi

validate_file_signature $ZIP_FILE $DGST_FILE

unzip -q $ZIP_FILE -d /root

chmod +x /root/xray

# Clean up
rm -rf $ZIP_FILE $DGST_FILE
