#!/bin/bash

DTM=$(date +'%Y_%d_%m__%H_%M_%S')
DTM=$(date +'%Y_%d_%m')


DB_TO_BACKUP=


BACKUP_SCHEMA_FILE=schema_$DTM
LOG_FILE=dump_${DTM}.log
LOG_FILE_PATH=./


BACKUP_PATH=
BACKUP_FOLDER_FULL=
BACKUP_FOLDER=

CPU_AMOUNT=1
IS_INTERACTIVE=0
IS_INCREMENTAL=0

#  /tmp/backup
#              20160701
#              20160708
#              20160719
#              increment
#              current_20160725
# 
# 
# 


# --------------------------------------------------------------------------------------------------
function get_options(){
   local OPTIONS=$@
   local ARGUMENTS=($OPTIONS)
   local index=0

   for ARG in $OPTIONS; do
       index=$(($index+1));
       case $ARG in
         --databases|-d)   DB_TO_BACKUP="${ARGUMENTS[index]}";;
         --backup-path|-p) BACKUP_PATH="${ARGUMENTS[index]}";;
         --help|-h)        usage; exit 1;;
      esac
   done
}



# --------------------------------------------------------------------------------------------------
function init_folder(){
   sudo -u mysql mkdir -p $BACKUP_PATH/$BACKUP_FOLDER
   sudo -u mysql mkdir -p $BACKUP_PATH/$BACKUP_FOLDER_FULL

   test $IS_INCREMENTAL -eq 1 && sudo -u mysql rm -rf $BACKUP_PATH/$BACKUP_FOLDER/* 2>/dev/null
}



# --------------------------------------------------------------------------------------------------
function init(){
   # setup backup folders
   CURRENT_BACKUP_FOLDER=$(ls $BACKUP_PATH 2>/dev/null | grep -i current)

   if [ -z "$CURRENT_BACKUP_FOLDER" ] || [ $(ls $BACKUP_PATH/$CURRENT_BACKUP_FOLDER 2>/dev/null | wc -l) -eq 0 ]; then
      IS_INCREMENTAL=0
   else
      IS_INCREMENTAL=1
   fi

   if [ $IS_INCREMENTAL -eq 0 ]; then
      BACKUP_FOLDER="current_$DTM"
      BACKUP_FOLDER_FULL=$BACKUP
   else
      BACKUP_FOLDER="incremental"
      BACKUP_FOLDER_FULL=$CURRENT_BACKUP_FOLDER
   fi

   mkdir -p $LOG_FILE_PATH

   # CPU
   local CPU_AMOUNT=$(($(grep -c ^processor /proc/cpuinfo)/4*3))
   test $CPU_AMOUNT -eq 0 && CPU_AMOUNT=1

   # DB setup
   if [ -z "$DB_TO_BACKUP" ]; then
      DB_TO_BACKUP=$(mysql -BN -e 'show databases' | tr '\n' ',' | sed 's/,$//g')
   else
      DB_TO_BACKUP="${DB_TO_BACKUP},mysql,sys,information_schema,performance_schema"
   fi

   # rest
   test -t 0 && IS_INTERACTIVE=1


   return 0
}


                                                                                                                                                                                                                                                                                                                           
# --------------------------------------------------------------------------------------------------
function echo_confirmation(){
cat << EOF

   Basic path:     $BACKUP_PATH
   Innodb backup:      $BACKUP_FOLDER   $(test $IS_INCREMENTAL -eq 1 && echo " -> $BACKUP_PATH/$BACKUP_FOLDER_FULL")
   Schema backup:      $BACKUP_SCHEMA_FILE
   
   Databases:      $DB_TO_BACKUP
   Log file:       $LOG_FILE_PATH/$LOG_FILE

   incremental?:   $IS_INCREMENTAL 
   Interactive?:   $IS_INTERACTIVE
   Amount of cpu:  $CPU_AMOUNT

EOF

   if [ $IS_INTERACTIVE -eq 1 ]; then
      read -p "Would you like to continue? (yY/N): " ANSWER
      if [ ! "$ANSWER" == "y" ] && [ ! "$ANSWER" == "Y" ]; then
         echo -e "Okay. Exiting...\n"
         exit 2
      fi
   fi

}



# --------------------------------------------------------------------------------------------------
function usage(){
   echo "Help will be there...."
   exit 0
}



# --------------------------------------------------------------------------------------------------
function trap_exit(){
   echo "Going to exit from backup script. You have to run it again"
   clear_current_backup_folder

   return 0
}



# --------------------------------------------------------------------------------------------------
function backup(){
   local DB_USER=$(grep '^user' ~/.my.cnf | cut -d '=' -f2 | sed 's/ //g')
   local DB_PASSWORD=$(grep '^password' ~/.my.cnf | cut -d '=' -f2 | sed 's/ //g')

   DB_PATTERN=$(echo $DB_TO_BACKUP | tr ',' '\n' | awk '{print "(" $0 "[.].*)"}' | tr '\n' '|' | sed 's/|$//g')

   ARGS="--no-timestamp --user=${DB_USER} --password=${DB_PASSWORD} --parallel=$CPU_AMOUNT"
   if [ $IS_INCREMENTAL == 0 ]; then
      sudo -u mysql innobackupex $ARGS --include="$DB_PATTERN" $BACKUP_PATH/$BACKUP_FOLDER > $LOG_FILE_PATH/$LOG_FILE 2>&1
   else
      sudo -u mysql innobackupex $ARGS --include="$DB_PATTERN" --incremental $BACKUP_PATH/$BACKUP_FOLDER --incremental-basedir=$BACKUP_PATH/$BACKUP_FOLDER_FULL > $LOG_FILE_PATH/$LOG_FILE 2>&1
   fi

   tail -1 $LOG_FILE_PATH/$LOG_FILE | grep -q "completed OK!"
   return $?
}



# --------------------------------------------------------------------------------------------------
function clear_current_backup_folder(){
   echo "Deleting backup folder $BACKUP_PATH/$BACKUP_FOLDER"
   sudo -u mysql rm -rf $BACKUP_PATH/$BACKUP_FOLDER
}



# --------------------------------------------------------------------------------------------------
function apply_logs(){
   if [ $IS_INCREMENTAL -eq 0 ]; then
      sudo -u mysql innobackupex --apply-log --redo-only "$BACKUP_PATH/$BACKUP_FOLDER" >> $LOG_FILE_PATH/$LOG_FILE 2>&1
   else
      sudo -u mysql innobackupex --apply-log-only  --incremental-dir="$BACKUP_PATH/$BACKUP_FOLDER" "$BACKUP_PATH/$BACKUP_FOLDER_FULL"  >> $LOG_FILE_PATH/$LOG_FILE 2>&1
   fi

   tail -1 $LOG_FILE_PATH/$LOG_FILE | grep -q "completed OK!"
   RET=$?
   
   if [ $RET -eq 0 ] && [ $IS_INCREMENTAL -eq 1 ]; then
      local TMP_FOLDER=$(ls -t $BACKUP_PATH/$BACKUP_FOLDER_FULL/ | head -1)

      sudo -u mysql mkdir -p $BACKUP_PATH/$TMP_FOLDER
      sudo -u mysql mv $BACKUP_PATH/$BACKUP_FOLDER_FULL/$TMP_FOLDER/ $BACKUP_PATH/
      sudo -u mysql rm -rf "$BACKUP_PATH/$BACKUP_FOLDER_FULL/"*
      sudo -u mysql bash -c "cd $BACKUP_PATH/$TMP_FOLDER; cp -R * $BACKUP_PATH/$BACKUP_FOLDER_FULL/"
      sudo -u mysql rm -rf $BACKUP_PATH/$TMP_FOLDER
   fi

   return $RET
}



# --------------------------------------------------------------------------------------------------
function backup_schema(){
   mysqldump --opt --single-transaction --no-data  --databases $(echo $DB_TO_BACKUP | tr ',' ' ') | pigz | sudo -u mysql tee "$BACKUP_PATH/$BACKUP_SCHEMA_FILE.sql.gz" > /dev/null
}



# --------------------------    MAIN    ------------------------------------------------------------

get_options $@

init

echo_confirmation

init_folder

trap trap_exit INT

echo "dumping schema..."
backup_schema

echo "Starting backup...."
if backup; then
   echo "going to apply-log logs"
   
   if ! apply_logs; then
      echo "Applying logs failed..."
      clear_current_backup_folder
   fi
else
   echo -e "Backup failed for some reasons...\nCheck logs: $LOG_FILE_PATH/$LOG_FILE"
   # clear_current_backup_folder
   exit 1
fi


echo "Completed. OK!"

exit 0
