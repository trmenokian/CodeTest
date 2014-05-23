
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
      echo "Failed test! Swap must be at least $mem_swap times RAM."
    fi
  fi
"--------------------------------------------------------------------"

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
"------------------------------------------------------------------"


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
	      echo "$mounted_dir not mounted. Failed test!"
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
  "----------------------------------------------------------------------"
  
    echo ""
    echo "----------------------------------------------------"
    echo "- Report JDK install status                        -"
    echo "----------------------------------------------------"

    #Check JDK installed
    if [ -n "`ssh $target ls /prod/rcidb/extern | grep jdk`" ]
    then
      echo "JDK installed."
    else
      echo "JDK not installed. Failed test!"
    fi
  fi
  "----------------------------------------------------------------------"
  if [ $verbose -eq 1 -o ${display_item[16]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report nfshome mount status                      -"
    echo "----------------------------------------------------"

    #Check nfshome is mounted
    if [ -n "`ssh $target mount | grep nfshome`" ]
    then
      echo "nfshome is mounted."
    else
      echo "nfshome is not mounted. Failed test!"
    fi
  fi
"----------------------------------------------------------------------"
  if [ $verbose -eq 1 -o ${display_item[17]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report updatedb configure status                 -"
    echo "----------------------------------------------------"

    #Check updatedb run nightly
    ssh $target cat /etc/updatedb.conf | sed -n 2p | \
        awk '{if ($0 ~ /=yes/ || $0 ~ /=YES/)
               print "updatedb is running nightly."
             else
               print "updatedb is not running nightly. Failed test!"}'
  fi
"-----------------------------------------------------------------------"
  if [ $verbose -eq 1 -o ${display_item[18]} = "yes" ]
  then 
    echo ""
    echo "----------------------------------------------------"
    echo "- Report slocate.cron status                       -"
    echo "----------------------------------------------------"

    #Check slocate.cron exists
    if [ -n "`ssh $target ls /etc/cron.daily | grep slocate.cron`" ]
    then
      echo "/etc/cron.daily/slocate.cron exists."
    else
      echo "/etc/cron.daily/slocate.cron does not exist."
      echo "Failed test!"
    fi
  fi

  
  echo "############### Report $target Over ################"

