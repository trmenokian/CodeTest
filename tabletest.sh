#!/bin/bash
CSV='./test.csv'
column_width=(20 6 5 10 10 10 10 8 30)

IFS=","
        while read LINE
        do
                set -- $LINE
                arg=($@)
                for (( i = 0 ; i < ${#arg[@]} ; i++))
                do
                        case $i in
                                1) printf "%-20s"   ${arg[$i]} ;;
                                2) printf "%-6s"    ${arg[$i]} ;;
                                3) printf "%-5s"    ${arg[$i]} ;;
                                4) printf "%-10s"   ${arg[$i]} ;;
                                5) printf "%-10s"   ${arg[$i]} ;;
                                6) printf "%-10s"   ${arg[$i]} ;;
                                7) printf "%-10s"   ${arg[$i]} ;;
                                8) printf "%-8s"    ${arg[$i]} ;;
                                9) printf "%-30s\n" ${arg[$i]} ;;
                        esac
                done
        done < $CSV
        unset IFS