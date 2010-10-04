#!/bin/bash 

# Log everything to /var/log/duplicity as well
exec > >(tee -a /var/log/duplicity) 
2>&1


# Functions to strip paths of spaces
_trim() #@ Trim spaces (or char in $2) from both ends of $1
{
    _TRIM=$1
    trim_string=${_TRIM%%[!${2:- }]*}
    _TRIM=${_TRIM#"$trim_string"}
    trim_string=${_TRIM##*[!${2:- }]}
    _TRIM=${_TRIM%"$trim_string"}
}

trim()
{
   _trim "$@"
   printf "%s\n" "$_TRIM"
}



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


if [ -z "$DUPLICITY_VERBOSITY" ]; then 
verbosity="-v3"
else
verbosity="-v$DUPLICITY_VERBOSITY"
fi

}

backup() {	
		duplicity "$duplicity_command"  $verbosity $options --include-globbing-filelist="$INCLUDE_LIST" --exclude-globbing-filelist="$EXCLUDE_LIST" --encrypt-key="$KEYID" $src $url
}


run_duplicity() {
	duplicity $duplicity_command $verbosity --encrypt-key="$KEYID" $options $src $url

}

file_list_options()
{
	options=$options --include-filelist="$INCLUDE_LIST" --exclude-filelist="$EXCLUDE_LIST"
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
			duplicity verify  $options $verbosity --include-globbing-filelist="$INCLUDE_LIST" --exclude-globbing-filelist="$EXCLUDE_LIST" --encrypt-key="$KEYID" $url $src
}

restore()
{
    files=""
    #Remove any leading or trailing slashes
    #_trim $* /
    RESTORE_FILES=$*
	if [ -n "$WHEN" ]; then
		options="$options --restore-time $WHEN"
	else
		options="$options"
	fi
	if [ -e "$RESTORE_LOCATION" ]; then
		echo "Restore location ($RESTORE_LOCATION) already exists, please remove"
		exit 1
	else
		mkdir -p "$RESTORE_LOCATION"
	fi

	message "Restoring $RESTORE_FILES into $RESTORE_LOCATION"
	duplicity restore $verbosity --encrypt-key="$KEYID" $options --file-to-restore="$RESTORE_FILES" $options $url $RESTORE_LOCATION
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
				shift
				restore $* 
			fi
				;;
		*)
		echo $"Usage: $0 {full|incremental|list|status|clean|purge|verify}"
		RETVAL=1
esac


