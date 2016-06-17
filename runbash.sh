# AUTHOR	: Des McCarter
# DESCRIPTION	: Runs a given remote bash script on a specific VM using a specific user
# DATE		: 15/06/2016

args="${*}"

. ${DEVELOPMENT}/utils/utils.sh
. ${DEVELOPMENT}/cdexample/createvm.sh


function runbash(){

	script="${1}" 
	vm="${2}"
	vm_admin_user="${3}"
	remote_or_local="${4}"

	if [ -z "${script}" ]
	then
		error "runbash: no script given"
		return 1
	fi

	if [ -z "${vm}" ]
	then
		error "runbash: no vm given"
		return 1
	fi

	if [ ! -z "${remote_or_local}" -a "${remote_or_local}" = "local.bash" ]
	then
		eval ${script}
	else
		if [ -z "${vm_admin_user}" ]
		then
			error "runbash: no vm admin user for this vm ${vm}"
			return 1
		fi

		ip="`getProperty vm.instance.${vm} ${DEVELOPMENT}/cdexample/provision/${vm}/run.properties`"

		ssh "${vm_admin_user}@${ip}" "${script}"
	fi

}
