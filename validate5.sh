#!/bin/bash

declare -a servers=()
declare -a lib_check=()
declare -a display_item=()
declare -a fstab_entries=()
#Updated: there is now uniformity with the pass and fail, fstab entires are up to date. slocate.cron became mlocate.cron. JDK changed from /prod/rcidb/extern  to /work2/extern. 
#nfsmount is uncommented but not removed.
function validate()
{
  target=$1
  fail_count=0
  echo ""
  echo "####################################################"
  echo "-             Report $target Start                  "
  echo "- Validating remote Server:" $target
  echo "####################################################"
  echo ""
  #printf "%-30s%s\n" "Validating Server: " $target

  echo ""
  echo "----------------------------------------------------"
  echo "- Report SSH accessable                            -"
  echo "----------------------------------------------------"

  #Don't proceed if SSH access can not be established.
  ssh $target ls /usr 1>/dev/null 2>&1
  if [ $? -ne 0 ]
  then
    echo "FAILED! , SSH access denied" >>fmessage
    echo "FAILED! , SSH access denied"
    echo "1. SSH keys have not been setup."
    echo "2. It is the first time to run SSH."
    echo "3. Host ID has been changed."
    echo "4. The server name is wrong."
    echo "Run \"ssh $target\" and you will know the cause."
    echo "For 1, run \"ssh-keygen\" to generate the keys."
    echo "For 2, run \"ssh $target\" and follow the instructions."
    echo "For 3, run \"ssh-keygen -R $target\" to remove the"
    echo "    old host id from the known_hosts file."
    echo "For 4, make sure the server name is correct."
    fail_count=`expr $fail_count+1`
    return
  fi
  echo "PASSED! SSH is ok"

  #Report RAM per core
  memory_total=`ssh $target cat /proc/meminfo | grep MemTotal`
  memory_total=${memory_total##*:} #Get its integer part
  memory_total=${memory_total% *}
  memory_total=`echo $memory_total | tr -d " "`
  MEM_MIN=`expr $mem_min \* 1000 \* 1000`

  #Get the cpu core number
  cpu_core=`ssh $target cat /proc/cpuinfo | grep "cpu cores" | wc -l`
  #Get RAM of every core
  memory_per_core=`expr $memory_total / $cpu_core`
  if [ $verbose -eq 1 -o ${display_item[0]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report RAM value: Total and per core             -"
    echo "----------------------------------------------------"

    echo "Memory total is: $memory_total kB"
    echo "Memory per core is: $memory_per_core kB"
    if [ $memory_per_core -lt $MEM_MIN ]
    then
      echo "FAILED! Ram must be at least $mem_min GB per each core." >>fmessage
      echo "FAILED! Ram must be at least $mem_min GB per each core."
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[1]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report Swap space                                -"
    echo "----------------------------------------------------"

    #Report swap space
    ram_mem=`expr $memory_total \* $mem_swap` #the expected swap size
    memory_total=`ssh $target cat /proc/meminfo | grep SwapTotal`
    memory_total=${memory_total##*:} #Get its integer part
    memory_total=${memory_total% *}
    echo "Swap space is: $memory_total kB"
    if [ $memory_total -lt $ram_mem ]
    then
      echo "FAILED! Swap must be at least $mem_swap times RAM." >>fmessage
      echo "FAILED! Swap must be at least $mem_swap times RAM."
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[2]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report Disk speed                                -"
    echo "----------------------------------------------------"

    #Report disk speed
    speed=`ssh $target cat /proc/sys/dev/raid/speed_limit_min`
    echo "The minimum aggregate disk speed is: $speed RPM"
    speed=`ssh $target cat /proc/sys/dev/raid/speed_limit_max`
    echo "The maximum aggregate disk speed is: $speed RPM"
  fi
  
  if [ $verbose -eq 1 -o ${display_item[3]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report CPU information                           -"
    echo "----------------------------------------------------"

    #Report cpu speed
    ssh $target cat /proc/cpuinfo | awk -v check="$cpu_speed_min" 'BEGIN {rec_count = 1
        flag = 0
        printf "%-8s %-10s %-10s %-10s\n", "CPU", "Type", "Speed", "Cache size"}
        /model name/ {printf "%3s%d %12s %10s", "Cpu", rec_count, $4, $9
        speed = substr($9, 1, length($9) - 6)
        if (speed == "@") 
          speed = substr($10, 1, length($10) - 6)
        if (speed < check)
          flag = 1}
        /cache size/ {printf " %7s KB\n", $4; rec_count++}
        END {if (flag == 1) printf "FAILED! CPU speed at least %d GHz", check}'
  fi

  if [ $verbose -eq 1 -o ${display_item[4]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report Disk usage                                -"
    echo "----------------------------------------------------"

    #Report disk usage
    #The df report for a device occupies 1 or 2 lines. Process both cases
    ssh $target df | awk 'BEGIN {printf "%-30s %10s %10s\n", "Filesystem", "Available", "Use"}
        {if (NR > 1 && NF == 6) {printf "%-30s %10s %10s\n", $1, $4, $5}
         if (NR > 1 && NF == 1) {printf "%-30s", $1}
         if (NR > 1 && NF == 5) {printf " %10s %10s\n", $3, $4}}'
  fi

  if [ $verbose -eq 1 -o ${display_item[5]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report OS kernel type && OS Bit type             -"
    echo "----------------------------------------------------"

    #Report OS kernel type
    os_type_local=`ssh $target uname -s`
    echo "OS kernel type: $os_type_local"
    if [ $os_type_local != $os_type ]
    then
      echo "FAILED! OS should be $os_type" >>fmessage
      echo "FAILED! OS should be $os_type"
      fail_count=`expr $fail_count+1`
    fi

    #Report OS bit type
    bit_count=`ssh $target getconf LONG_BIT`
    echo "OS bit type: $bit_count"
    if [ $bit_count -lt $os_bit ]
    then
      echo "FAILED! OS bit should be at least $os_bit" >>fmessage
      echo "FAILED! OS bit should be at least $os_bit"
      fail_count=`expr $fail_count+1`
    fi

    #Report OS version
    cur_version=`ssh $target lsb_release -r`
    cur_version=${cur_version##*:}
    cur_version=`echo $cur_version | tr -d " "`
    version_orig=$cur_version
    cur_version=${cur_version%%.*}
    if [ $cur_version -lt $os_version ]
    then
      echo "FAILED! OS version: $version_orig." >>fmessage
      echo "FAILED! OS version: $version_orig." 
      fail_count=`expr $fail_count+1`
      echo "Should be $os_version or higher."
    else
      echo "PASSED! OS version: $version_orig" 
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[6]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report OS installed libs                         -"
    echo "----------------------------------------------------"

    echo "Installed libraries:"
    #check libraries
    for libitem in ${lib_check[@]}
    do
      ssh $target rpm -qa | grep $libitem 1>/dev/null 2>&1
      if [ $? -ne 0 ]
      then
        echo "FAILED! $libitem is not installed." >>fmessage
        echo "FAILED! $libitem is not installed." 
         fail_count=`expr $fail_count+1`
      else
        echo "PASSED! $libitem is installed"
      fi
    done
  fi

  if [ $verbose -eq 1 -o ${display_item[7]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report OS file descriptor                        -"
    echo "----------------------------------------------------"

    #Check file descriptor
    count=`ssh $target ulimit -n`
    echo "Maximum file descriptor number = $count"
    if [ $count -lt $file_desc ]
    then
      echo "FAILED! File descriptor number be at least $file_desc" >>fmessage
      echo "FAILED! File descriptor number be at least $file_desc"
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[8]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report OS host file                              -"
    echo "----------------------------------------------------"

    #Check host file contains local loop adress
    if [ -z "`ssh $target cat /etc/hosts | grep 127.0.0.1`" ]
    then
      echo "FAILED! Host file does not contain 127.0.0.1." >>fmessage
      echo "FAILED! Host file does not contain 127.0.0.1."  
      fail_count=`expr $fail_count+1`
    else
      echo "PASSED! Host file contains 127.0.0.1"
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[9]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report OS DNS                                    -"
    echo "----------------------------------------------------"

    #Check hostname, DNS entry and reverse DNS lookup availability
    #We need to discard warning messages because nslookup has ">>" warning msg.
    if [ -z "`ssh $target hostname -f | ssh $target nslookup - 2>/dev/null | grep .  \
        | tail -1 | cut -c10- | ssh $target nslookup - 2>/dev/null`" ]
    then
      echo "FAILED! hostname, DNS and reverse DNS do not work." >>fmessage
      echo "FAILED! hostname, DNS and reverse DNS do not work."
      fail_count=`expr $fail_count+1`
    else
      echo "PASSED! hostname, DNS and reverse DNS works OK."
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[10]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report $esp_root owner                           -"
    echo "----------------------------------------------------"

    #Check $esp_root owner
    ssh $target ls -l $esp_root 1>/dev/null 2>&1
    if [ $? -ne 0 ]
    then
      echo "FAILED! $esp_root is not a valid directory." >>fmessage
      echo "FAILED! $esp_root is not a valid directory." 
      fail_count=`expr $fail_count+1`
    else
      echo $esp_root " directory owner:"
      esp_root_tmp=`echo $esp_root | sed 's/\/\(.*\)/\1/'`
      ssh $target ls -l / | grep $esp_root_tmp | awk '{print "   " $3}'      
    fi
  fi


  if [ $verbose -eq 1 -o ${display_item[11]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report mounted folders's sub-folders owner       -"
    echo "----------------------------------------------------"

    #Check $mounted_dirs mounted
    for mounted_dir in ${mounted_dirs[@]}
    do
      if [ -n "`ssh $target ls -l $mounted_dir 2>/dev/null`" ]
      then
        check_flag=1
      else
        check_flag=0
        echo "FAILED! $mounted_dir not mounted." 
        echo "FAILED! $mounted_dir not mounted." >>fmessage
        fail_count=`expr $fail_count+1`
      fi
      if [ $check_flag -eq 1 ]
      then
        #Check $mounted_dir sub-folders
        echo "$mounted_dir sub-folders:"
        #Ony report sub-directories
        ssh $target ls -l $mounted_dir | awk '{if (substr($1,1,1)=="d")
                                           printf("%-15s %s\n",$9,$1)}'
      fi
    done
  fi
  
  if [ $verbose -eq 1 -o ${display_item[19]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report fstab entries validation                  -"
    echo "----------------------------------------------------"

    echo "Check expected fstab entries:"
    #Check fstab entries
    #for fstab_entry in "${fstab_entries[@]}"
    num=0
    while [ $num -lt ${#fstab_entries[*]} ]
    do
      pattern=`echo ${fstab_entries[$num]} | sed 's/\s\s*/\[\[:space:\]\].*/g'`
      if [ -z "`ssh $target cat /etc/fstab 2>/dev/null | grep \"$pattern\"`" ]
      then
        echo "FAILED! ${fstab_entries[$num]}" >>fmessage
        echo "FAILED! ${fstab_entries[$num]}" 
        fail_count=`expr $fail_count+1`
      else
        echo "PASSED! ${fstab_entries[$num]}"
      fi
      ((num++))
    done
  fi


  if [ $verbose -eq 1 -o ${display_item[12]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report JDK install status                        -"
    echo "----------------------------------------------------"

    #Check JDK installed
    if [ -n "`ssh $target ls /work2/extern | grep jdk`" ]
    then
      echo "PASSED! JDK installed."
    else
      echo "FAILED! JDK not installed." >>fmessage
      echo "FAILED! JDK not installed."
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[13]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report perl install status                       -"
    echo "----------------------------------------------------"

    #Check perl installed
    if [ -n "`ssh $target ls /usr/bin | grep perl`" ]
    then
      echo "PASSED! Perl installed."
    else
      echo "FAILED! Perl not installed.">>fmessage
      echo "FAILED! Perl not installed."
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[14]} = "yes" ]
  then
    echo ""
    echo "----------------------------------------------------"
    echo "- Report ntpd running status                       -"
    echo "----------------------------------------------------"

    #Check ntpd is running
    user_name=`whoami`
    if [ -n "`ssh $target ps aux | grep ntpd | egrep -v $user_name`" ]
    then
      echo "PASSED! ntpd is running."
    else
      echo "FAILED! ntpd is not running." 
      echo "FAILED! ntpd is not running." >>fmessage
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[15]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report gnome running status                      -"
    echo "----------------------------------------------------"

    #Check gnome is running
    if [ -n "`ssh $target ps aux | grep gnome |grep -v grep`" ]
    then
      echo "FAILED! gnome is running."
      echo "FAILED! gnome is running." >>fmessage
      fail_count=`expr $fail_count+1`
    else
      echo "PASSED! gnome is not running."
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[16]} = "yes" ]
  then 
     echo ""
     echo "----------------------------------------------------"
     echo "-                                                  -"
     echo "----------------------------------------------------"

    # #Check nfshome is mounted
    # if [ -n "`ssh $target mount | grep nfshome`" ]
    # then
      # echo "PASSED! nfshome is mounted."
    # else
      # echo "FAILED! nfshome is not mounted."
    # fi
  fi

  if [ $verbose -eq 1 -o ${display_item[17]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report updatedb configure status                 -"
    echo "----------------------------------------------------"

    #Check updatedb run nightly
    ssh $target cat /etc/updatedb.conf | sed -n 2p | \
        awk '{if ($0 ~ /=yes/ || $0 ~ /=YES/)
               print "PASSED! updatedb is running nightly."
             else
               print "FAILED! updatedb is not running nightly."
               }' >>fmessage
  fi

  if [ $verbose -eq 1 -o ${display_item[18]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report mlocate.cron status                       -"
    echo "----------------------------------------------------"

    #Check mlocate.cron exists
    if [ -n "`ssh $target ls /etc/cron.daily | grep mlocate.cron`" ]
    then
      echo "PASSED! /etc/cron.daily/mlocate.cron exists."
    else
      echo "FAILED! /etc/cron.daily/mlocate.cron does not exist." >>fmessage
      echo "FAILED! /etc/cron.daily/mlocate.cron does not exist."
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[20]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report Time Zone                                 -"
    echo "----------------------------------------------------"

    echo "Check expected time zone:"
    thistz=`ssh -n $target date | cut -d ' ' -f5 `
    hasTimeZone=`echo $thistz |grep T  |wc -l`
    if [ "$hasTimeZone" = "0" ]
    then
      thistz=`ssh -n $target date | cut -d ' ' -f6 `
    fi
    if [ "$thistz" = "$time_zone" ]
    then
  
      echo "PASSED! Time Zone match"
    else
      echo "FAILED! Wrong Time Zone: $thistz. It should be: $time_zone" >>fmessage
      echo "FAILED! Wrong Time Zone: $thistz. It should be: $time_zone" 
      fail_count=`expr $fail_count+1`
    fi
  fi

  if [ $verbose -eq 1 -o ${display_item[20]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report hostname                                 -"
    echo "----------------------------------------------------"
    user_name=`whoami`
    hostnm=`ssh -x -a -l $user_name -oStrictHostKeyChecking=no $target hostname --fqdn`
    if [ "$hostnm" = "$target" ]
    then
      echo "PASSED! host name match"
    else
      echo "FAILED! Wrong Host Name: $hostnm. It should be: $target" >>fmessage
      echo "FAILED! Wrong Host Name: $hostnm. It should be: $target" 
      fail_count=`expr $fail_count+1`
    fi
  fi
  echo ""
  echo "############### Report $target Over ################"
  if [ $fail_count>0 ]
  then
    echo "-----------------------------------------------">>testfile43
    echo "Server:  $target">>testfile43
    echo "-----------------------------------------------">>testfile43
    egrep 'FAILED' fmessage>>testfile43
    `rm -rf fmessage`
    #sending email to recipiants
    SUBJECT="ERRORS IN VALIDATION"
    EMAIL="r.chen@thomsonreuters.com"
    /bin/mail -s "$SUBJECT" "$EMAIL" < testfile43
  fi
  fail_count=0
#done
}

verbose=0
config_file=""
report_file=""
while getopts "vc:r:" optionName; do
case "$optionName" in
v) verbose=1;;
c) config_file="$OPTARG";;
r) report_file="$OPTARG";;
*) echo "Usage: validate.sh [-v] -c config_file [-r report_file]";
   exit;;
esac
done

if [ -z $config_file ]
then
  echo "Usage: validate.sh [-v] -c config_file [-r report_file]";
  exit
fi
if [ ! -e $config_file ]
then
  echo "\"$config_file\" does not exist!"
  exit
fi

while read line
do
  if `echo $line | grep "Server Name" 1>/dev/null 2>&1`
  then
    #Get configure servers to array
    server=`echo $line | sed 's/<Server Name>\(.*\)<\/Server Name>/\1/'`
    servers[${#servers[*]}]=$server
  elif `echo $line | grep "Required Lib" 1>/dev/null 2>&1`
  then
    #Get get library names to be checked
    libitem=`echo $line | sed 's/<Required Lib>\(.*\)<\/Required Lib>/\1/'`
    lib_check[${#lib_check[*]}]=$libitem
  elif `echo $line | grep "ESP Dir" 1>/dev/null 2>&1`
  then
    #Get FAST ESP root directory
    esp_root=`echo $line | sed 's/<ESP Dir>\(.*\)<\/ESP Dir>/\1/'`
  elif `echo $line | grep "Mounted Dir" 1>/dev/null 2>&1`
  then
    #Get mounted directories
    mounted_dir=`echo $line | sed 's/<Mounted Dir>\(.*\)<\/Mounted Dir>/\1/'`
    mounted_dirs[${#mounted_dirs[*]}]=$mounted_dir
  elif `echo $line | grep "Fstab Entry" 1>/dev/null 2>&1`
  then
    #Get fstab entries
    fstab_entry=`echo $line | sed 's/<Fstab Entry>\(.*\)<\/Fstab Entry>/\1/'`
    fstab_entries[${#fstab_entries[*]}]=$fstab_entry
  elif `echo $line | grep "Fstab File" 1>/dev/null 2>&1`
  then
    #Get fstab file
    fstab_file=`echo $line | sed 's/<Fstab File>\(.*\)<\/Fstab File>/\1/'`
  elif `echo $line | grep "OS Type" 1>/dev/null 2>&1`
  then
    #Get OS type
    os_type=`echo $line | sed 's/<OS Type>\(.*\)<\/OS Type>/\1/'`
  elif `echo $line | grep "OS Bit" 1>/dev/null 2>&1`
  then
    #Get OS bit
    os_bit=`echo $line | sed 's/<OS Bit>\(.*\)<\/OS Bit>/\1/'`
  elif `echo $line | grep "OS Version" 1>/dev/null 2>&1`
  then
    #Get OS version
    os_version=`echo $line | sed 's/<OS Version>\(.*\)<\/OS Version>/\1/'`
  elif `echo $line | grep "Mem Swap" 1>/dev/null 2>&1`
  then
    #Get Mem Swap ratio
    mem_swap=`echo $line | sed 's/<Mem Swap>\(.*\)<\/Mem Swap>/\1/'`
  elif `echo $line | grep "CPU Speed" 1>/dev/null 2>&1`
  then
    #Get minimum cpu speed
    cpu_speed_min=`echo $line | sed 's/<CPU Speed>\(.*\)<\/CPU Speed>/\1/'`
  elif `echo $line | grep "Mem Min" 1>/dev/null 2>&1`
  then
    #Get minimum ram
    mem_min=`echo $line | sed 's/<Mem Min>\(.*\)<\/Mem Min>/\1/'`
  elif `echo $line | grep "File Desc" 1>/dev/null 2>&1`
  then
    #Get file descriptor count
    file_desc=`echo $line | sed 's/<File Desc>\(.*\)<\/File Desc>/\1/'`
  elif `echo $line | grep "Time Zone" 1>/dev/null 2>&1`
  then
    #Get Time Zone 
    time_zone=`echo $line | sed 's/<Time Zone>\(.*\)<\/Time Zone>/\1/'`
  elif `echo $line | grep "Display Tag" 1>/dev/null 2>&1`
  then
    display_content=`echo $line | sed 's/<Display Tag>\(.*\)<\/Display Tag>/\1/'`
    [[ $display_content =~ "RAM=yes" ]] && display_item[0]="yes"
    [[ $display_content =~ "RAM=no" ]] && display_item[0]="no"
    [[ $display_content =~ "SWAP=yes" ]] && display_item[1]="yes"
    [[ $display_content =~ "SWAP=no" ]] && display_item[1]="no"
    [[ $display_content =~ "DISKSPEED=yes" ]] && display_item[2]="yes"
    [[ $display_content =~ "DISKSPEED=no" ]] && display_item[2]="no"
    [[ $display_content =~ "CPUSPEED=yes" ]] && display_item[3]="yes"
    [[ $display_content =~ "CPUSPEED=no" ]] && display_item[3]="no"
    [[ $display_content =~ "DISKUSAGE=yes" ]] && display_item[4]="yes"
    [[ $display_content =~ "DISKUSAGE=no" ]] && display_item[4]="no"
    [[ $display_content =~ "OS=yes" ]] && display_item[5]="yes"
    [[ $display_content =~ "OS=no" ]] && display_item[5]="no"
    [[ $display_content =~ "OSLIB=yes" ]] && display_item[6]="yes"
    [[ $display_content =~ "OSLIB=no" ]] && display_item[6]="no"
    [[ $display_content =~ "OSFILE=yes" ]] && display_item[7]="yes"
    [[ $display_content =~ "OSFILE=no" ]] && display_item[7]="no"
    [[ $display_content =~ "OSHOST=yes" ]] && display_item[8]="yes"
    [[ $display_content =~ "OSHOST=no" ]] && display_item[8]="no"
    [[ $display_content =~ "DNS=yes" ]] && display_item[9]="yes"
    [[ $display_content =~ "DNS=no" ]] && display_item[9]="no"
    [[ $display_content =~ "ESPOWNER=yes" ]] && display_item[10]="yes"
    [[ $display_content =~ "ESPOWNER=no" ]] && display_item[10]="no"
    [[ $display_content =~ "SUBDIR=yes" ]] && display_item[11]="yes"
    [[ $display_content =~ "SUBDIR=no" ]] && display_item[11]="no"
    [[ $display_content =~ "JDK=yes" ]] && display_item[12]="yes"
    [[ $display_content =~ "JDK=no" ]] && display_item[12]="no"
    [[ $display_content =~ "PERL=yes" ]] && display_item[13]="yes"
    [[ $display_content =~ "PERL=no" ]] && display_item[13]="no"
    [[ $display_content =~ "NTPD=yes" ]] && display_item[14]="yes"
    [[ $display_content =~ "NTPD=no" ]] && display_item[14]="no"
    [[ $display_content =~ "GNOME=yes" ]] && display_item[15]="yes"
    [[ $display_content =~ "GNOME=no" ]] && display_item[15]="no"
    [[ $display_content =~ "NFSHOME=yes" ]] && display_item[16]="yes"
    [[ $display_content =~ "NFSHOME=no" ]] && display_item[16]="no"
    [[ $display_content =~ "UPDATEDB=yes" ]] && display_item[17]="yes"
    [[ $display_content =~ "UPDATEDB=no" ]] && display_item[17]="no"
    [[ $display_content =~ "SLOCATE=yes" ]] && display_item[18]="yes"
    [[ $display_content =~ "SLOCATE=no" ]] && display_item[18]="no"
    [[ $display_content =~ "FSTAB=yes" ]] && display_item[19]="yes"
    [[ $display_content =~ "FSTAB=no" ]] && display_item[19]="no"
    [[ $display_content =~ "TZ=yes" ]] && display_item[20]="yes"
    [[ $display_content =~ "TZ=no" ]] && display_item[20]="no"
  fi
done < $config_file

if [ ${#server[*]} -eq 0 ]
then
  echo "Need to configure server."
  exit
fi
if [ ${#lib_check[*]} -eq 0 ]
then
  echo "Need to configure lib items."
  exit
fi
if [ -z "$esp_root" ]
then
  echo "Need to configure esp root."
  exit
fi
if [ ${#mounted_dirs[*]} -eq 0  ]
then
  echo "Need to configure mounted directories."
  exit
fi
if [ ${#fstab_entries[*]} -eq 0  -a -z "$fstab_file" ]
then
  echo "Need to configure fstab entries or file."
  exit
elif [ ${#fstab_entries[*]} -ne 0  -a -n "$fstab_file" ]
  then
    echo "Fstab entries can't exist concurrently with fstab file"
    exit
elif [ -n "$fstab_file" -a ! -e "$fstab_file" ]
  then
    echo "$fstab_file doesn't exit!"
    exit
elif [ -n "$fstab_file" -a -e "$fstab_file" ]
  then
    while read fstab_entry
    do
      fstab_entries[${#fstab_entries[*]}]=$fstab_entry
    done < $fstab_file
fi
if [ -z "$os_type" ]
then
  echo "Need to configure os type."
  exit
fi
if [ -z "$os_bit" ]
then
  echo "Need to configure os bit."
  exit
fi
if [ -z "$os_version" ]
then
  echo "Need to configure os version."
  exit
fi
if [ -z "$mem_swap" ]
then
  echo "Need to configure memory swap ratio."
  exit
fi
if [ -z "$cpu_speed_min" ]
then
  echo "Need to configure minimum cpu speed."
  exit
fi
if [ -z "$mem_min" ]
then
  echo "Need to configure minimum memory size."
  exit
fi
if [ -z "$file_desc" ]
then
  echo "Need to configure minimum file descriptor."
  exit
fi
if [ -z "$time_zone" ]
then
  echo "Need to configure time zone."
  exit
fi

config_ok=1
i=0
while [ $i -le 19 ]
do
  if [ -z "${display_item[$i]}" ]
  then
    config_ok=0
    case $i in
    0) echo "Need to configure RAM=yes/no" ;;
    1) echo "Need to configure SWAP=yes/no" ;;
    2) echo "Need to configure DISKSPEED=yes/no" ;;
    3) echo "Need to configure CPUSPEED=yes/no" ;;
    4) echo "Need to configure DISKUSAGE=yes/no" ;;
    5) echo "Need to configure OS=yes/no" ;;
    6) echo "Need to configure OSLIB=yes/no" ;;
    7) echo "Need to configure OSFILE=yes/no" ;;
    8) echo "Need to configure OSHOST=yes/no" ;;
    9) echo "Need to configure DNS=yes/no" ;;
    10) echo "Need to configure ESPOWNER=yes/no" ;;
    11) echo "Need to configure SUBDIR=yes/no" ;;
    12) echo "Need to configure JDK=yes/no" ;;
    13) echo "Need to configure PERL=yes/no" ;;
    14) echo "Need to configure NTPD=yes/no" ;;
    15) echo "Need to configure GNOME=yes/no" ;;
    16) echo "Need to configure NFSHOME=yes/no" ;;
    17) echo "Need to configure UPDATEDB=yes/no" ;;
    18) echo "Need to configure SLOCATE=yes/no" ;;
    19) echo "Need to configure FSTAB=yes/no" ;;
    20) echo "Need to configure TZ=yes/no" ;;
    esac
  fi
  i=$(($i+1))
done

if [ $config_ok -eq 0 ]
then
  echo "Corrupted configuration file."
  exit
fi

for entity in ${servers[@]}
do
  #validate every server
  if [ -z $report_file ]
  then
    validate $entity
  else
    validate $entity >> $report_file
  fi
done

