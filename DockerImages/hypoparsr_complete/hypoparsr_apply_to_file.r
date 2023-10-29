#script to apply hypoparsr table extraction against given .csv file

library(feather)
args = commandArgs(trailingOnly=TRUE)
input_file = args[1]
output_file = args[2]
# call hypoparsr
res <- hypoparsr::parse_file(input_file)
# get result data frames
best_guess <- as.data.frame(res)
# write result to CSV with row headings
# write.csv(best_guess,output_file,row.names=FALSE)
write_feather(best_guess, output_file)
# print(best_guess)