#!/bin/bash
DRYRUN=0;

# always do backups regardless the time
SKIP_UPTIME_CHECK=0;

# Device to mount and mount point
BACKUP_MOUNT_DEVICE="/dev/sdb1"
BACKUP_MOUNT_POINT="/mnt/backup"

# Directory the backups must be copied to
BACKUP_TARGET_BASE="/mnt/backup/devbox"

# This is always in the format <file_or_dir> <dir>
# NOTE: do not use wildcards!
FILES_TO_BACKUP=( \
    '/path/to/picturefile1' 'pictures' \
    '/path/to/musicfile1' 'music' \
    '/path/to/musicfile2' 'music' \
    '/path/to/musicfile3' 'music' \
    '/path/to/documents_dir' 'documents' \
)

function all_source_files_exist {
	# Checks that all source files exist. Returns 1 if so, returns 0 otherwise.	

	echo "Checking if all source files exist...";
	notfound="";
	src=0;
	target=0;
	for i in "${FILES_TO_BACKUP[@]}"; do
		if [ "$src" = "0" ]; 
		then 
			src="$i";
		else
			target="$i";

			if [ ! -e $src ];
			then
				echo "input file not found: $src";
				notfound="$src $notfound";
			fi;

			src=0;
			target=0;
		fi;
	done;

	if [ "$notfound" = "" ];
	then
		return 1;
	fi;

	return "0";
}

function mount_backup {
	# Mounts $BACKUP_MOUNT_DEVICE as $BACKUP_MOUNT_POINT

	echo "Making sure ${BACKUP_MOUNT_POINT} exists and is mounted...";
	[[ ! -d ${BACKUP_MOUNT_POINT} ]] && mkdir -p ${BACKUP_MOUNT_POINT}
	mount ${BACKUP_MOUNT_DEVICE} ${BACKUP_MOUNT_POINT}
}

function can_backup {
	# Checks that conditions to proceed with the backup are verified. Returns 1  
	# if the conditions are verified, returns 0 otherwise.    

	##
	## All source files must exist
	##
	all_source_files_exist
	if [ $? -eq 0 ]; then
		return 0;
	fi;
	
	##
	## We can backup if we don't care about uptime
	##
	if [ $SKIP_UPTIME_CHECK -eq 1 ];
	then
		return 1;
	fi;

	# format H:MM
	UPTIME=$(uptime | cut -d ','  -f 1 | awk '{print $NF}')
	UPTIME_HOURS=$(echo $UPTIME | cut -d : -f 1)
	UPTIME_MINUTES=$(echo $UPTIME | cut -d : -f 2)

	if [ "$UPTIME_HOURS" = "min" ]; then
		UPTIME_HOURS=0;
	fi

	# do the backup if we've turned on the computer in the past hour
	if [ $UPTIME_HOURS -eq 0 ]; then
		return 1;
	else
		echo "Cannot proceed with backup because the computer was turned on for more than hour (i.e., ${UPTIME_HOURS} hours)"
		return 0;
	fi;
}

function do_backup {
	# Copies the source file to the specified target directory.
	
	path_to_src_file=$1
	name_of_target_dir=$2

	path_to_target_dir="${BACKUP_TARGET_BASE}/${name_of_target_dir}"
	[[ ! -d ${path_to_target_dir} ]] && mkdir -p ${path_to_target_dir}
	rsync -a $path_to_src_file ${path_to_target_dir}
}


function dry {
	# Executes the specified command if $DRYRUN is turned off, otherwise
	# just echo the command itself.
	if [ $DRYRUN -eq 1 ];
	then
		echo "dryrun [$1]";
	else
		$1;
	fi
}

echo -n "Backup Started on "
date

echo -n "Uptime: "
uptime

can_backup
if [ $? -eq 1 ];
then
	if ! mount | grep "/mnt/backup" &>/dev/null;
	then
		mount_backup;
	fi;


	# Extract source and target files from $FILES_TO_BACKUP
	src=0;
	target=0;
	for i in "${FILES_TO_BACKUP[@]}"; do
		if [ "$src" = "0" ]; 
		then 
			src="$i";
		else
			target="$i";
			
			# do backup here
			dry "do_backup $src $target";

			src=0;
			target=0;
		fi;
	done;
	# -- end backing up

	echo -n "Shutting down on "
	date
	dry "/sbin/shutdown -h now";
else
	echo "Halting backup, and leaving the computer turned on.";
fi;

