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

## Check if host is responsive to ping
ping_check() {
	ping_hosts=$(echo "${yaml}" | grep 'ping_hosts' | cut -d '(' -f 2 | sed 's/["()]//g')
	ping_options=$(echo "${yaml}" | grep 'ping_options' | cut -d '(' -f 2 | sed 's/["()]//g') 
	ping_silent=$(echo "${yaml}" | grep 'ping_silent' | cut -d '(' -f 2 | sed 's/["()]//g') 

	if [[ -n ${ping_hosts} ]]
	then
		for host in ${ping_hosts}
		do
			if [[ ${ping_silent} == "true" ]]
			then
				ping ${ping_options} ${host} >/dev/null || echo "$(date --iso-860=seconds): Host ${host} unresponsive to ping"
			else
				ping ${ping_options} ${host} || echo "$(date --iso-860=seconds): Host ${host} unresponsive to ping"
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
			if [[ ${curl_silent} == "true" ]]
			then
				curl ${curl_options} "${url}" > /dev/null || echo "$(date --iso-860=seconds): URL ${url} unresponsive to curl"
			else	
				curl ${curl_options} "${url}" || echo "$(date --iso-860=seconds): URL ${url} unresponsive to curl"
			fi	
		done
	fi	
}

ping_check
curl_check
