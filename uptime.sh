#!/usr/bin/env bash
error="false"

## Check for required dependencies
check_dep() {
	missing_deps=()
	pkgs="$@"
	for pkg in ${pkgs}
	do
		command -v ${pkg} > /dev/null || { missing_deps+="${pkg} "; }
	done
	echo "${missing_deps}"
}

missing_deps=$(check_dep grep awk sed ping curl cut)

[[ -n ${missing_deps} ]] && echo "Please install the following dependencies: ${missing_deps}" && error="true"

## UPTIME_CONF variable
if [[ -z ${UPTIME_CONF} ]]
then
	[[ -e /etc/uptime.yaml ]] && UPTIME_CONF="/etc/uptime.yaml"
	[[ -e ./uptime.yaml ]] && UPTIME_CONF="./uptime.yaml"
fi

## Check if UPTIME_CONF still isn't set
if [[ -z ${UPTIME_CONF} ]]
then
	echo 'No config file found at ./uptime.yaml or /etc/uptime.yaml'
	echo 'For custom config file path set UPTIME_CONF to desired path'
	error='true'
else
	[[ -e ${UPTIME_CONF} ]] || { echo "${UPTIME_CONF} file not found" && error="true"; }
fi

## Parse yaml config file
parse_yaml() {
	local prefix=$2
	local s
	local w
	local fs
	s='[[:space:]]*'
	w='[a-zA-Z0-9_]*'
	fs="$(echo @|tr @ '\034')"
	sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
	awk -F"$fs" '{
	indent = length($1)/2;
	vname[indent] = $2;
	for (i in vname) {if (i > indent) {delete vname[i]}}
		if (length($3) > 0) {
			vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
			printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
		}
	}' | sed 's/_=/+=/g'
}

## Exit if error was encountered
[[ "${error}" == "true" ]] && exit 1

## Parse yaml
yaml=$(parse_yaml ${UPTIME_CONF})

## Check if status dir and tracking is enabled
if echo "${yaml}" | grep -q 'global_status_dir' 2>/dev/null
then
	STATUS_DIR=$(echo "${yaml}" | grep 'global_status_dir' | cut -d '(' -f 2 | sed 's/["()]//g')
else
	STATUS_DIR=/tmp/bash_uptime_status
fi

if echo "${yaml}" | grep 'global_track_status' 2>/dev/null | grep -q 'true'
then
	SILENCE_DUPES='true'
	mkdir -p ${STATUS_DIR}
fi

## Check if host is responsive to ping
ping_check() {
	ping_hosts=$(echo "${yaml}" | grep 'ping_hosts' | cut -d '(' -f 2 | sed 's/["()]//g')
	ping_options=$(echo "${yaml}" | grep 'ping_options' | cut -d '(' -f 2 | sed 's/["()]//g')
	ping_silent=$(echo "${yaml}" | grep 'ping_silent' | cut -d '(' -f 2 | sed 's/["()]//g')

	if [[ -n ${ping_hosts} ]]
	then
		for host in ${ping_hosts}
		do
			## If ping silent set in config
			if [[ ${ping_silent} == "true" ]]
			then
				if ping ${ping_options} ${host} &>/dev/null
				then
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						outfile="${STATUS_DIR}/${host}_ping"
						# Check if status file already contains status
						if ! grep -q ': UP Host' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): UP Host ${host} responded to ping" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): UP Host ${host} responded to ping"
					fi
				else
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						outfile="${STATUS_DIR}/${host}_ping"
						# Check if status file already contains status
						if ! grep -q ': DOWN Host' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): DOWN Host ${host} unresponsive to ping" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): DOWN Host ${host} unresponsive to ping"
					fi
				fi
			## If ping silent not set in config
			else
				if ping ${ping_options} ${host}
				then
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						outfile="${STATUS_DIR}/${host}_ping"
						# Check if status file already contains status
						if ! grep -q ': UP Host' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): UP Host ${host} responded to ping" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): UP Host ${host} responded to ping"
					fi

				else
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						outfile="${STATUS_DIR}/${host}_ping"
						# Check if status file already contains status
						if ! grep -q ': DOWN Host' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): DOWN Host ${host} unresponsive to ping" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): DOWN Host ${host} unresponsive to ping"
					fi
				fi
			fi
		done
	fi
}

## Check if URL is responsive to curl 
curl_check() {
	curl_urls=$(echo "${yaml}" | grep 'curl_urls' | cut -d '(' -f 2 | sed 's/["()]//g')
	curl_options=$(echo "${yaml}" | grep 'curl_options' | cut -d '(' -f 2 | sed 's/["()]//g') 
	curl_silent=$(echo "${yaml}" | grep 'curl_silent' | cut -d '(' -f 2 | sed 's/["()]//g') 

	if [[ -n ${curl_urls} ]]
	then
		for url in ${curl_urls}
		do
			sanitized_url=$(echo "${url}" | awk -F// '{print $NF}')
			outfile="${STATUS_DIR}/${sanitized_url}_curl"
			# If curl silent config set
			if [[ ${curl_silent} == "true" ]]
			then
				if curl ${curl_options} "${url}" &> /dev/null
				then
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						# Check if status file already contains status
						if ! grep -q ': UP URL' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): UP URL ${url} responded to curl" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): UP URL ${url} responded to curl"
					fi
				else
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						# Check if status file already contains status
						if ! grep -q ': DOWN URL' "${outfile}" 2>/dev/null
						then
							## Here
							echo "$(date --iso-860=seconds): DOWN URL ${url} unresponsive to curl" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): DOWN URL ${url} unresponsive to curl"
					fi
				fi
			# If curl silent config not set
			else
				if curl ${curl_options} "${url}"
				then
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						# Check if status file already contains status
						if ! grep -q ': UP URL' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): UP URL ${url} responded to curl" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): UP URL ${url} responded to curl"
					fi
				else
					# Log status to status file
					if [[ ${SILENCE_DUPES} == 'true' ]]
					then
						# Check if status file already contains status
						if ! grep -q ': DOWN URL' "${outfile}" 2>/dev/null
						then
							echo "$(date --iso-860=seconds): DOWN URL ${url} unresponsive to curl" | tee ${outfile}
						fi
					else
						echo "$(date --iso-860=seconds): DOWN URL ${url} unresponsive to curl"
					fi
				fi
			fi
		done
	fi
}

ping_check
curl_check
