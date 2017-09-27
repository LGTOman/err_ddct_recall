#!/bin/bash


#SSHID=/home/admin/.ssh/id_ecdsa
#DDRUSER=sysadmin
#DDRHOST=ddve-01

usage () {
  echo
  echo "Usage: $0 --all --sshid ssh_id_file --user DD_User --ddr DD_Host [--listonly] [--debug]"
  echo
  echo "Usage: $0 --input input_file --sshid ssh_id_file --user DD_User [--ddr DD_Host] [--listonly] [--debug]"
  echo
  echo "Usage: $0 -?\|-h\|--help"
  echo
  echo "--all                          Recall all files that have read errors on the Data Domain"
  echo "                               specified by the --ddr option."
  echo "--ddr DD_Host                  Limit the scope to the Data Domain specified by DD_Host."
  echo "--input input_file             Specifies the name of a file that contains a list of files to recall."
  echo "                               The input file must have the full path to the file on the Data Domain"
  echo "                               including the MTree name. Example: /data/col1/cloud_mtree/dir1/file1."
  echo "                               List one file per line in the input_file."
  echo "--listonly                     Only lists files to be recalled on the Data Domain. No recall occurs."
  echo "--sshid ssh_id_file            Specifies the full path to the sshid file to use with Admin Access "
  echo "                               for the Data Domain"
  echo "                                 NOTE: It is required to specify the sshid file otherwise the "
  echo "                                       server may inspect a local one that requires a password. The "
  echo "                                       ssh ID file is the one generated for Admin Access to work on "
  echo "                                       the Data Domain. See the README.MD file for more details."
  echo "--user DD_User                 Specifies the name of the user on the Data Domain with which to"
  echo "                               execute commands. This user must be an admin user."
  echo "-?\|-h\|--help                 Display this help message."
  echo
}

ALL=FALSE

while [ $# -gt 0 ]; do 
  case "$1" in
    --all)
      ALL=TRUE
      ;;
    --debug)
      DEBUG=Y
      ;;
    --ddr)
      DDRHOSTS="$2"
      shift
      ;;
    --listonly)
      LISTONLY=TRUE
      ;;
    --input)
      INPUTFILE="$2"
      shift
      ;;
    --sshid)
      SSHID="$2"
      shift
      ;;
    --user)
      DDRUSER="$2"
      shift
      ;;
    -?|-h|--help)
      usage
      exit
      ;; 
    *)
      echo "ERROR: $1 is not a valid option."
      usage
      exit 1
      ;;
  esac
  shift
done

if [ "$ALL" == "TRUE" ] && [ "$INPUTFILE" != "" ]; then
  echo
  echo ERROR: Conflicting options specified. --all and --input input_file not allowed in the same command. 
  usage
  exit 1
elif [ "$ALL" == "FALSE" ] && [[ "$INPUTFILE" == ""  || "$INPUTFILE" == " " ]]; then 
  echo
  echo ERROR: One of --all or --input input_file must be specified.
  usage
  exit 1
elif [ "$SSHID" == "" ]; then
  echo
  echo ERROR: --sshid ss_id_file must be specified
  usage
  exit 1
elif [ "$DDRUSER" == "" ]; then
  echo
  echo ERROR: --user DD_User must be specified
  usage
  exit 1
elif [ "$DDRHOSTS" == "" ]; then
  echo
  echo ERROR: --ddr DD_Host must be specified
  usage
  exit 1
fi

if [ "$ALL" == "TRUE" ]; then
  echo About to recall all files with read errors on Data Domain $DDRHOSTS.
  echo This operation may take significant time and space.
  echo It may also incur additional charges from public cloud providers.
  echo Are you sure you want to proceed? \(YES/[NO]\)
  read ANSWER
  if [ "$ANSWER" != "YES" ]; then
    echo Canceling...
    exit 2
  fi
fi

echo Searching for backup files to recall...

if [ "$ALL" == "TRUE" ]; then
  FILES=($(ssh -i $SSHID $DDRUSER@$DDRHOSTS filesys report generate cloud-files-with-read-failures | grep /data/col))
  RC=$?
  if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
  if [ $RC -gt 0 ]; then
    echo ERROR: The SSH command faild.
    exit 1
  fi
  if [ ${#LONGSSIDS[@]} -lt 1 ]; then
    echo No files to recall. All backup files may be on the Active tier.
    echo Exiting...
    exit 3
  fi
  echo About to recall all backups for client $CLIENT from ${#LONGSSIDS[@]} save sets.
  echo Are you really sure you want to proceed? \(YES/[NO]\)
  read ANSWER
  if [ "$ANSWER" != "YES" ]; then
    echo Canceling...
    exit 2
  fi
  if [ "$DDRHOSTS" == "" ] || [ "$DDRHOSTS" == " " ];then 
    VOLUMES=$(mminfo -q client=$CLIENT -r 'volume')
    for VOLUME in $VOLUMES; do 
      DDRHOSTS=$(echo "print type:NSR device; volume name: $VOLUME" | nsradmin -i - | grep "information" | awk -F \" '{print $2}' | awk -F \: '{print $1}')
    done
  fi
elif [ "$ALL" == "TRUE" ];then
  if [ "$DDRHOSTS" == "" ] || [ "$DDRHOSTS" == " " ];then 
    DDRHOSTS=$(echo "print type:NSR device; media type: Data Domain" | nsradmin -i - | grep "information" | awk -F \" '{print $2}' | awk -F \: '{print $1}' | sort | uniq)
  fi
  LONGSSIDS=()
  for DDRHOST in $DDRHOSTS; do 
    LONGSSIDS+=($(echo "print type:NSR device; media type: Data Domain" | nsradmin -i - | grep "information" | grep $DDRHOST | awk -F : '{print $3}' | awk -F \" '{print $1}'))
  done
  if [ ${#LONGSSIDS[@]} -lt 1 ]; then
    echo No backup files to recall. All backup files may be on the Active tier.
    echo Exiting...
    exit 3
  fi
  echo About to recall all backups for Data Domain $DDRHOST from ${#LONGSSIDS[@]} save sets.
  echo Are you really sure you want to proceed? \(YES/[NO]\)
  read ANSWER
  if [ "$ANSWER" != "YES" ]; then
    echo Canceling...
    exit 2
  fi
else
  LONGSSIDS=()
  for SSID in $SSIDS; do 
    LONGSSIDS+=($(mminfo -q ssid=$SSID -r 'ssid(60)'))
    RC=$?
    if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
    if [ $RC -gt 0 ]; then
      echo ERROR: The mminfo query failed. Most likely save set id $SSID does not exist.
      exit 1
    fi
  done  
  if  [[ "$DDRHOSTS" == "" || "$DDRHOSTS" == " " ]]; then
    for SSID in $LONGSSIDS; do
      for VOLUME in $(mminfo -q ssid=$SSID -r 'volume'); do
        DDRHOSTS=$DDRHOSTS" "$(echo "print type:NSR device; volume name: $VOLUME" | nsradmin -i - | grep "information" | awk -F \" '{print $2}' | awk -F \: '{print $1}')
      done
    done
  fi
fi


let REPEAT=1
DDRHOSTS=$(echo $DDRHOSTS | sort | uniq)
if [ "$DEBUG" == "Y" ]; then echo DDRHOSTS is $DDRHOSTS; fi
for DDRHOST in $DDRHOSTS; do
  if [ "$DEBUG" == "Y" ]; then echo REPEAT is $REPEAT; fi
  let REPEAT=1
  echo Operating on Data Domain $DDRHOST
  while [ $REPEAT -ne 0 ]; do 
    let REPEAT=0
    FILES=($(ssh -i $SSHID $DDRUSER@$DDRHOST filesys report cloud-files-with-read-failures| grep -v "-----" | grep -v "File  Name" | awk '{$NF=""}1'))
    RC=$?
    if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
    if [ $RC -gt 0 ]; then
      echo ERROR: Unable to ssh to $DDRHOST using user $DDDRUSER with key $SSHID.
      echo "      Check credentials and try again."
      exit 1
    fi
    echo
    if [ ${#FILES[@]} -lt 1 ]; then
      echo No backup files to recall. All backup files may be on the Active tier.
      echo Exiting...
      exit 3
    fi
    echo Listing or recalling ${#FILES[@]} files.

    for ((FILE=0; FILE<${#FILES[@]}; FILE++)); do
      if [ "$LISTONLY" == "TRUE" ]; then
        echo "${FILES[$FILE]}"
      else
        echo Recalling backup file $FILE of ${#FILES[@]}...
        ssh -i $SSHID $DDRUSER@$DDRHOST data-movement recall path "${FILES[$FILE]}"
      fi
      RC=$?
      if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
      if [ $RC -gt 0 ]; then 
        let REPEAT=$REPEAT+1
      fi
      if [ "$DEBUG" == "Y" ]; then echo REPEAT is: $REPEAT; fi
    done
    let STATUS=1
    while [ "$LISTONLY" != "TRUE" ] && [ $STATUS -gt 0 ]; do
      if [ $REPEAT -gt 0 ]; then
        echo $REPEAT files were not recalled. Any files not recalled will be tried again.
        break
      fi
      ssh -i $SSHID $DDRUSER@$DDRHOST data-movement status | tee /dev/tty | grep -q "No recall"
      let RC=$?
      if [ "$DEBUG" == "Y" ]; then echo Error Code is: $RC; fi
      if [ $REPEAT -gt 0 ]; then
        echo $REPEAT files were not recalled. Any files not recalled will be tried again.
        break
      fi
      if [ $RC -gt 0 ]; then
        echo Backup files are still recalling. Waiting 5 seconds...
        sleep 5
      else 
        let STATUS=0
      fi
    done
  done 
done


