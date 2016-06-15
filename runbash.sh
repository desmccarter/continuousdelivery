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

	if [ -z "${vm_admin_user}" ]
	then
		error "runbash: no vm admin user for thie vm"
		return 1
	fi

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

	ip="`getProperty vm.instance.${vm} ${PROPERTIES}`"

	ssh "${vm_admin_user}@${ip}" "${script}"
}
