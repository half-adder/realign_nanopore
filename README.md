# Nanopore Read re-start and alignment


[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.11050973.svg)](https://doi.org/10.5281/zenodo.11050973)


## Author: Markus Nevil

Raw Oxford Nanopore sequencing reads of plasmids have multiple start locations even though the original molecules were circular. This script "restarts" each read using BLAT to search for the user-definied origin of the vector. By aligning these restarted reads to a reference sequence, a consensus sequence can be generated and scanned for mutations. This is useful for vectors with multiple repeats of the same sequence, which normally obfuscates which repeat contains mutations.

## Quick Start:

**Note:** I recommend interfacing with Longleaf using a program with a graphic file explorer, such as MobaXterm for Windows

Clone the script into a new directory in your pine directory of Longleaf:

(Substitute with your own information; example username: `jsmith1`, with example plasmid project name `new_plasmid`)

```
cd /work/users/[j]/[s]/[jsmith1]

mkdir ./[new_plasmid]
cd ./[new_plasmid]
```

Run the following command to copy the script into the current directory.
```
git clone https://github.com/DuronioLab/realign_nanopore.git && rm -rf ./realign_nanopore/.git && mkdir ./scripts && mv ./realign_nanopore/* ./scripts/ && rm -r ./realign_nanopore && rm -r ./scripts/images
```

## Collect/Generate neccessary files/parameters

1. Generate a reference sequence<sup>1</sup> for your plasmid in a plasmid editor.
   - The linear sequence should start and end in vector, thus having the approximate layout:
   
   ![Like This](https://github.com/DuronioLab/realign_nanopore/blob/main/images/githubAsset%202small.png?raw=true)
2. Export the reference sequence as either a FASTA or Genbank File (Snapgene > File > Export > DNA > Genbank or FASTA)
   - Although not required, uploading a Genbank<sup>2</sup> file will generate a GTF of the genes in your sequence for viewing in IGV.

3. Upload your raw Nanopore FASTQ file(s) and reference FASTA/Genbank file.
   - **DO NOT** add these input files to the `scripts/` folder that was automatically generated.
   - Multiple FASTQ's may be uploaded as long as they are named differently.

### Check that the required files and folders are present.

After uploading your **FASTA (or Genbank) and FASTQ files** and copying the scripts from github, your file directory should look like:

```bash
work/users/j/s/jsmith1/
└──new_plasmid/
   ├─ reference_plasmid.fasta or .gb
   ├─ raw_reads.fastq
   └──scripts/
      ├─ README.md
      ├─ realign_fasta.sh
      ├─ read_histogram.R
      ├─ restart_consensus.R
      └──subseq_search.R
```

**note: you may have *more than one* FASTQ file, but may only have *one* reference FASTA or Genbank file**


## Run the script

Copy and paste the following into the terminal:
```
sbatch --time=5:00:00 --mem=16g --ntasks=2 --wrap="sh ./scripts/realign_fasta.sh"
```

## Collect the results

Depending on the number of reads, the script should complete within 30 minutes and generate several results (named after your reference file). The output files are moved into the `results/` folder, but a compressed version of this folder is included:

1. `[reference]_results.zip` contains all the results compressed into one file.
------
Within the `results/` folder:

2. `[reference]_consensus.fasta` is the called consensus sequence to be viewed in a plasmid editor against the reference sequence.

Files to more closely examine the results in IGV:

3. `[reference]_reference.fasta` is a moved-and-renamed FASTA reference file to be used as the genome in IGV.
4. `[reference]_reads.bam` contains the aligned reads for visualization in IGV to examine any potential mutations.
5. `[reference]_reads.bam.bai` indexed bam required for IGV visualization.
6. `[reference]_annotations.gtf` contains 'features' to be viewed in IGV. Only created if a Genbank file was provided.
7. `homopolymer.bed`<sup>3</sup> contains the predicted homopolymer tracts in the reference sequence. Useful to explain sequence errors.
8. `methylation.bed`<sup>4</sup> contains the predicted *E. coli* methylated sites in the reference sequence. Useful to explain sequence errors.

Extra files that may be useful:

9. `[reference]_restart.fastq` are the re-started, size-filtered FASTQ reads.
10. `Filtered_read_lengths.pdf` is a histogram of the read lengths filtered out by the script. Useful to check size filter stringincy.
11. `Restart_Alignment.txt` is an alignment of the beginnings of the first few reads. Useful to ensure the reads are "re-starting" properly


## Notes

1. An accurate reference FASTA is very important but not required. Medaka/minimap2 (the alignment program used) does a fair job of dealing with errors such as unexpected Indels, however it is unclear how much deviation it can take before outputting unexpected results.

2. If a Genbank file is used, the resulting GTF will only be as accurate as the input. Currently, it is written to only scan for "CDS", "5'UTR", and "3'UTR". When creating the annotation (likely in Snapgene), be sure to mark features as these types rather than simply denoting it in their names. This will help prevent loss or misannotation.
3. Homopolymer tracts (AAAAAA, GTGTGTGT, etc.) are a particularly difficult task for nanopore sequencers. While greater numbers of reads helps the Medaka/minimap2 alignment and consensus programs, you may still find "errors" in the sequence at these sites. Generally they can be ignored or examined with Sanger sequencing.
4. We believe that methylated nucleotides are mis-read at a rate that is higher than the expected nanopore error rate, but lower than what you would expect if you have a true mutation in your sequence. This file denotes the three most common *E. coli* methylation sites to cross reference with sequence errors.
