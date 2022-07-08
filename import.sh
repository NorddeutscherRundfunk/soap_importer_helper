#!/bin/bash
# Sophora SOAP-Importer-Helper
# ----------------------------
# Takes NIMEX formatted XML file and imports it into Sophora CMS using Sophora's own SOAP importer.
# Details can be controlled by means of a special context config file.
# In practice, the config file hast to be filled in most likely on a case by case base
# (that is, there will be no ONE config file that fits all situations).
#
# Version: 0.3
#
# Usage: See readme.md


# Settings basic variables
# ------------------------
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"

SESSIONS_DIR="${SCRIPT_PATH}/sessions"
# Do not confuse this "SESSIONS_DIR" (plural) with "SESSION_DIR" (singular)!
# The "SESSIONS_DIR" contains separate directories for each run of `import.sh`.
# These separate directories under "SESSIONS_DIR" are called "session directories".
# Therefore the directory for a specific session is referred to by "SESSION_DIR" (singular).

EXPECTED_NUMBER_OF_PARAMETERS=4
DEBUG="false"
#DEBUG="true"

# Error codes
ERR_PARAMETER_NUMBER_WRONG=10
ERR_CONTEXT_CONFIG_FILE_NOT_FOUND=20
ERR_SESSION_DIR_COULD_NOT_BE_CREATED=30
ERR_NIMEX_INPUT_CANNOT_DETERMINE_INPUT_TYPE=40
ERR_NIMEX_FILE_CONTAINS_CDATA=50
ERR_NIMEX_FILE_MISSING=60
ERR_IMPORTER_CONFIG_FILE_NOT_FOUND=70
ERR_CURL_NETRC_FILE_NOT_FOUND=80
ERR_CURL_CONFIG_FILE_NOT_FOUND=90
ERR_SOAP_ENVELOPE_FILE_NOT_FOUND=100



# Read and process command line parameters
# ----------------------------------------
# Check number of arguments
if [ $# -ne $EXPECTED_NUMBER_OF_PARAMETERS ]
then
	echo "ERROR: Script must be called with $EXPECTED_NUMBER_OF_PARAMETERS parameters"
	echo "See readme.md for further information"
	exit $ERR_PARAMETER_NUMBER_WRONG
fi

# 1) NIMEX input
NIMEX_INPUT="$1"
echo "NIMEX_INPUT = ${NIMEX_INPUT}"
if [ "${NIMEX_INPUT:0:8}" == "https://" ] || [ "${NIMEX_INPUT:0:7}" == "http://" ]
then
	echo "Assuming NIMEX_INPUT is a URL"
	NIMEX_INPUT_TYPE="url"
else
	echo "Assuming NIMEX_INPUT is a regular file"
	NIMEX_INPUT_TYPE="file"
fi

# 2) Context
CONTEXT="$2"
echo "CONTEXT = ${CONTEXT}"

# 3) CMS
CMS="$3"
echo "CMS = ${CMS}"

# 4) Importer instance
ENVIRONMENT="$4"
echo "ENVIRONMENT = ${ENVIRONMENT}"



# Check if config file can be read
# --------------------------------
CONTEXT_CONFIG_FILE="${SCRIPT_PATH}/config/context/${CONTEXT}/config.cfg"
if [ -f "${CONTEXT_CONFIG_FILE}" ]
then
	echo "CONTEXT_CONFIG_FILE = ${CONTEXT_CONFIG_FILE}"
	source "${CONTEXT_CONFIG_FILE}"
else
	echo "ERROR: Configuration file '$CONTEXT_CONFIG_FILE' not found"
	echo "Aborting"
	exit $ERR_CONTEXT_CONFIG_FILE_NOT_FOUND
fi


# Create session directory
# ------------------------
TIMESTAMP_FILESYSTEM=$(date '+%Y-%m-%d_%H%M%S')
SESSION_DIR="${SESSIONS_DIR}/${CONTEXT}/${TIMESTAMP_FILESYSTEM}"
mkdir -p "${SESSION_DIR}"
if [ -d "${SESSION_DIR}" ]
then
	echo "SESSION_DIR = ${SESSION_DIR}"
else
	echo "ERROR Session directory could not be created: ${SESSION_DIR}"
	echo "Aborting"
	exit $ERR_SESSION_DIR_COULD_NOT_BE_CREATED
fi



# Copy NIMEX source file to sessions directory for archiving purposes
# -------------------------------------------------------------------
# Set VPN proxy
source "${SCRIPT_PATH}/config/set_vpn_proxy.sh"

NIMEX_FILE="${SESSION_DIR}/nimex_input.xml"
echo "NIMEX_FILE = ${NIMEX_FILE}"

echo "NIMEX_INPUT = ${NIMEX_INPUT}" > "${SESSION_DIR}/run.log"

if [ "${NIMEX_INPUT_TYPE}" == "file" ]
then
	# Case 1: NIMEX_INPUT is a file
	cp "${NIMEX_INPUT}" "${NIMEX_FILE}"
elif [ "${NIMEX_INPUT_TYPE}" == "url" ]
then
	# Case 2: NIMEX_INPUT is a URL
	if [ $DEBUG == "true" ]
	then
		$(which curl) -v "${NIMEX_INPUT}" -o "${NIMEX_FILE}"
	else 
		$(which curl) -s "${NIMEX_INPUT}" -o "${NIMEX_FILE}"
	fi
else
	echo "ERROR: Can't decide wether type of NIMEX input is URL or file."
	echo "Aborting"
	exit $ERR_NIMEX_INPUT_CANNOT_DETERMINE_INPUT_TYPE
fi

# Check if download / copying was successful
if [ ! -f "${NIMEX_FILE}" ]
then
	echo "ERROR: Downloading or copying NIMEX file failed. Missing file: ${NIMEX_FILE}"
	echo "Aborting"
	exit $ERR_NIMEX_FILE_MISSING
fi



# Ensure that NIMEX_FILE does not contain CDATA
# ---------------------------------------------
grep CDATA "${NIMEX_FILE}"
GREP_RETURN_CODE=$?
if [ "$GREP_RETURN_CODE" == "0" ]
then
	echo "ERROR: NIMEX file contains CDATA statement. NIMEX file not suited for import."
	echo "Aborting"
	exit $ERR_NIMEX_FILE_CONTAINS_CDATA
fi



# Create SOAP envelope
# --------------------
SOAP_ENVELOPE_HEADER="${SCRIPT_PATH}/config/context/${CONTEXT}/templates/soap_envelope/header.xml"
SOAP_ENVELOPE_FOOTER="${SCRIPT_PATH}/config/context/${CONTEXT}/templates/soap_envelope/footer.xml"


# Glue header, contents and footer together
SOAP_ENVELOPE_TMP="${SESSION_DIR}/soap_envelope_tmp.xml"
cat "${SOAP_ENVELOPE_HEADER}" "${NIMEX_FILE}" "${SOAP_ENVELOPE_FOOTER}" > "${SOAP_ENVELOPE_TMP}"
echo "SOAP_ENVELOPE_TMP = ${SOAP_ENVELOPE_TMP}"

SOAP_ENVELOPE="${SESSION_DIR}/soap_envelope.xml"
TIMESTAMP_TIME=$(date '+%H:%M Uhr')
TIMESTAMP_DATE_AND_TIME=$(date '+%d.%m.%Y %H:%M Uhr')

# 2. Replace placeholders in SOAP_ENVELOPE
cp "${SOAP_ENVELOPE_TMP}" "${SOAP_ENVELOPE}"
sed -i '' "s/PLACEHOLDER-TIMESTAMP-TIME/${TIMESTAMP_TIME}/g" "${SOAP_ENVELOPE}"
sed -i '' "s/PLACEHOLDER-TIMESTAMP-DATE-AND-TIME/${TIMESTAMP_DATE_AND_TIME}/g" "${SOAP_ENVELOPE}"

if [ -f "${SOAP_ENVELOPE}" ]
then
	echo "SOAP_ENVELOPE = ${SOAP_ENVELOPE}"
else
	echo "ERROR: SOAP envelope does not exist: ${SOAP_ENVELOPE}"
	echo "Aborting"
	exit $ERR_SOAP_ENVELOPE_FILE_NOT_FOUND
fi

if [ $DEBUG != "true" ]
then
	rm "${SOAP_ENVELOPE_TMP}"
fi


# Create `.netrc` file
# --------------------
# Use information in `config/importer/<CMS>_<ENVIRONMENT>.cfg` to
# automatically create `.netrc` file for curl to connect to importer
IMPORTER_CONFIG_FILE="${SCRIPT_PATH}/config/importer/${CMS}_${ENVIRONMENT}.cfg"
echo "IMPORTER_CONFIG_FILE = ${IMPORTER_CONFIG_FILE}"

CURL_NETRC_FILE="${SCRIPT_PATH}/config/importer/curl/${CMS}_${ENVIRONMENT}.netrc.cfg"

if [ ! -f "${IMPORTER_CONFIG_FILE}" ]
then
	echo "ERROR: Config file for importer not found: ${IMPORTER_CONFIG_FILE}"
	echo "Without importer config file the corresponding .netrc file for curl cannot be created."
	echo "Aborting"
	exit $ERR_IMPORTER_CONFIG_FILE_NOT_FOUND
fi

source "${IMPORTER_CONFIG_FILE}"
CAT <<EOF_CURL_NETRC_FILE > "${CURL_NETRC_FILE}"
# Sophora importer configuration for curl (.netrc)
# ------------------------------------------------
# CMS = ${CMS}
# ENVIRONMENT = ${ENVIRONMENT}
machine ${IMPORTER_CFG_SERVER}
login ${IMPORTER_CFG_USERNAME}
password ${IMPORTER_CFG_PASSWORD}
EOF_CURL_NETRC_FILE

if [ -f "${CURL_NETRC_FILE}" ]
then
	echo "CURL_NETRC_FILE = ${CURL_NETRC_FILE}"
else
	echo "ERROR: netrc for curl could not be written: ${CURL_NETRC_FILE}"
	echo "Aborting"
	exit $ERR_CURL_NETRC_FILE_NOT_FOUND
fi



# Write config file for curl
# --------------------------
CURL_CONFIG_FILE="${SESSION_DIR}/curl_config.cfg"
cat <<EOF_CURL_CONFIG_FILE > "${CURL_CONFIG_FILE}"
# Curl config file
# ----------------
# CMS = ${CMS}
# ENVIRONMENT = ${ENVIRONMENT}
-H "Content-Type: text/xml"
--netrc-file ${CURL_NETRC_FILE}
--data-binary @${SOAP_ENVELOPE}
url = ${IMPORTER_CFG_URL}
EOF_CURL_CONFIG_FILE

if [ -f "${CURL_CONFIG_FILE}" ]
then
	echo "CURL_CONFIG_FILE = ${CURL_CONFIG_FILE}"
else
	echo "ERROR: curl config file could not be written: ${CURL_CONFIG_FILE}"
	echo "Aborting"
	exit $ERR_CURL_CONFIG_FILE_NOT_FOUND
fi


# Execute curl command
# --------------------
RESULT_FILE="${SESSION_DIR}/result.txt"
if [ $DEBUG == "true" ]
then
	$(which curl) -v --config "${CURL_CONFIG_FILE}" > "${RESULT_FILE}"
else 
	$(which curl) -s --config "${CURL_CONFIG_FILE}" > "${RESULT_FILE}"
fi





# Display importer result
# -----------------------
# Determine file contents type
RESULT_FILE_TYPE="UNKNOWN"
echo

FILE_COMMAND_OUTPUT=$(file -b "${RESULT_FILE}")

if [[ $FILE_COMMAND_OUTPUT = *XML* ]]
then
  RESULT_FILE_TYPE="XML"
  mv "${RESULT_FILE}" "${SESSION_DIR}/result.xml"
  RESULT_FILE="${SESSION_DIR}/result.xml"
fi

if [[ $FILE_COMMAND_OUTPUT = *JSON* ]]
then
  RESULT_FILE_TYPE="JSON"
  mv "${RESULT_FILE}" "${SESSION_DIR}/result.json"
  RESULT_FILE="${SESSION_DIR}/result.json"
fi

if [[ $FILE_COMMAND_OUTPUT = *HTML* ]]
then
  RESULT_FILE_TYPE="HTML"
  mv "${RESULT_FILE}" "${SESSION_DIR}/result.html"
  RESULT_FILE="${SESSION_DIR}/result.html"
fi

# Invoke result formatter
$(which python3) format_result.py -r "${RESULT_FILE}" -t "${RESULT_FILE_TYPE}"