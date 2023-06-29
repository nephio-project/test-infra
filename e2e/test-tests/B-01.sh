#!/bin/bash

echo start: $0
sleep 5
sleep $(expr $RANDOM % 10)
echo end: $0
