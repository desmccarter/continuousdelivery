# AUTHOR	: Des McCarter
# DATE		: 17/06/2016
# DESCRIPTION	: Creates virtual machines (using vagrant) and provisions them using VM properties.
#
#		  Step 1 - edit the run.properties file (located in the same folder as run.sh) and insert a line similar to the following:
#		  vm.instance.nexus=192.168.33.70
#		  ... where 'nexus' is the name of the vm (this can be named anything)
#		  Step 2 - create a provision/<name of vm>/run.properties file containing the provisioning properties for this vm. Content should
#		  be similar to this:
#
#
#		vm.admin.user=vagrant
#		
#		# centos box ...
#		vm.box.type=hashicorp/precise32
#		
#		# install Nexus on nexus
#		# IP address of Nexus ...
#		vm.instance.nexus=192.168.33.70
#		
#		# Provisioning properties of Nexus ...
#		
#		vm.provision.nexus.bash=sudo apt-get update
#		vm.provision.nexus.bash=sudo apt-get -q -y install unzip
#		vm.provision.nexus.bash=sudo apt-get -q -y install openjdk-7-jre-headless
#		vm.provision.nexus.bash=sudo mkdir -p /usr/local/nexus
#		vm.provision.nexus.bash=wget  http://download.sonatype.com/nexus/oss/nexus-2.12.0-01-bundle.zip -O /var/tmp/nexus-2.12.0-01-bundle.zip >/dev/null 2>&1 
#		vm.provision.nexus.bash=sudo chown vagrant /usr/local/nexus
#		vm.provision.nexus.bash=unzip -o /var/tmp/nexus-2.12.0-01-bundle.zip -d /usr/local/nexus
#		vm.provision.nexus.bash=nohup /usr/local/nexus/nexus-2.12.0-01/bin/nexus start &
#
#
#		... where:
#		vm.admin.user is the admin user that will be used to log into the VM
#	    	vm.box.type is the type of VM you need setting up (identical to vagrants vm.box property in VangrantFile
#		vm.provision.nexus.bash are commands to execute on that vm / box

args="${*}"

export VALID_ARGS=("-jenkinsmaster:the_name_of_the_jenkins_master" "-vmsoff")

. ${DEVELOPMENT}/utils/utils.sh
. ${DEVELOPMENT}/cdexample/createvm.sh

PROPERTIES="${DEVELOPMENT}/cdexample/run.properties"
PROVISION_CONFIG_ROOT="${DEVELOPMENT}/cdexample/provision"

SOUT="/tmp/vms/provision_out.log"
SERR="/tmp/vms/provision_err.log"

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

function createVms(){

	for vm in ${VMS[@]}
	do
		prop=${PROVISION_CONFIG_ROOT}/${vm}/run.properties

        	if [ ! -f "${prop}" ]
        	then
			warn "No provisioning properties exist for virtual machine ${vm}."
		else
                	box_type="`getProperty vm.box.type ${prop}`"
	
	        	if [ ! -d "${VMDIR}/${vm}" -o ! -f "${VMDIR}/${vm}/Vagrantfile" ]
	        	then
	                	createvm "${vm}" "${box_type}"
			else
		        	info "Virtual machine ${vm} already exists"
			fi
		fi
	done
}

function editVmConfigs(){

	let index=0

	for vm in ${VMS[@]}
	do
	        if [ -f "${VMDIR}/${vm}/Vagrantfile" ]
	        then
	                ip_address="${VMS_IP[${index}]}"
	
		        setvmip "${vm}" "${ip_address}"
		else
		        warn "Vangrant file for ${vm} does not exist. Cannot edit VM properties"
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


	for vm in ${VMS[@]}
	do
		prop=${PROVISION_CONFIG_ROOT}/${vm}/run.properties

		if [ -f "${prop}" ]
		then
			vm_admin_user="`getProperty vm.admin.user ${prop}`"
			ip="`getProperty vm.instance.${vm} ${prop}`"

			initpublickeyonvm "${ip}" "${vm_admin_user}"
		else
			warn "No provisioning properties exist for virtual machne ${vm}"
		fi
	done
}

function provisionvms(){

	for vm in ${VMS[@]}
	do
		prop=${PROVISION_CONFIG_ROOT}/${vm}/run.properties

		if [ -f "${prop}" ]
		then
			# get all the provisioning instructions for ${vm} ...
			vmprovision="`getPropertyGroupAndName vm.provision.${vm} ${prop}`"
	
			vm_admin_user="`getProperty vm.admin.user ${prop}`"
	
			let script_index=0
	
			if [ ! -z "${vmprovision}" ]
			then
				for data in ${vmprovision}
				do
					prop="`echo ${data} | sed -n s/'\(vm\.provision\.[^=\]*\).*$'/'\1'/p`"
					full_prop_name="`echo ${data} | sed -n s/'^\([^=]*\)=.*$'/'\1'/p`"
	
					if [ ! -z "${prop}" -o ! -z "${full_prop_name}" -a "${full_prop_name}" = "vm.provision.${vm}.local.bash" ]
					then
						provision_command="${prop/'vm.provision.'${vm}'.'/}"
	
						if [ "${provision_command}" = "bash" -o "${provision_command}" = "local.bash" ]
						then
							let script_index="${script_index}+1"
		
							temp_data="`echo ${data} | sed -n s/'^[^=]*=\(.*\)$'/'\1'/p`"			
		
							if [ ! -z "${temp_data}" ]
							then
								bash_script[${script_index}]="${temp_data}"
							fi
	
							executor[${script_index}]="runbash"
							executor_extra_data[${script_index}]="${provision_command}"
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
					executor_type="${executor_extra_data[${index}]}"
	
					info "Executing bash on virtual machine ${vm}: \"${script}\" ..."

					# load the executor ...
					. ${DEVELOPMENT}/cdexample/property-plugins/${execute_command}.sh
	
					${execute_command} "${script}" "${vm}" "${vm_admin_user}" "${executor_type}" >> ${SOUT} 2>> ${SERR}
	
					if [ ! "$?" = 0 ]
					then
						error "Error found. Stopping execution"
						return 1
					else
						info "Bash script completed successfuly."
					fi
	
					let index="${index}+1"
				done
			fi
		else
			warn "provisionvm: no provisioning properties exist (${prop}) for virtual machine ${vm}, therefore no provisioning to do on ${vm}."
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
	# Create virtual machines if they do 
	# not yet exist ...

	createVms

	# Edit VM configs and change properties
	# where required ...

	editVmConfigs

	# Start the virtual machines ...

	startVms

	# Place the public key (of this user) onto the VM ...

	initpublickeysonvms

	# Start installing apps on VM's ...

	provisionvms
else
	stopVms
fi
