args="${*}"

export VALID_ARGS=("-jenkinsmaster:the_name_of_the_jenkins_master" "-vmsoff")
export VMS=("jmaster" "jbuildslave" "testslave" "testenvironment" "stagingenvironment" "production")

. ${DEVELOPMENT}/utils/utils.sh
. ${DEVELOPMENT}/cdexample/createvm.sh

PROPERTIES="${DEVELOPMENT}/cdexample/run.properties"

export VMDIR=/tmp/vms

function getVmNames(){

	names="`getPropertyGroupNames \"vm.instance\" \"${PROPERTIES}\"`"

	if [ -z "${names}" ]
	then
		error "no 'vm.instance' property groups found in ${PROPERTIES}"
		return 1
	fi

	let index=0

	for vm in ${names}
	do
		VMS[${index}]="${vm}"

		let index="${index}+1"
	done

	return 0
}


function processArgsvmsoff(){

	VMS_OFF=true
}

function processArgsjenkinsmaster(){

	if [ -z "${1}" ]
	then
		error "-jenkinsmaster: 'name of jenkins master'  not given"
		return 1
	else
		JENKINS_MASTER="${1}"
	fi
}

function validateArgs(){

	echo >/dev/null
}

function getIps(){

	let index=0

	for vm in ${VMS[@]}
	do
		VMS_IP[${index}]="`getProperty vm.instance.${vm} ${PROPERTIES}`"

		if [ -z "${VMS_IP[${index}]}" ]
		then
			error "Property ${vm} not found in ${PROPERTIES}"
			return 1
		fi

		let index="${index}+1"
	done
}

function editVmConfigs(){

	let index=0

	for vm in ${VMS[@]}
	do
        if [ ! -d "${VMDIR}/${vm}" -o ! -f "${VMDIR}/${vm}/Vagrantfile" ]
        then
                createvm "${vm}"

                ip_address="${VMS_IP[${index}]}"

	                setvmip "${vm}" "${ip_address}"
	        else
	                debug "${vm} already exists"
	        fi
	
	        let index="${index}+1"
	done
}

function startVms(){
	for vm in ${VMS[@]}
	do
		if [ -d "${VMDIR}/${vm}" -a -f "${VMDIR}/${vm}/Vagrantfile" ]
		then
			startvm "${vm}"
		else
			error "failed to start vm: virtual machine ${vm} does not exist"
		fi
	done
}

function stopVms(){
	for vm in ${VMS[@]}
	do
		if [ -d "${VMDIR}/${vm}" -a -f "${VMDIR}/${vm}/Vagrantfile" ]
		then
			stopvm "${vm}"
		else
			error "failed to stop vm: virtual machine ${vm} does not exist"
		fi
	done
}

function initpublickeysonvms(){

	vm_admin_user="`getProperty vm.admin.user ${PROPERTIES}`"

	for ip in ${VMS_IP[@]}
	do
		initpublickeyonvm "${ip}" "${vm_admin_user}"
	done
}

processArgs ${args}

validateArgs

if [ ! "$?" = "0" ]
then
	exit $?
fi

getVmNames

if [ ! $? = 0 ]
then
	exit $?
fi

getIps

if [ -z "${VMS_OFF}" ]
then
	editVmConfigs

	startVms

	initpublickeysonvms
else
	stopVms
fi
