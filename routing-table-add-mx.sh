#!/bin/bash

## Set specific routes via cable modem for known mail servers,
## since Telus blocks incoming traffic to port 25, which
## prevents, say, Nextcloud from sending email


## TekSavvy's network via cable modem does
## NOT block incoming port 25 traffic:
##
## telnet telnet 69-172-190-161.cable.teksavvy.com 25
## Trying 199.212.143.222...
## Connected to 69-172-190-161.cable.teksavvy.com.kwvoip.ca.
## Escape character is '^]'.
## 220 lists.bclug.ca ESMTP Postfix (Ubuntu)



## Routes set up in netplan have 'proto static', and ALL routes
## should have something there, per the 'man ip route' page:
##
## If the routing protocol ID is
## not given, ip assumes protocol boot (i.e. it assumes the
## route was added by someone who doesn't understand what
## they are doing).
##
## (Harsh, but fair. rb / rgb / uid1)
prefMailRoute='10.60.42.1 dev eno2'
prefMailRoute='10.60.42.1 dev eno2 proto static'


## Let's add our routes to a separate routing table, with a higher
## priority than "main":
## Apparently, table name has to be numeric, unless "local, main, default",
## or (maybe?) it's found in /etc/iproute2/rt_tables
## routingTable="email"
routingTable="100"
priority="priority 10"


function load_current_routing_table ()
	{
	## Better than unset for this usage, keeps scope intact:
	table=()

	## Change Internal Field Separator to NOT contain a space, but
	## contain a new-line character (tab is irrelevant here):
	oldIFS=${IFS}
	IFS="
	"
	## Get the current routing table, with entries separated by new-lines,
	## into an array. Use the array to avoid adding duplicate entries
	for route in $(ip route);
		do
		## Strip trailing space(s) from variable "route":
		route=${route% *}
		## Populate associative array:
		table[$route]=$route
		done
	IFS=${oldIFS}
	}


## Remove table array if exists from previous invocation:
unset table
## Create associated array (-A) called "table":
declare -A table
load_current_routing_table;

## Gives all INDICES of array, not COUNT of indices:
## echo "Routing table has ${!table[@]} entries."
## Give count of indices / elements in array:
echo "Routing table has ${#table[@]} entries:"
## Show routing table (not neccessary, really):
printf ' > \"%s\"\n' "${table[@]}"
#for line in ${!table[@]};
#	do
#	echo " \"${table[$line]}\""
#	done


## Major email provider domains to create specific routes for:
mxDomains=(
	'gmail.com'
	'telus.net'
	'yahoo.com'
	'shaw.ca'
	## Generate a known duplicate of if 2 domains MX records point to same IP:
	## INTERESTING: the routing table gets read once,
	## so duplicates can be added within the loops
	## below (until I fix it)
	## Fixed it by repeating load_current_routing_table()
	);



## Allow extra domains to be routed by placing them in file ./extraDomains
## Check ./extraDomains exists and is readable
## File contents should consist of one domain name per line
## Comments in ./extraDomains indictated by # characters
if [ -r ./extraDomains ] ; then
	echo "Found readable file ./extraDomains: parsing..."
	while read domain
		## NOTE: regular expressions in bash are, frankly, stupidly implemented.
		## Simply unable to get this working, and I am quite familiar with regex
		## everywhere else.  Do not bother, use grep instead.
		## Merely having the regexPattern defined caused infinite loop, even
		## when not used elsewhere in script.
		##
		## regex pattern to match comments where # is comment, strip whitespace:
		## regexPattern='^[ \t]*(#.*)'
		do
			## [[ ! ${domain} =~ '#' ]] &&
			##	(
			##	echo "Adding \"${domain}\" to list..."
			##	)
			##
			## Add array element to mxDomains indexed array:
			mxDomains+=(${domain});

		## NOTE: redirection MUST be on same line as "done", else reads from
		## keyboard... Weird.
		## NOTE: One might expect to redirect from $(command), like below with
		## dig | awk... but NO, that is a for loop, this is a while read.
		## This syntax is a redirect from a sub-process:
		done < <(
			cat extraDomains				|
				sed -e "s/#.*$//g"		|
				sed -e "s/^[ \t]*//g"	|
				awk '!/^$/'
			)
fi




## IFS=$'\n'
echo "mxDomains, who get routing table entries:"
printf ' > %s\n' "${mxDomains[@]}"
## IFS=${oldIFS}


## get mail servers from DNS MX records for some known domains and
## strip off the priority using awk:
for mxHost in $(dig +short -t mx ${mxDomains[@]} |awk '{print $2}');
	do
	## Remove trailing '.' from DNS preferred format:
	## ${mxHost%%.*} (asterisk removes multiples, which don't exist):
	mxHost=${mxHost%.*}
	echo "mxHost:\"$mxHost\"";
	## some (i.e. fb.mail.gandi.net) have multiple IPs;
	## iterate through them, getting IPs for MX hosts:
	for mxHostIP in $(dig +short ${mxHost});
		do echo " >mxHostIP:\"$mxHostIP\"";
		## Update array of current routing table:
		load_current_routing_table;


		if [ -v "table[${mxHostIP} via ${prefMailRoute}]" ] ; then
			echo -n " >Skipping existing route: ";
			echo " \"${table[$mxHostIP via ${prefMailRoute}]}\""
		else
			echo " >ip route add ${mxHostIP} via ${prefMailRoute} table ${routingTable} ${priority}";
			## add specific route through TekSavvy cable modem:
# SKIPPING FOR NOW:
#			ip route add ${mxHostIP} via ${prefMailRoute} table ${routingTable} ${priority}
echo "SKIPPING TABLE UPDATE: UNDO FOR PRODUCTION"
		fi
		done;
	## IFS=${oldIFS}
	done
