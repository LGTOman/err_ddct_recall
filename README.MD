# Warning

This script may be buggy. It has not been fully debugged.

# Introduction

This script will recall files from the Data Domain Cloud Tier. If a file generates a read error on
the Data Domain those errors are captured and this script can recall the files.

# Installation

In order to use this script Admin Access must be configured on the Data Domain 
system. This allows a remote system with the proper ssh key to use ssh to execute 
commands on the Data Domain without a password. Next the script will need to be
installed on a system with IP access to the Data Domain. The 
user that is used to run the script must have access to the Data Domain ssh key. 

## Configuring Admin Access for Data Domain

1.	From the Linux system where the commands to recall data will be run:

	ssh-keyen –t ecdsa

	Leave the passphrase blank and make note of the location to the id_ecdsa.pub file.

2.	From the host where the keys were generated run the command:

	`ssh <dd_user>@<dd_host> adminaccess add ssh-keys  < ~/.ssh/id_ecdsa.pub`

	Where: <dd_user> is the user on the Data Domain with admin access that will be used to run commands externally. 

	Where: <dd_host> is the name of the Data Domain host that Cloud Tier is on.

	The Data Domain user password will need to be entered for this command.

3.	Verify that Admin Access works by issuing the following command on the Linux system that the ssh key was created on:

	`ssh <dd_user>@<dd_host> filesys show status`

	The status of the Data Domain file system should be displayed. If it is not, login to the Data Domain and verify that 
	they key was taken by running the command: `adminaccess show ssh-keys`

## Install the script

1. Download and copy the `err_ddct_recall.sh` script to a location where it won't be deleted. 
   For this example we will use `/home/admin` on a Linux server. 
	

2. Set the script to be executable. 

   `chmod 755 err_ddct_recall.sh`

3.   Verify that the ssh key created for Admin Access is installed in `/home/admin/.ssh`


# Usage

   Usage: err_ddct_recall.sh --all --sshid ssh_id_file --user DD_User --ddr DD_Host [--listonly] [--debug].

   Usage: err_ddct_recall.sh --input input_file --sshid ssh_id_file --user DD_User [--ddr DD_Host] [--listonly] [--debug].

   Usage: err_ddct_recall.sh -?\|-h\|--help.

   --all                          Recall all files that have read errors on the Data Domain.
                                  specified by the --ddr option.
   --ddr DD_Host                  Limit the scope to the Data Domain specified by DD_Host.
   --input input_file             Specifies the name of a file that contains a list of files to recall.
                                  The input file must have the full path to the file on the Data Domain.
                                  including the MTree name. Example: /data/col1/cloud_mtree/dir1/file1.
                                  List one file per line in the input_file.
   --listonly                     Only lists files to be recalled on the Data Domain. No recall occurs.
   --sshid ssh_id_file            Specifies the full path to the sshid file to use with Admin Access.
                                  for the Data Domain.
                                    NOTE: It is required to specify the sshid file otherwise the .
                                          server may inspect a local one that requires a password. The
                                          ssh ID file is the one generated for Admin Access to work on
                                          the Data Domain. See the README.MD file for more details.
   --user DD_User                 Specifies the name of the user on the Data Domain with which to
                                  execute commands. This user must be an admin user.
   -?\|-h\|--help                 Display this help message.


# Compatibility

This script was created and tested using Data Domain Virtual Edition v6.0.0.9. 