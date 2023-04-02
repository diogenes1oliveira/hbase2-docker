#!/bin/sh

grep -F '<version>' pom.xml | tr -d '[:space:]' | tr '<>/' '|' | cut -d'|' -f 3
