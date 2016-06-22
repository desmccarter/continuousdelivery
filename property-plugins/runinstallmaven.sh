# AUTHOR	: Des McCarter
# DESCRIPTION	: Runs a given remote bash script on a specific VM using a specific user
# DATE		: 15/06/2016

export runbash_loaded=true

echo 1=$1

args="${*}"

. ${DEVELOPMENT}/utils/utils.sh
. ${DEVELOPMENT}/cdexample/createvm.sh


function runinstallmaven(){

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

		ssh "${vm_admin_user}@${ip}" wget http://mirrors.muzzy.org.uk/apache/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.zip -O /var/tmp/apache-maven-3.3.9-bin.zip
		ssh "${vm_admin_user}@${ip}" if [ ! -d /usr/local/maven]; then sudo mkdir /usr/local/maven; fi
		ssh "${vm_admin_user}@${ip}" sudo chown vagrant /usr/local/maven
		ssh "${vm_admin_user}@${ip}" if [ ! -d /usr/local/maven/apache-maven-3.3.9 ]; then unzip /var/tmp/apache-maven-3.3.9-bin.zip -d /usr/local/maven; fi
		ssh "${vm_admin_user}@${ip}" if [ `grep JAVA_HOME /etc/environment | wc -l` = 0 ]; then cat /etc/environment > /var/tmp/environment && echo export JAVA_HOME=\"/usr/lib/jvm/java-7-openjdk-i386/jre\" >> /var/tmp/environment && sudo mv /var/tmp/environment /etc/environment ;fi

	fi
}
