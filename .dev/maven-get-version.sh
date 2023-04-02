#!/bin/sh

grep -F '<version>' | tr -d '[:space:]' | tr '<>/' '|' | cut -d'|' -f 3
