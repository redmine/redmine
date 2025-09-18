#!/bin/bash
set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --zscaler-cert)
            ZSCALER_CERT="$2"
            if [[ -f "$ZSCALER_CERT" && -s "$ZSCALER_CERT" ]]; then
                cp "$ZSCALER_CERT" "$script_dir/../zscaler.crt"
                echo "✅ Zscaler cert copied to build context as zscaler.crt."
            else
                echo "⚠️  Provided Zscaler cert '$ZSCALER_CERT' is missing or empty, skipping."
            fi
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

# Check for an existing zscaler.crt in parent dir if none was provided via argument  
if [[ ! -f "$script_dir/../zscaler.crt" || ! -s "$script_dir/../zscaler.crt" ]]; then
    echo "⚠️  No valid Zscaler cert found. Building without Zscaler cert."
    # Create empty placeholder to prevent Docker COPY from failing
    touch "$script_dir/../zscaler.crt.placeholder"
else
    echo "✅ Using zscaler.crt in build context."
fi

function on_exit {
    exit_code=$?
    # Clean up placeholder file if it exists
    rm -f "$script_dir/../zscaler.crt.placeholder"
    if [ $exit_code -ne 0 ]; then
        echo "--------------------------------------------------"
        echo "⚠️  Build failed!"
        echo "If you are behind Zscaler, pass the cert with:"
        echo "    ./build.sh --zscaler-cert /path/to/zscaler.pem"
        echo "--------------------------------------------------"
    fi
}
trap on_exit EXIT

if docker inspect hillman-redmine:latest >/dev/null 2>&1; then
    docker rmi hillman-redmine:latest
fi

cd "$script_dir"/..
docker buildx build -t hillman-redmine:latest -f scripts/Dockerfile .
