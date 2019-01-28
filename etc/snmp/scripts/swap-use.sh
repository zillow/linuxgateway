#!/bin/sh

TotalSwap=`cat /proc/meminfo | grep "SwapTotal" | awk '{ print $2 }'`
FreeSwap=`cat /proc/meminfo | grep "SwapFree" | awk '{ print $2 }'`

expr \( $TotalSwap - $FreeSwap \) \* 100 / $TotalSwap
