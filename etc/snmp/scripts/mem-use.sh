#!/bin/sh

TotalMem=`cat /proc/meminfo | grep "MemTotal" | awk '{ print $2 }'`
TotalFree=`cat /proc/meminfo | grep "MemFree" | awk '{ print $2 }'`
Buffers=`cat /proc/meminfo | grep "Buffers" | awk '{ print $2 }'`
Cached=`cat /proc/meminfo | grep "Cached" | grep -v "Swap"| awk '{ print $2 }'`

expr 100 - \( \( $TotalFree + $Buffers + $Cached \) \* 100 / $TotalMem \)
