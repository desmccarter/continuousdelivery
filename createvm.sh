# AUTHOR	: Des McCarter @ BJSS
# DESCRIPTION	: Creates a new VM 
# DATE		: 08/06/2016 - started

. ${DEVELOPMENT}/utils/utils.sh

CREATEVM_PROPERTIES="${DEVELOPMENT}/cdexample/createvm.properties"

if [ -z "${VMDIR}" ]
then
	warn "env variable VMDIR not set. Setting to /tmp/vms"

	VMDIR=/tmp/vms
fi

function init(){
	if [ ! -d "${VMDIR}" ]
	then
		mkdir -p ${VMDIR}
	
		if [ ! "$?" = 0 ]
		then
			error "FAILED to create directory ${VMDIR}"
		fi
			
	fi
}

init

if [ ! $? = 0 ]
then
	exit $?
fi

function vmHasBeenPoweredOff(){

	vmname="$1"

	if [ -z "${vmname}" ]
	then
		error "vmHasBeenSetup: vm name has not been given"
	fi

	cd "${VMDIR}/${vmname}"

	vagrant status  2>/dev/null | grep "powered off"

	cd - >/dev/null 2>&1
}

function vmHasNotBeenCreated(){

	vmname="$1"

	if [ -z "${vmname}" ]
	then
		error "vmHasBeenSetup: vm name has not been given"
	fi

	cd "${VMDIR}/${vmname}"

	vagrant status  2>/dev/null | grep "The environment has not yet been created"

	cd - >/dev/null 2>&1
}


function validvm(){

	if [ -z "${1}" ]
	then
		error "validvm: vm name not given"
		return 1
	fi

	vmdir="${VMDIR}/${1}"

	if [ ! -d "${vmdir}" ]
	then
		error "validvm: vm ${1} does not exist (or has not been created yet)"
		return 1
	fi

	return 0
}

function updateVmWithPublicKey(){

	vm="${1}"
	user="${2}"

	info "Using ${user} to update vm ${vm} with public key of ${USER}@${this_host}"
	
	scp "`eval echo ${ssh_key_location}`/id_rsa.pub" "${user}@${vm}:/var/tmp/id_rsa.pub" 
	
	if [ $? = 0 ]
	then
		ssh "${user}@${vm}" "cat /var/tmp/id_rsa.pub >> ~/.ssh/authorized_keys"

		if [ ! $? = 0 ]
		then
			error "initpublickeysonvm: failed to update authorized_keys on VM ${vm}"
			return 1
		fi
	else
		error "initpublickeyonvms: failed to store public key on ${vm}"
		return 1
	fi
}

function initpublickeyonvm(){

	# check to see whether we have VM's ...
	if [ ! -d "${VMDIR}" ]
	then
		error "No VM's have been set-up on this local machine"
		return 1
	fi

	vm="${1}"
	user="${2}"

	if [ -z "${vm}" ]
	then
		error "copyPublicKey: vitrual machine not given"
		return 1
	fi

	ssh_key_location="`getProperty ssh.key.location ${CREATEVM_PROPERTIES}`"

	key_file="`eval echo ${ssh_key_location}`/id_rsa.pub"

	if [ ! -f "${key_file}" ]
	then
		error "initpublikeyonvm: public key ${key_file} does not exist"
		return 1
	else
		info "Public key (RSA) for current user (${USER}) exists on this (local) machine (`hostname`)"
		info "Checking to see whether it exists on vm ${vm} ..."
	fi

	# check that public key has not already been placed on this VM first. 
	# if not then do it ...

	this_host="`hostname`"

	my_public_key_local="`cat ${key_file}`"

	# check to see whether the public key exists on the remote vm ...
	my_public_key="`ssh \"${user}@${vm}\" \"cat ~/.ssh/authorized_keys 2>/dev/null | grep ${USER}@${this_host}\"`"

	if [ ! -z "${my_public_key}" ]
	then
		if [ "${my_public_key}" = "${my_public_key_local}" ]
		then
			info "Public key for ${USER}@${this_host} exists on vm ${vm}"
		else
			warn "Public key for exists for ${USER}@${this_host} on vm ${vm}, but is different"

			updateVmWithPublicKey "${vm}" "${user}"
		fi
	else
		updateVmWithPublicKey "${vm}" "${user}"
	fi

	return 0
}

function setvmip(){

	vm="${1}"
	ip="${2}"

	if [ -z "${vm}" ]
	then
		error "setvmip: vm not given"
		return 1
	fi

	if [ -z "${ip}" ]
	then
		error "setvmip: ip not given"
		return 1
	fi

	vagrantfile="${VMDIR}/${vm}/Vagrantfile"
	vagrantfile_temp="/tmp/Vagrantfile.${vm}"

	if [ ! -f "${vagrantfile}" ]
	then
		error "Vagrant file for ${vm} not found"
		return 1	
	fi

	sed s/".*\(config.vm.network[ ]*\"private_network\",[ ]*ip:[ ]*\"\)[^\"]*\(.*\)$"/"\1$ip\2"/g ${vagrantfile} > "${vagrantfile_temp}" 2>/dev/null

	if [ ! $? = 0 ]
	then
		error "Failed to edit vagrant file for ${vm}"
		return 1
	fi

	mv "${vagrantfile_temp}" "${vagrantfile}" >/dev/null 2>&1

	if [ ! $? = 0 ]
	then
		error "Failed to update vagrant file for ${vm}"
		return 1
	else
		info "Updated IP address of vm ${vm} to ${ip}"
		return 0
	fi
}

function createvm(){

	name="$1"

	if [ -z "${name}" ]
	then
		error "Name of VM not given"
		return 1
	fi

	vmdir="${VMDIR}/${name}"

	mkdir -p "${vmdir}"

	cd ${vmdir}

	vagrant init hashicorp/precise32 >/dev/null 2>&1

	if [ ! "$?" = 0 ]
	then
		error "Vagrant init failed"

		cd -

		return 1
	else
		info "Created virtual machine ${name} successfully"
	
		return 0
	fi
}


function stopvm(){

	if [ -z "${1}" ]
	then
		error "stopvm: vm name not given"
		return 1
	fi

	vmdir="${VMDIR}/${1}"

	if [ ! -d "${vmdir}" ]
	then
		error "stopvm: vm ${1} does not exist (or has not been created yet)"
		return 1
	fi

	cd "${vmdir}"

	flag_machine_up="`vagrant status | grep 'powered off'`"

        ret=0

        if [ -z "${flag_machine_up}" ]
        then
                info "stopvm: stopping virtual machine ${1}. Please wait ..."

                vagrant halt >/dev/null 2>&1

                if [ ! $? = 0 ]
                then
                        error "stopvm: failed to stop vm ${1}"

                        ret=1
                else
                        info "stopvm: virtual machine ${1} stopped successfully"
                fi
        else
                info "stopvm: virtual machine ${1} already stopped"
        fi

        cd - >/dev/null 2>&1

        return ${ret}
}

function startvm(){

	if [ -z "${1}" ]
	then
		error "startvm: vm name not given"
		return 1
	fi

	vmdir="${VMDIR}/${1}"

	if [ ! -d "${vmdir}" ]
	then
		error "startvm: vm ${1} does not exist (or has not been created yet)"
		return 1
	fi

	flag_machine_powered_off="`vmHasBeenPoweredOff ${1}`"
	flag_machine_has_not_been_created="`vmHasNotBeenCreated ${1}`"
	
	ret=0

	if [ ! -z "${flag_machine_powered_off}" -o ! -z "${flag_machine_has_not_been_created}" ]
	then
		info "startvm: starting virtual machine ${1}. Please wait ..."

		cd "${vmdir}"

		vagrant up >/dev/null 2>&1

		vagrant_resp="${?}"

		cd - >/dev/null 2>&1

		if [ ! "${vagrant_resp}" = 0 ]
		then
			error "startvm: failed to start vm ${1}"

			ret=1
		else
			info "startvm: virtual machine ${1} started successfully"
		fi
	else
		info "startvm: virtual machine ${1} already started"
	fi


	return ${ret}
}
