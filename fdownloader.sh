#/bin/bash

#----------some variable declaration--------------
HELP_MESSAGE="Usage: fdownloader.sh [OPTIONS] [url]

Simple script that allows you to download multiple consecutive files from their url.

Options:

-b		begin at the provided offset
-d		specify target folder
-f		specify input file
-h		print this message
-i		specify custom incrementation
-n		specify the number of elements to download
-y		doesn't ask for folder creation

"

#--------------options management-----------------
while getopts "b:d:f:hi:n:y" option
do
	case $option in
		b)
			begin=$OPTARG
			;;
		d)
			target_folder=$OPTARG
			;;
		f)
			input_file=$OPTARG
			allow_creation=1
			;;
		i)
			custom_increment=$OPTARG
			;;
		n)
			taille=$OPTARG
			;;
		h)
			echo "$HELP_MESSAGE"
			exit
			;;
		y)
			allow_creation=1
			;;
		\?)
			echo "$OPTARG: invalid option"
			echo "fdownloader.sh -h for help"

			exit
			;;
		:)
			echo "The $OPTARG option needs an argument"
			echo "fdownloader.sh -h for help"
			exit
			;;
	esac
done
shift $((OPTIND-1))
if [ "$#" -ne 1 ]
then
	if [ ! -v input_file ]
	then
		echo "Illegal number of arguments"
		echo "$HELP_MESSAGE"
		exit
	fi
fi

#-------------getting some variables---------------
source=`pwd`
base_url=$1
if [ ! -v allow_creation ]
then
	allow_creation=0
fi
if [ ! -v begin ]
then
	begin=1
fi

#--------------incrementation type-----------------
if [ ! -v custom_increment ]
then
	custom_increment=1
fi


Folder_check()
{
#-----------target folder check--------------------
#verify that the targeted folder is not a file
if [ -f $target_folder ] && [ ! -z $target_folder ]
then
	echo "$target_folder is a file, exiting..."
	exit
fi

#verify that the targeted folder exists
if [ ! -d $target_folder ]
then
	if [ $allow_creation -eq 1 ]
	then
		mkdir -p $target_folder
	else
		#if not, prompt user for creation, then creates or exit
		read -p "$target_folder doesn't exists, do you want to create it ?(y/n)" create_folder
		if [[ ${create_folder} == "y" ]]
		then
			mkdir -p $target_folder
		else
			echo "Exiting due to non-existant target folder..."
			exit
		fi
	fi
fi

#if no folder specified, target folder is current folder
if [ -z $target_folder ]
then
	target_folder="./"
fi
}

#########################################################################################################Folder_check $target_folder

Get_extension()
{
#--------------getting extension-------------------
file_name=$(basename $base_url)
extension=${file_name##*.}
}

Transform_url()
{
#--------------url transformation------------------
#transforms only if there is no __
prefix=${base_url%'/'*}
base_url="${prefix}/__.${extension}"
}

Determine_number()
{
#--determining the number of elements to download--
	echo "determining number of elements..."
	if [ -v begin ]
	then
		taille=$begin
	else
		taille=1
	fi
	status_code=200
	while [ $status_code -eq "200" ]
	do
		#progression printing
		echo -en "\r"
		echo -n $taille
		((taille+=1))
		status_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' ${base_url/__/$taille})
		if [ $status_code -ne 200 ] && [ $extension == "png" ]
		then
			temp_ext="jpg"
			temp_url="${prefix}/__.${temp_ext}"
			status_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' ${temp_url/__/$taille})
		elif [ $status_code -ne 200 ] && [ $extension == "jpg" ]
		then
			temp_ext="png"
			temp_url="${prefix}/__.${temp_ext}"
			status_code=$(curl -o /dev/null --silent --head --write-out '%{http_code}\n' ${temp_url/__/$taille})
		fi
	done
	echo ""
	((taille-=1))
}

Determine_zero_buffer()
{
#-------output file naming management--------------
zero_buffer=""
temp_taille=$((taille/10))
while [ $temp_taille -gt 0 ]
do
	zero_buffer="${zero_buffer}0"
	((temp_taille/=10))
done
if [ $begin -ge 10 ]
then
	zero_buffer=${zero_buffer%?}
fi
if [ $begin -ge 100 ]
then
	zero_buffer=${zero_buffer%?}
fi
if [ $begin -ge 1000 ]
then
	zero_buffer=${zero_buffer%?}
fi
if [ $begin -ge 10000 ]
then
	zero_buffer=${zero_buffer%?}
fi
}

Download()
{
#-------------download management------------------
cd $target_folder

if [ -v begin ]
then
	i=$begin
else
	i=1
fi
apassed=0
bpassed=0
cpassed=0
dpassed=0
while [ $taille -ge $i ]
do
	wget ${base_url/__/$i} -O "${zero_buffer}$i.$extension" -q --show-progress
	return=$?
	if [ $return -ne 0 ] && [ $extension == "png" ]
	then
		rm "${zero_buffer}$i.$extension"
		temp_ext="jpg"
		temp_url="${prefix}/__.${temp_ext}"
		wget ${temp_url/__/$i} -O "${zero_buffer}$i.$temp_ext" -q --show-progress
	elif [ $return -ne 0 ] && [ $extension == "jpg" ]
	then
		rm "${zero_buffer}$i.$extension"
		temp_ext="png"
		temp_url="${prefix}/__.${temp_ext}"
		wget ${temp_url/__/$i} -O "${zero_buffer}$i.$temp_ext" -q --show-progress
	fi
	echo -en "\r"
	echo -n "${i}/${taille}"
	((i+=$custom_increment))
	if [ $i -ge 10 ] && [ $apassed -eq 0 ]
	then
		apassed=1
		zero_buffer=${zero_buffer%?}
	fi
	if [ $i -ge 100 ] && [ $bpassed -eq 0 ]
	then
		bpassed=1
		zero_buffer=${zero_buffer%?}
	fi
	if [ $i -ge 1000 ] && [ $cpassed -eq 0 ]
	then
		cpassed=1
		zero_buffer=${zero_buffer%?}
	fi
	if [ $i -ge 10000 ] && [ $dpassed -eq 0 ]
	then
		dpassed=1
		zero_buffer=${zero_buffer%?}
	fi
done
cd $source
}


if [ -v input_file ]
then
	while read base_url taille target_folder begin custom_increment
	do
		if [[ $begin == "//" ]]
		then
			begin=1
		fi
		if [[ $custom_increment == "//" ]]
		then
			custom_increment=1
		fi
		if [[ $target_folder == "//" ]]
		then
			target_folder=""
		fi
		Folder_check
		Get_extension
		if [[ ! $base_url == *"__"* ]]
		then
			Transform_url
		fi
		if [[ $taille == "//" ]]
		then
			Determine_number
		fi
		Determine_zero_buffer
		Download
		echo ""
	done < $input_file
else
	Folder_check
	Get_extension
	if [[ ! $base_url == *"__"* ]]
	then
		Transform_url
	fi
	if [ ! -v taille ]
	then
		Determine_number
	fi
	Determine_zero_buffer
	Download
fi

echo ""
