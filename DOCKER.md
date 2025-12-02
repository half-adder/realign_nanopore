# Docker Usage Guide

This guide explains how to build and run the realign_nanopore pipeline using Docker.

## Building the Docker Image

From the repository root directory, build the Docker image:

```bash
docker build -t realign_nanopore .
```

This will create a Docker image named `realign_nanopore` with all required dependencies installed.

### Platform-Specific Builds

If you encounter platform compatibility issues (e.g., on Apple Silicon/M1/M2 Macs), you can specify the platform explicitly:

**For native ARM64 builds (recommended for Apple Silicon):**
```bash
docker build --platform linux/arm64 -t realign_nanopore .
```

**For x86_64 builds (recommended - better BLAT support):**
```bash
docker build --platform linux/amd64 -t realign_nanopore .
```

**Note**: If you're on Apple Silicon (M1/M2), building for x86_64 will be slower but ensures all tools (especially BLAT) work correctly.

**Note on BLAT**: BLAT may not be available via conda for ARM64. If the build fails or BLAT is missing, you have two options:
1. Build for x86_64 platform (slower on Apple Silicon due to emulation, but all packages available)
2. Install BLAT manually after container creation, or build BLAT from source

Note: Building for a non-native architecture may be slower due to emulation.

## Running the Pipeline

### Prerequisites

Before running the container, ensure you have:
1. A reference FASTA or Genbank file (`.fasta`, `.fa`, or `.gb`)
2. One or more FASTQ files with your Nanopore reads

### Basic Usage

1. **Prepare your data directory**: Create a directory containing your input files:
   ```bash
   mkdir -p /path/to/your/data
   cd /path/to/your/data
   # Copy your reference.fasta (or .gb) and *.fastq files here
   ```

2. **Run the container**: Mount your data directory and execute the pipeline:
   ```bash
   docker run -v /path/to/your/data:/workspace realign_nanopore bash /opt/scripts/realign_fasta_docker.sh
   ```
   
   **Note**: Use `bash` (not `sh`) to run the script, as it uses bash-specific features.

### Example

```bash
# Create a data directory
mkdir -p ~/nanopore_analysis
cd ~/nanopore_analysis

# Copy your files
cp /path/to/reference.fasta .
cp /path/to/reads.fastq .

# Run the pipeline
docker run -v ~/nanopore_analysis:/workspace realign_nanopore bash /opt/scripts/realign_fasta_docker.sh
```

### Output

After completion, the results will be in the `results/` directory within your mounted data directory:
- `[reference]_consensus.fasta` - Consensus sequence
- `[reference]_reads.bam` and `.bai` - Aligned reads for IGV
- `[reference]_restart.fastq` - Restarted reads
- `[reference]_results.zip` - Compressed results folder
- Additional analysis files (histograms, BED files, etc.)

## Interactive Mode

To explore the container interactively:

```bash
docker run -it -v /path/to/your/data:/workspace realign_nanopore /bin/bash
```

Then you can run commands manually:
```bash
cd /workspace
bash /opt/scripts/realign_fasta_docker.sh
```

## Notes

- The Docker version uses `realign_fasta_docker.sh` which removes SLURM-specific commands and module loading
- All tools (seqkit, blat, seqtk, medaka, R) are pre-installed and available in PATH
- The container uses `/workspace` as the working directory for input/output files
- Scripts are installed at `/opt/scripts/` in the container
- Input files should be placed in the directory you mount to `/workspace`

