inputdir=$1
outputdir=$2
dataset_name=$3

cd strudel
python run_strudel.py -t $dataset_name -p $inputdir -o $outputdir
