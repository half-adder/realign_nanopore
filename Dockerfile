# Use a base image with R (using latest tag for better platform support)
FROM rocker/r-ver:4.3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    bc \
    zip \
    unzip \
    libbz2-dev \
    liblzma-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    libncurses5-dev \
    libncursesw5-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Mambaforge for bioinformatics tools (better ARM64 support, no ToS issues)
# Use build argument to specify architecture, default to x86_64
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM}
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
        wget https://github.com/conda-forge/miniforge/releases/download/24.1.2-0/Mambaforge-24.1.2-0-Linux-aarch64.sh -O /tmp/mambaforge.sh || \
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-aarch64.sh -O /tmp/mambaforge.sh; \
    else \
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh -O /tmp/mambaforge.sh || \
        wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/mambaforge.sh; \
    fi && \
    bash /tmp/mambaforge.sh -b -p /opt/conda && \
    rm /tmp/mambaforge.sh && \
    /opt/conda/bin/conda clean -afy

# Add conda to PATH
ENV PATH=/opt/conda/bin:$PATH

# Install bioinformatics tools using mamba (faster and better dependency resolution)
# Add conda-forge and bioconda channels, install packages
RUN mamba install -y -c conda-forge -c bioconda \
    seqkit \
    seqtk \
    medaka \
    htslib \
    && mamba clean -afy

# Install BLAT - try conda first, then pre-built binary (x86_64 works on ARM64 via emulation)
RUN apt-get update && \
    apt-get install -y unzip && \
    (mamba install -y -c bioconda blat && mamba clean -afy && echo "BLAT installed via conda") || \
    (echo "Installing pre-built BLAT binary (x86_64, works on ARM64 via emulation)..." && \
     wget -q http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/blat/blat.zip -O /tmp/blat.zip && \
     unzip -q /tmp/blat.zip -d /tmp && \
     mv /tmp/blat /opt/conda/bin/blat && \
     chmod +x /opt/conda/bin/blat && \
     rm -f /tmp/blat.zip && \
     echo "BLAT binary installed") || \
    echo "Warning: BLAT installation failed. Pipeline may not work without BLAT." && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install R packages (including tidyverse dependencies for readr)
RUN Rscript -e "install.packages(c('readr', 'BiocManager'), repos='https://cran.rstudio.com/')" && \
    Rscript -e "BiocManager::install('msa', update=FALSE, ask=FALSE)"

# Create scripts directory and copy scripts to a fixed location
RUN mkdir -p /opt/scripts
COPY *.R /opt/scripts/
COPY realign_fasta.sh /opt/scripts/
COPY realign_fasta_docker.sh /opt/scripts/

# Make the scripts executable
RUN chmod +x /opt/scripts/*.sh

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]

