# Diagnosing Medaka / tabix / bgzip issues in `realign_nanopore`

## What’s happening

When running `realign_fasta.sh`, the pipeline prints:

```text
Performing Medaka consensus search

Medaka will use the reference FASTA:
./12xH3sims.fasta
Attempting to automatically select model version.
WARNING: Failed to detect a model version, will use default: 'r1041_e82_400bps_sup_v5.2.0'
Checking program versions
This is medaka 2.1.1
tabix: invalid option -- '-'
...
Program: tabix (TAB-delimited file InderXer)
Version: 0.2.5 (r1005)
...

bgzip: invalid option -- '-'
...

mv: cannot stat '././12xH3sims_consensus/consensus.fasta': No such file or directory
...
```

From `scripts/realign_fasta.sh`:

```bash
out_folder="${ref_basename}_consensus"

printf "\nMedaka will use the reference FASTA: \n"${ref_fasta}"\n"

medaka_consensus -i ./plasmid_restart.fasta -o ${out_folder} -d ${ref_fasta} -t 1

printf "\nRe-naming output Files..."
mv ./${out_folder}/consensus.fasta ./${ref_basename}_consensus.fasta
mv ./${out_folder}/calls_to_draft.bam ./${ref_basename}_reads.bam
mv ./${out_folder}/calls_to_draft.bam.bai ./${ref_basename}_reads.bam.bai
```

`realign_fasta.sh` assumes that `medaka_consensus` succeeds and creates:

- `${out_folder}/consensus.fasta`
- `${out_folder}/calls_to_draft.bam`
- `${out_folder}/calls_to_draft.bam.bai`

However, the log shows `tabix` and `bgzip` errors and then `mv: cannot stat` for all of these files, which means Medaka never created them.

## Root cause

- The module environment is loading **Medaka 2.1.1** together with **very old** `tabix` / `bgzip`:
  - `tabix 0.2.5 (r1005)` is ancient and does not support some of the options Medaka internally passes to `tabix`/`bgzip`.
- Medaka 2.x expects a much newer `htslib`/`tabix`/`bgzip` stack (typically 1.16+).
- Because of this mismatch, Medaka fails part-way through its consensus/variant calling steps. The script doesn’t check for this failure and immediately tries to move/delete files that don’t exist.

So the **real error** is the incompatible `tabix`/`bgzip`, not the missing files themselves.

## How to confirm

From the same environment where you run the pipeline, check:

```bash
which medaka_consensus
medaka_consensus --version

which tabix
which bgzip

tabix --version
bgzip --version
```

You will likely see something like:

```text
Program: tabix (TAB-delimited file InderXer)
Version: 0.2.5 (r1005)
```

If you list the Medaka output directory after a failed run:

```bash
ls -R 12xH3sims_consensus
```

it will probably be missing or incomplete, confirming that Medaka did not complete successfully.

## Fix strategy

There are two complementary fixes:

1. **Fix the environment so Medaka uses a recent htslib/tabix/bgzip** (primary fix).
2. **Harden `realign_fasta.sh` so it fails fast if Medaka fails** and doesn’t try to move non‑existent files.

### 1. Fixing the environment

Depending on your cluster/module setup, you have two main approaches.

#### 1A. Use newer modules on the cluster

1. Inspect available modules:

   ```bash
   module avail tabix
   module avail htslib
   module avail samtools
   module avail medaka
   ```

2. In your job (or interactively) try something like:

   ```bash
   module purge
   module load htslib/1.XX   # use the newest version available
   module load medaka/2.1.1
   ```

3. Re-check the versions:

   ```bash
   tabix --version
   bgzip --version
   medaka_consensus --version
   ```

   You want `tabix`/`bgzip` coming from the same htslib series as Medaka (1.x, not 0.2.5).

If the Medaka module is hardwired to an old htslib, you may need your cluster admin to update it or move to a conda-based installation.

#### 1B. Use a conda / mamba environment for Medaka

If possible, create a dedicated environment with consistent versions:

```bash
mamba create -n medaka-env medaka=2.1.1 -c conda-forge -c bioconda
mamba activate medaka-env
```

This will install Medaka along with a matching `htslib`/`tabix`/`bgzip`. Then **do not load the system `medaka` module**; instead, rely on the conda environment:

- Before submitting the job: activate the env and call `sbatch` from within that environment (or use `conda run` in the `sbatch` command).
- In `realign_fasta.sh`, you can comment out the `module load medaka` line and assume `medaka_consensus` is on `PATH` from conda.

### 2. Making `realign_fasta.sh` more robust

Even with a fixed environment, it’s good practice for the script to:

- Exit immediately when a critical step (like Medaka) fails.
- Check that outputs exist before renaming/deleting them.

Recommended changes in `realign_fasta.sh`:

1. **Add strict error handling at the top**:

   ```bash
   #!/bin/bash
   set -euo pipefail
   ```

   This makes the script exit if any command fails, if you use an unset variable, or if a pipeline component fails.

2. **Check Medaka output before proceeding**:

   Replace:

   ```bash
   medaka_consensus -i ./plasmid_restart.fasta -o ${out_folder} -d ${ref_fasta} -t 1

   printf "\nRe-naming output Files..."
   mv ./${out_folder}/consensus.fasta ./${ref_basename}_consensus.fasta
   mv ./${out_folder}/calls_to_draft.bam ./${ref_basename}_reads.bam
   mv ./${out_folder}/calls_to_draft.bam.bai ./${ref_basename}_reads.bam.bai
   ```

   with:

   ```bash
   medaka_consensus -i ./plasmid_restart.fasta -o "${out_folder}" -d "${ref_fasta}" -t 1

   # Verify Medaka output exists
   if [ ! -f "${out_folder}/consensus.fasta" ]; then
       echo "ERROR: Medaka did not produce ${out_folder}/consensus.fasta."
       echo "       Check Medaka / tabix / bgzip versions and Medaka logs above."
       exit 1
   fi

   printf "\nRe-naming output Files..."
   mv "${out_folder}/consensus.fasta" "${ref_basename}_consensus.fasta"

   # These may or may not exist depending on Medaka version/options
   if [ -f "${out_folder}/calls_to_draft.bam" ]; then
       mv "${out_folder}/calls_to_draft.bam" "${ref_basename}_reads.bam"
   fi

   if [ -f "${out_folder}/calls_to_draft.bam.bai" ]; then
       mv "${out_folder}/calls_to_draft.bam.bai" "${ref_basename}_reads.bam.bai"
   fi
   ```

3. **Guard some cleanup steps** so they don’t fail if the directory is missing:

   ```bash
   printf "\nRemoving Files..."

   # Remove temp files and do some cleaning up
   rm ./out.fasta || true
   rm ./temp.fasta || true
   rm ./query.fasta || true

   if [ -d "${out_folder}" ]; then
       rm -r "${out_folder}"
   fi

   rm ./renamed_reads.fastq || true
   rm ./plasmid_restart.fasta || true
   rm ./concat.fastq || true
   rm ./*.fai 2>/dev/null || true
   rm ./*.mmi 2>/dev/null || true
   rm ./out.fastq || true
   rm ./output.psl || true
   rm ./blat_names.txt || true
   rm ./fname.txt || true
   rm ./shortened.fasta 2>/dev/null || true
   ```

   And for the final move into `results/`:

   ```bash
   mkdir -p ./results

   mv *.pdf *consensus.fasta *.bam *.bai *_restart.fastq *_Alignment.txt *.bed *.gtf ./results 2>/dev/null || true
   cp "${ref_fasta}" "./results/${ref_basename}_reference.fasta"
   zip -r "${ref_basename}_results.zip" ./results
   ```

   The `2>/dev/null || true` pattern stops missing files from crashing the script.

## How to rerun successfully

1. **Fix the environment**:

   - Preferably: create and activate a conda environment with Medaka 2.1.1 (and its dependencies) and ensure `tabix`/`bgzip` are from a modern `htslib`.
   - Or: load compatible cluster modules for `htslib`/`samtools` *before* `medaka` so the `tabix`/`bgzip` on `PATH` are recent.

2. **Optionally harden `realign_fasta.sh`** as described above so that if Medaka still fails, the script stops immediately with a clear error message.

3. **Submit the job again** from your project directory (not from inside `scripts/`):

   ```bash
   sbatch --time=5:00:00 --mem=16g --ntasks=2 --wrap="sh ./scripts/realign_fasta.sh"
   ```

4. After it finishes, you should see:

   - `[reference]_consensus.fasta` (e.g. `12xH3sims_consensus.fasta`)
   - `[reference]_reads.bam` and `[reference]_reads.bam.bai`
   - A `results/` folder and `[reference]_results.zip` containing all outputs described in `README.md`.

If you share the outputs of `tabix --version`, `bgzip --version`, and `which medaka_consensus` from your environment, we can tailor the environment fix more precisely (e.g. exact module or conda setup).
