#!/bin/bash

# Read backup configs from env
BACKUP_FTP_SERVER="${BACKUP_FTP_SERVER}"
BACKUP_FTP_USER="${BACKUP_FTP_USER}"
BACKUP_FTP_PASS="${BACKUP_FTP_PASS}"
BACKUP_IGNORE_PATH="${BACKUP_IGNORE_PATH}"
MYSQL_DATABASE="${MYSQL_DATABASE}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
BACKUP_FULL_HOUR="${BACKUP_FULL_HOUR}"

# source and destination for backup file
SOURCE_DIR="/source"
BACKUP_DIR="/backup"

# make backup folder
mkdir -p $BACKUP_DIR

# filename and location generation
TIMESTAMP=$(date +"%Y%m%d_%H%M")
LOCAL_FILE=backup_$TIMESTAMP.zip
DB_BACKUP_FILE=$BACKUP_DIR/db_backup_$TIMESTAMP.sql

# copy files from /mariadb to mysql data directory
mkdir -p /var/lib/mysql/
cp -r $SOURCE_DIR/mariadb/* /var/lib/mysql/
chmod -R 755 /var/lib/mysql
chown -R mysql:mysql /var/lib/mysql
sleep 2
# start mariadb server
mysqld_safe --datadir='/var/lib/mysql' &
sleep 20
# create database backup
mariadb-dump -u root -p"$MYSQL_ROOT_PASSWORD" $MYSQL_DATABASE >$DB_BACKUP_FILE
# stop mariadb server
mysqladmin -u root -p"$MYSQL_ROOT_PASSWORD" shutdown
# zip the SQL file
zip -j $DB_BACKUP_FILE.zip $DB_BACKUP_FILE
# remove additional SQL file
rm $DB_BACKUP_FILE

# upload db file
if [ -n "$BACKUP_FTP_SERVER" ]; then
    curl -s -T "$DB_BACKUP_FILE.zip" --user "$BACKUP_FTP_USER:$BACKUP_FTP_PASS" "ftp://$BACKUP_FTP_SERVER/" -o /dev/null -w "UPLOAD %{http_code}\n"
fi

CURRENT_HOUR=$(date +%H)
CURRENT_MINUTE=$(date +%M)
IGNORE_OPTIONS=""
if [ "$CURRENT_HOUR" -eq $BACKUP_FULL_HOUR ] && [ "$CURRENT_MINUTE" -lt 10 ]; then
    # create zip ignore list form env
    if [ -n "$BACKUP_IGNORE_PATH" ]; then
        for path in $BACKUP_IGNORE_PATH; do
            IGNORE_OPTIONS="$IGNORE_OPTIONS \"$path\""
        done
    fi
    # create zip (without compress: 0) from file and folders (recursive; r) and ignore some files in silence (q)
    cd $SOURCE_DIR
    eval "zip -qr0 $LOCAL_FILE . -x \"backup/*\" \".env*\" $IGNORE_OPTIONS"

    # upload zip file to a ftp server only at 18:00
    if [ -n "$BACKUP_FTP_SERVER" ]; then
        curl -s -T "$LOCAL_FILE" --user "$BACKUP_FTP_USER:$BACKUP_FTP_PASS" "ftp://$BACKUP_FTP_SERVER/" -o /dev/null -w "UPLOAD %{http_code}\n"
    fi
fi

# a function to determine a backup file should keep
should_keep_zip_file() {
    local file=$1
    local filename=$(basename "$file")
    local datetime=$(echo "$filename" | sed -e 's/backup_//' -e 's/.zip//')
    # change filename to valid format for date function
    local formatted_datetime=$(echo "$datetime" | sed 's/\(....\)\(..\)\(..\)_\(..\)\(..\)/\1-\2-\3 \4:\5/')
    local file_time=$(date -d "$formatted_datetime" +%s)
    local current_time=$(date +%s)
    local age=$(((current_time - file_time) / 60)) # سن فایل به دقیقه

    # file keep conditions
    if [ $age -lt 10080 ] && [[ "$datetime" =~ [0-9]{8}_ ]]; then
        return 0 # files created in last 7 days
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}01_ ]]; then
        return 0 # files created in last month that day matched with 01
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}08_ ]]; then
        return 0 # files created in last month that day matched with 08
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}15_ ]]; then
        return 0 # files created in last month that day matched with 15
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}22_ ]]; then
        return 0 # files created in last month that day matched with 22
    elif [ $age -lt 157680 ] && [[ "$datetime" =~ [0-9]{6}01_ ]]; then
        return 0 # files created in last 6 months that day matched with 01
    else
        return 1 # file should remove
    fi
}

# a function to determine a backup file should keep
should_keep_sql_file() {
    local file=$1
    local filename=$(basename "$file")
    local datetime=$(echo "$filename" | sed -e 's/db_backup_//' -e 's/.sql.zip//')
    # change filename to valid format for date function
    local formatted_datetime=$(echo "$datetime" | sed 's/\(....\)\(..\)\(..\)_\(..\)\(..\)/\1-\2-\3 \4:\5/')
    local file_time=$(date -d "$formatted_datetime" +%s)
    local current_time=$(date +%s)
    local age=$(((current_time - file_time) / 60)) # سن فایل به دقیقه

    # file keep conditions
    if [ $age -lt 60 ]; then
        return 0 # files created in last 1h
    elif [ $age -lt 480 ] && [[ "$datetime" =~ [0-9]{8}_[0-9]{2}00 ]]; then
        return 0 # files created in last 8h that minutes matched 00
    elif [ $age -lt 10080 ] && [[ "$datetime" =~ [0-9]{8}_00 ]]; then
        return 0 # files created in last 7 days that hours matched 00
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}01_00 ]]; then
        return 0 # files created in last month that day matched with 01 and hours matched 00
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}08_00 ]]; then
        return 0 # files created in last month that day matched with 08 and hours matched 00
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}15_00 ]]; then
        return 0 # files created in last month that day matched with 15 and hours matched 00
    elif [ $age -lt 43200 ] && [[ "$datetime" =~ [0-9]{6}22_00 ]]; then
        return 0 # files created in last month that day matched with 22 and hours matched 00
    elif [ $age -lt 157680 ] && [[ "$datetime" =~ [0-9]{6}01_00 ]]; then
        return 0 # files created in last 6 months that day matched with 01 and hours matched 00
    else
        return 1 # file should remove
    fi
}

# checking zip file and remove them base on condition
for file in "$BACKUP_DIR"/backup_*.zip; do
    if ! should_keep_zip_file "$file"; then
        rm -f "$file"
        # remove file from ftp server
        if [ -n "$BACKUP_FTP_SERVER" ]; then
            curl -s -u "$BACKUP_FTP_USER:$BACKUP_FTP_PASS" "ftp://$BACKUP_FTP_SERVER" -Q "-DELE $(basename $file)" -o /dev/null -w "DELETE $file %{http_code}\n"
        fi
    fi
done

# checking sql file and remove them base on condition
for file in "$BACKUP_DIR"/db_backup_*.sql.zip; do
    if ! should_keep_sql_file "$file"; then
        rm -f "$file"
        # remove file from ftp server
        if [ -n "$BACKUP_FTP_SERVER" ]; then
            curl -s -u "$BACKUP_FTP_USER:$BACKUP_FTP_PASS" "ftp://$BACKUP_FTP_SERVER" -Q "-DELE $(basename $file)" -o /dev/null -w "DELETE $file %{http_code}\n"
        fi
    fi
done

sync
