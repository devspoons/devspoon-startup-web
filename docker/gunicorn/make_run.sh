#!/bin/bash

django=1
flask=2

while :
do 
    echo "Select Framework Type 1. django, 2.flask"
    echo -n "Enter the Type >"
    read fwtype
    echo  "Entered the Type: $fwtype"
    if [[ "$fwtype" != "" ]]; then
        break
    fi
done 

while :
do 
    echo "* if your project path has sub-level, you should be insert as \\\/www\\\/B\\\/C"
    echo -n "Enter the project path >"
    read project_path
    echo  "Entered the project path: $project_path"
    if [[ "$project_path" != "" ]]; then
        break
    fi
done 

while :
do 
    echo -n "Enter the project name >"
    read project_name
    echo  "Entered the project name: $project_name"
    if [[ "$project_name" != "" ]]; then
        break
    fi
done 

if [[ "$fwtype" -eq $django ]]; then
    wsgi=${project_name}".wsgi:application"
    echo  "django wsgi: $wsgi"
else
    echo -n "Enter a flask wsgi app name >"
    read appname
    wsgi="wsgi:"${appname}
    echo  "flask wsgi: $wsgi"
fi

sed 's/project_path/'$project_path'/g' sample_run > $project_name'1'.temp
sed 's/wsgi/'$wsgi'/g' $project_name'1'.temp > $project_name'2'.temp
sed 's/project_name/'$project_name'/g' $project_name'2'.temp > run.sh

rm *.temp
