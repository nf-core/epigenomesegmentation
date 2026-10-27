#!/usr/bin/env Rscript
suppressPackageStartupMessages(suppressWarnings(library(GenomicRanges)))
suppressPackageStartupMessages(suppressWarnings(library(BiocParallel)))
suppressPackageStartupMessages(suppressWarnings(library(Rsamtools)))
suppressPackageStartupMessages(suppressWarnings(library(bamsignals)))
suppressPackageStartupMessages(suppressWarnings(library(preprocessCore)))
suppressPackageStartupMessages(suppressWarnings(library(matrixStats)))
library(Rcpp)

sourceCpp("/app/counts.cpp")

# Reading all the arguments
args = commandArgs(trailingOnly=TRUE)
# print(args) # Uncomment to check for provided arguments
tab_files <- read.table(args[1],header=F)
ut.regions <- read.table(args[2],header = F)
bin_size <- as.integer(args[3])
shift_bp <- as.integer(args[4])
output_path <- as.character(args[5])
cores <- as.integer(args[6])
paired_end <- as.character(args[7])

print("All inputs are read...")

tab_files$V2 <- as.character(tab_files$V2)

# Generating refined regions
regions <- GRanges(ut.regions[[1]], IRanges(start=ut.regions[[2]]+1, end=ut.regions[[3]]))
starts <- start(regions)-1
ends <- end(regions)
newstarts <- bin_size*(ceiling(starts/bin_size))
newends <- bin_size*(floor(ends/bin_size))
valid <- newends > newstarts
regions <- regions[valid]
newstarts <- newstarts[valid]
newends <- newends[valid]
start(regions) <- newstarts+1
end(regions) <- newends


# List of BAM files
bam_files <- c(tab_files$V2)

# Initialize BiocParallel
register(MulticoreParam(workers = cores))  # Adjust the number of workers as needed

# Process each BAM file in parallel
results <- bplapply(bam_files, function(bam_path) {
  bprof <- bamProfile(bampath = bam_path, regions, binsize = bin_size, shift = shift_bp, paired.end=paired_end)
  unlist(as.list(bprof))
})


# Combine the results into a list
counts_list <- as.data.frame(results)
colnames(counts_list) <- c(as.character(tab_files$V1))

# Adaptive outlier removal using multi-replicate mark columns only.
# Builds a single intersection keep-mask so every mark (single- and multi-replicate)
# retains the same set of bins, preventing cbind row-count mismatches.
# If the mask removes >5% of bins the threshold is relaxed geometrically toward 1
# and the mask is recomputed, up to a ceiling of 0.9999.
unique_patterns <- unique(sub("\\.\\d+$", "", names(counts_list)))
threshold <- 0.999
has_multi_rep <- any(sapply(unique_patterns, function(p) length(grep(p, names(counts_list))) > 1))

if(has_multi_rep) {
  repeat {
    combined_keep <- rep(TRUE, nrow(counts_list))
    for(p in unique_patterns) {
      col_idx <- grep(p, names(counts_list))
      if(length(col_idx) > 1) {
        for(i in col_idx) {
          combined_keep <- combined_keep & (counts_list[, i] <= quantile(counts_list[, i], prob=threshold))
        }
      }
    }
    pct_removed <- mean(!combined_keep)
    message(sprintf("Outlier threshold %.4f: %.2f%% of bins removed", threshold, 100 * pct_removed))
    if(pct_removed <= 0.05 || threshold >= 0.9999) break
    threshold <- threshold + (1 - threshold) / 2
    message(sprintf("Threshold too aggressive; relaxing to %.5f", threshold))
  }
  counts_list[!combined_keep, ] <- 0L
}

# Use lapply to group and sum rows based on patterns
summed_data_list <- lapply(unique_patterns, function(pattern) {
  print("Starting counts...")
    if(ncol(counts_list[grep(pattern, names(counts_list))]) > 1) {
      print("Starting normalization...")
        input_df <- counts_list[grep(pattern, names(counts_list))]
        normalized_counts <- quantileNormalization(input_df)
        normalized_counts <- as.matrix(normalized_counts)
        print("calculating rowmedians...")
        summed_cols <- floor(rowMedians(normalized_counts))
    } else {
        summed_cols <- counts_list[grep(pattern, names(counts_list))]
    }
    data.frame(summed_cols)
}
)


# Combine the list of dataframes into a single dataframe
summed_data <- do.call(cbind, summed_data_list)
colnames(summed_data) <- unique_patterns

refined_regions <- data.frame(chr= as.character(seqnames(regions)), start=start(regions)-1, end=end(regions))

# write the count matrix and refined regions to output file
print("writing tables...")
write.table(summed_data,file=paste(output_path,"counts.txt",sep="_"),sep="\t",quote=FALSE,row.names=F)
write.table(refined_regions,file=paste(output_path,"refine_chr_regions.bed",sep="_"),sep="\t",quote=FALSE,row.names=F, col.names=FALSE)
