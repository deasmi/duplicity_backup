First make sure you have a working install of duplicity
http://duplicity.nongnu.org/

You will also need S3 setup and working with duplicity

Then place the duplicity file into /etc/sysconfig and edit accordingly.
You need to change at least these lines

    KEYID
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_BUCKET

and if you are using a passphrase on the GPG key 

    PASSPHRASE


Now mkdir /etc/duplicity and copy exclude_list and include_list into it
Then edit these files to suit
include_list is used to re-include subdirectories of the exclude_list only
the script will backup everything on the server not in exclude_list
You can also use a single include_list file with + or - at the start of lines, which is  more flexible.
Parsing exits on first match so for example

    - /usr/local/bin
    + /usr/local/
    - /

Will backup everything in /usr/local except /usr/local/bin and nothing else

Finally put duplicity_backup.sh somewhere

After testing setup crob, here is mine. The first script is a db dump script that prepares files duplicity will then backup.

My schedule is a weekly full then twice daily incremental. Purges are also run once a week to keep the total backup sets down, configure the number you want in /etc/sysconfig/duplciity.

Finally I get a weekly status update

    0 1 * * Sun /usr/local/bin/duplicity_backup.sh full
    0 1,13 * * Mon-Sat /usr/local/bin/duplicity_backup.sh incremental
    0 4 * * Sun /usr/local/bin/duplicity_backup.sh status
    0 10 * * Mon /usr/local/bin/duplicity_backup.sh purge

The output form the script will always start with
DUPLICITY_RUN_MODE=<incremental|full|status> etc. so you can filter mails if you only want to see the status ones in your inbox.
