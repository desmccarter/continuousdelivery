# AUTHOR	: Des McCarter
# DESCRIPTION	: Runs a given remote bash script on a specific VM using a specific user
# DATE		: 15/06/2016

export runbash_loaded=true

echo 1=$1

args="${*}"

. ${DEVELOPMENT}/utils/utils.sh
. ${DEVELOPMENT}/cdexample/createvm.sh


function runinstalljava(){

	script="${1}" 
	vm="${2}"
	vm_admin_user="${3}"

	echo script=$script

	if [ -z "${script}" ]
	then
		error "runbash: no script given"
		return 1
	fi

	if [ -z "${vm}" ]
	then
		eval ${script}
	else
		if [ -z "${vm_admin_user}" ]
		then
			error "runbash: no vm admin user for this vm ${vm}"
			return 1
		fi

		ip="`getProperty vm.instance.${vm} ${DEVELOPMENT}/cdexample/provision/${vm}/run.properties`"

		ssh "${vm_admin_user}@${ip}" sudo apt-get update
		ssh "${vm_admin_user}@${ip}" sudo apt-get -q -y install openjdk-7-jre-headless
	fi
}
