#!/bin/bash 

# Log everything to /var/log/duplicity as well
exec > >(tee -a /var/log/duplicity) 

2>&1

# Get our config settings
source /etc/sysconfig/duplicity


message() {
if [ $MESSAGES = "1" ]; then
	echo $*
fi
}

setup() {
src="/"
url="s3+http://$AWS_BUCKET"
options=" --s3-use-new-style --s3-european-buckets --asynchronous-upload --num-retries 10 --volsize=25"

# A list of paths NOT to backup
NO_DIR_FILE=/etc/duplicity/exclude_list
# A list of any sub-paths from above we do want to backup
YES_DIR_FILE=/etc/duplicity/include_list



if [ -z "$DUPLICITY_VERBOSITY" ]; then 
verbosity="-v3"
else
verbosity="-v$DUPLICITY_VERBOSITY"
fi

}

backup() {	
		duplicity "$duplicity_command"  $verbosity $options --include-globbing-filelist="$YES_DIR_FILE" --exclude-globbing-filelist="$NO_DIR_FILE" --encrypt-key="$KEYID" $src $url
}


run_duplicity() {
	duplicity $duplicity_command $verbosity --encrypt-key="$KEYID" $options $src $url

}

file_list_options()
{
	options=$options --include-filelist="$YES_DIR_FILE" --exclude-filelist="$NO_DIR_FILE"
}

full() {
	message "Full backup"
	duplicity_command="full"
	backup
}

incremental() {
	message "Incremental backup"
	duplicity_command="incremental"
	backup
}


purge() {
	message "Purging old backups"
	duplicity remove-all-but-n-full $FULL_BACKUPS $verbosity $options --force --encrypt-key="$KEYID" "$url"
}

clean() {
	message "Cleaning up the mess"
	duplicity cleanup $options --force $verbosity --encrypt-key="$KEYID" "$url"
}

list() {
	message "Listing files"
	duplicity list-current-files $verbosity $options --encrypt-key="$KEYID" "$url"
}


verify()
{
			duplicity verify  $options $verbosity --include-filelist="$YES_DIR_FILE" --exclude-filelist="$NO_DIR_FILE" --encrypt-key="$KEYID" $url $src
}

restore()
{
    files=""
	message "Restoring $1 into $RESTORE_LOCATION"
	if [ -n "$WHEN" ]; then
		options="--restore-time $WHEN"
	else
		options=""
	fi

	if [ "$*" != "_ALL_FILES_" ]; then
		duplicity restore $verbosity --encrypt-key="$KEYID" $options --file-to-restore "$*" $url $RESTORE_LOCATION
	else
		duplicity restore $verbosity --encrypt-key="$KEYID" $options $url $RESTORE_LOCATION
	fi
}

status()
{
	message "Getting status"
	duplicity collection-status $verbosity $options --encrypt-key="$KEYID" "$url"
}



setup

echo "DUPLICITY_RUN_MODE=$1"

case "$1" in
        full)
			full
              	;;
        incremental)
			incremental
                ;;
	    purge)
			purge
				;;
        clean)
			clean
                ;;
		verify)
			verify
				;;
		list)
			list
				;;
		status)
			status
				;;
		restore)
			if [ -z "$2" ]; then
				echo "You must specify a file/directory to resotre or _ALL_FILES_. Not do NOT include / at start of file name"
			else
				restore $2
			fi
				;;
		*)
		echo $"Usage: $0 {full|incremental|list|status|clean|purge|verify}"
		RETVAL=1
esac


