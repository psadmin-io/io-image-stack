#!/bin/bash

export MOS_USERNAME="${1:?MOS Username not set}"
export MOS_PASSWORD="${2:?MOS Password not set}"
export PATCH_ID="${3:?Patch ID not set}"

sudo yum install -y git

sudo git clone https://github.com/psadmin-io/ioco.git
python3 -m pip install ./ioco

cp ioco/examples/config.json.example ioco/config.json

sudo /usr/local/bin/ioco oci block --block-disk=/dev/sdb --block-path=/u01

tee pum.sh <<EOF
export MOS_USERNAME="${MOS_USERNAME}"
export MOS_PASSWORD="${MOS_PASSWORD}"
/usr/local/bin/ioco dpk deploy --dpk-source=MOS --dpk-patch=${PATCH_ID}
EOF

chmod +x pum.sh
sudo ./pum.sh