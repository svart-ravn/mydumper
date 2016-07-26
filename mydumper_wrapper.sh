#!/bin/bash


DB="$1"
OUTPUT_FOLDER="$2"
BACKUP_FOLDER=

###
CHUNK_SIZE=100000
CPU_AMOUNT=
IS_INTERACTIVE=0



# --------------------------------------------------------------------------------------------------
function get_options(){
   local OPTIONS=$@
   local ARGUMENTS=($OPTIONS)
   local index=0

   for ARG in $OPTIONS; do
       index=$(($index+1));
       case $ARG in
         --database|-d) DB="${ARGUMENTS[index]}";;
         --output|-o)   OUTPUT_FOLDER="${ARGUMENTS[index]}";;
         --help|-h)     usage; exit 1;;
      esac
   done
}



# --------------------------------------------------------------------------------------------------
function echo_confirmation(){
cat << EOF
   
   Database:       $DB
   Backup:         $BACKUP_FOLDER
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


# --------------------------------------------------------------------------
function init(){
   local RET=0

   test -t 0 && IS_INTERACTIVE=1
   BACKUP_FOLDER="$OUTPUT_FOLDER/$(date +'%Y%m%d')"

   CPU_AMOUNT=$(($(grep processor /proc/cpuinfo | wc -l)/4*3))
   test $CPU_AMOUNT -eq 0 && CPU_AMOUNT=1

   mkdir -p $BACKUP_FOLDER 2>/dev/null
   if [ $? -ne 0 ]; then
      echo "Can't silently create destination folder: $BACKUP_FOLDER. Exiting..."
      RET=1
   else
      rm -r $BACKUP_FOLDER/* 2>/dev/null
   fi

   mysql $DB -e "select 1" 1>/dev/null 2>&1
   if [ $? -ne 0 ]; then
      echo "Cannot connect to MySQL or database does not exist: $DB"
      RET=1
   fi


   return $RET
}



# ---------------------------------------------------------------------------
get_options $@


init || exit 1

echo_confirmation


mydumper -B $DB -o $BACKUP_FOLDER -r $CHUNK_SIZE -t $CPU_AMOUNT -c -v 3 --events --routines


 $?