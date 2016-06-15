args="${*}"

export VALID_ARGS=("-jenkinsmaster:the_name_of_the_jenkins_master" "-vmsoff")
#export VMS=("jmaster" "jbuildslave" "testslave" "testenvironment" "stagingenvironment" "production")

. ${DEVELOPMENT}/utils/utils.sh
. ${DEVELOPMENT}/cdexample/createvm.sh
. ${DEVELOPMENT}/cdexample/runbash.sh

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

function provisionvms(){

	for vm in ${VMS[@]}
	do
		# get all the provisioning instructions for ${vm} ...
		vmprovision="`getPropertyGroupAndName vm.provision.${vm} ${PROPERTIES}`"

		vm_admin_user="`getProperty vm.admin.user ${PROPERTIES}`"

		let script_index=0

		if [ ! -z "${vmprovision}" ]
		then
			for data in ${vmprovision}
			do
				prop="`echo ${data} | sed -n s/'\(vm\.provision\.[^=\]*\).*$'/'\1'/p`"

				if [ ! -z "${prop}" ]
				then
					provision_command="${prop/'vm.provision.'${vm}'.'/}"

					if [ "${provision_command}" = "bash" ]
					then
						let script_index="${script_index}+1"
	
						temp_data="`echo ${data} | sed -n s/'^[^=]*=\(.*\)$'/'\1'/p`"			
	
						if [ ! -z "${temp_data}" ]
						then
							bash_script[${script_index}]="${temp_data}"
						fi

						executor[${script_index}]="runbash"
					fi
				else
					bash_script[${script_index}]="${bash_script[${script_index}]} ${data}"	
				fi
			done

			let index=1

			while [ ! -z "${bash_script[${index}]}" ]
			do
				script="${bash_script[${index}]}"
				execute_command="${executor[${index}]}"

				${execute_command} "${script}" "${vm}" "${vm_admin_user}"

				let index="${index}+1"
			done
		fi


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
	#editVmConfigs

	#startVms

	#initpublickeysonvms

	provisionvms
else
	stopVms
fi
