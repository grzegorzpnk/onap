#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "enc_passwd.sh <branch> <os_password>"
    exit
fi

KEY="$(wget -qnv -O - https://raw.githubusercontent.com/onap/oom/$1/kubernetes/so/resources/config/mso/encryption.key)"

echo "MSO KEY: $KEY"

CMD="echo -n $2 | openssl aes-128-ecb -e -K $KEY -nosalt | xxd -c 256 -p "

ENC_KEY="$(eval  $CMD)"

echo "OS PWD: $2"
echo "OS ENC PWD: $ENC_KEY"
