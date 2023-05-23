while getopts d: flag
do
    case "${flag}" in
        d) directory=${OPTARG};;
    esac
done

if [ -d "$directory" ] 
then 
  rm -rf "$directory" 
else
  echo "dir doesn't exist"
fi
