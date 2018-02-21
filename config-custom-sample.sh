SSH_CMD=ssh
SCP_CMD=scp

PDF_TOOLS_VERSION="0.0.2"
PDF_TOOLS_URL="https://jurism-download.s3.amazonaws.com/pdftools/pdftools-$PDF_TOOLS_VERSION.tar.gz"

ZOTERO_SOURCE_DIR="$repo_dir"/jurism/build
SOURCE_REPO_URL="https://github.com/juris-m/zotero"
S3_BUCKET="jurism-download"

DEPLOY_HOST="our.law.nagoya-u.ac.jp"
DEPLOY_PATH="/var/www/nginx/download/client/manifests"
DEPLOY_CMD="echo WHAT NOW? SOMETHING ON ${DEPLOY_HOST}?"

BUILD_PLATFORMS=""
NUM_INCREMENTALS=6

