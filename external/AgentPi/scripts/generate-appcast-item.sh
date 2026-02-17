#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --version <x.y.z> --signature <edSignature> --length <bytes> [options]

Required:
  --version              Release version, e.g. 1.0.4
  --signature            Sparkle EdDSA signature (sparkle:edSignature value)
  --length               AgentPi.app.zip size in bytes

Optional:
  --repo                 GitHub repo (default: Cz07cring/agentpi)
  --pub-date             RFC822 pub date (default: current UTC)
  --min-system-version   Sparkle minimum system version (default: 14.0)
USAGE
}

VERSION=""
SIGNATURE=""
LENGTH=""
REPO="Cz07cring/agentpi"
MIN_SYSTEM_VERSION="14.0"
PUB_DATE="$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S %z")"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --signature)
      SIGNATURE="$2"
      shift 2
      ;;
    --length)
      LENGTH="$2"
      shift 2
      ;;
    --repo)
      REPO="$2"
      shift 2
      ;;
    --pub-date)
      PUB_DATE="$2"
      shift 2
      ;;
    --min-system-version)
      MIN_SYSTEM_VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$SIGNATURE" || -z "$LENGTH" ]]; then
  echo "ERROR: --version, --signature and --length are required." >&2
  usage
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: invalid --version '$VERSION'. Expected semantic version x.y.z" >&2
  exit 1
fi

if [[ ! "$LENGTH" =~ ^[0-9]+$ ]]; then
  echo "ERROR: invalid --length '$LENGTH'. Must be numeric bytes." >&2
  exit 1
fi

cat <<XML
    <item>
      <title>Version ${VERSION}</title>
      <link>https://github.com/${REPO}/releases/tag/v${VERSION}</link>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description><![CDATA[
        <h2>Version ${VERSION}</h2>
        <ul>
          <li>See release notes on GitHub</li>
        </ul>
      ]]></description>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure
        url="https://github.com/${REPO}/releases/download/v${VERSION}/AgentPi.app.zip"
        sparkle:version="${VERSION}"
        sparkle:shortVersionString="${VERSION}"
        sparkle:edSignature="${SIGNATURE}"
        length="${LENGTH}"
        type="application/octet-stream" />
      <sparkle:minimumSystemVersion>${MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
    </item>
XML
