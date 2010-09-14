#!/bin/bash 


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
options="--num-retries 10 --s3-european-buckets --s3-use-new-style"

# A list of paths NOT to backup
NO_DIR_FILE=/tmp/_no_files_for_backup

cat > $NO_DIR_FILE << EOM 
/proc
/tmp
/dev
/backup
/usr
/lost+found
/sbin
/selinux
/root/tmp
/sys
/bin
**iso
**dmg
**mp3
/var/cache
/var/named/chroot/proc
/vz/root
EOM

# A list of any sub-paths from above we do want to backup
YES_DIR_FILE=/tmp/_yes_files_for_backup
cat > $YES_DIR_FILE << EOM
/usr/local
/backup/db
EOM

if [ -z "$VERBOSITY" ]; then
	verbosity="-v3"
else
	verbosity="-v$VERBOSITY"
fi

}

backup() {	
		duplicity "$duplicity_command"  $verbosity --include-globbing-filelist="$YES_DIR_FILE" --exclude-globbing-filelist="$NO_DIR_FILE" --encrypt-key="$KEYID" --asynchronous-upload $options $src $url
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
	duplicity remove-all-but-n-full $FULL_BACKUPS $verbosity --force --encrypt-key="$KEYID" $options "$url"
}

clean() {
	message "Cleaning up the mess"
	duplicity cleanup --force $verbosity --encrypt-key="$KEYID" $options "$url"
}

list() {
	message "Listing files"
	duplicity list-current-files $verbosity --encrypt-key="$KEYID" $options "$url"
}


verify()
{
			duplicity verify  $verbosity --include-filelist="$YES_DIR_FILE" --exclude-filelist="$NO_DIR_FILE" --encrypt-key="$KEYID" $options $url $src
}

restore()
{
    files=""
        #Remove any leading or trailing slashes
        _trim $1 /
        RESTORE_FILES=$_TRIM
	if [ $RESTORE_FILES != "_ALL_FILES_" ]; then
		RESTORE_FILES="--file-to-restore=$RESTORE_FILES"
	else
		RESTORE_FILES=""
	fi
	if [ -n "$WHEN" ]; then
		options="--restore-time $WHEN"
	else
		options=""
	fi
	if [ -e "$RESTORE_LOCATION" ]; then
		echo "Restore location ($RESTORE_LOCATION) already exists, please remove"
		exit 1
	else
		mkdir -p "$RESTORE_LOCATION"
	fi

	message "Restoring $RESTORE_FILES into $RESTORE_LOCATION"
	duplicity restore $verbosity --encrypt-key="$KEYID" $options $RESTORE_FILES $options $url $RESTORE_LOCATION
}

status()
{
	message "Getting status"
	duplicity collection-status $verbosity --encrypt-key="$KEYID" $options "$url"
}



setup

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
				echo "You must specifiy a file/directory to resotre or _ALL_FILES_. Not do NOT include / at start of file name"
			else
				restore $2
			fi
				;;
		*)
		echo $"Usage: $0 {full|incremental|list|status|clean|purge|verify}"
		RETVAL=1
esac


