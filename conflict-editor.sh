#!/bin/bash
contents=`cat "$1"`
echo "CONFLICT! $contents" > "$1"
