ARG BASE_IMAGE=mambaorg/micromamba:1.5.8-noble
FROM --platform=$BUILDPLATFORM $BASE_IMAGE

# Set image metadata labels
LABEL org.opencontainers.image.title="SSEC Base Image"
LABEL org.opencontainers.image.version="0.1"
LABEL org.opencontainers.image.url="https://github.com/uw-ssec/docker-images"
LABEL org.opencontainers.image.source="https://github.com/uw-ssec/docker-images.git"
LABEL org.opencontainers.image.description="Base image of all SSEC images. \
    It is similar to Pangeo Docker Base Image, but this uses micromamba."
LABEL org.opencontainers.image.licenses="BSD-3-Clause"
LABEL org.opencontainers.image.vendor="UW Scientific Software Engineering Center"


# Setup environment to match variables set by repo2docker as much as possible
# The name of the conda environment into which the requested packages are installed
ENV CONDA_ENV=notebook \
    # Tell apt-get to not block installs by asking for interactive human input
    DEBIAN_FRONTEND=noninteractive \
    # Set username, uid and gid (same as uid) of non-root user the container will be run as
    NB_USER=${MAMBA_USER} \
    NB_UID=${MAMBA_USER_ID} \
    # Use /bin/bash as shell, not the default /bin/sh (arrow keys, etc don't work then)
    SHELL=/bin/bash \
    # Setup locale to be UTF-8, avoiding gnarly hard to debug encoding errors
    LANG=C.UTF-8  \
    LC_ALL=C.UTF-8 \
    # Install conda in the same place repo2docker does
    CONDA_DIR=${MAMBA_ROOT_PREFIX}

# All env vars that reference other env vars need to be in their own ENV block
# Path to the python environment where the jupyter notebook packages are installed
ENV NB_PYTHON_PREFIX=${CONDA_DIR}/envs/${CONDA_ENV} \
    # Home directory of our non-root user
    HOME=/home/${NB_USER}

# Add both our notebook env as well as default conda installation to $PATH
# Thus, when we start a `python` process (for kernels, or notebooks, etc),
# it loads the python in the notebook conda environment, as that comes
# first here.
ENV PATH=${NB_PYTHON_PREFIX}/bin:${CONDA_DIR}/bin:${PATH}

# Ask dask to read config from ${CONDA_DIR}/etc rather than
# the default of /etc, since the non-root jovyan user can write
# to ${CONDA_DIR}/etc but not to /etc
ENV DASK_ROOT_CONFIG=${CONDA_DIR}/etc

USER root

# Make sure that /srv is owned by non-root user, so we can install things there
RUN chown -R ${NB_USER}:${NB_USER} /srv

# Install basic apt packages
RUN echo "Installing Apt-get packages..." \
    && apt-get update --fix-missing > /dev/null \
    && apt-get install -y wget zip tzdata > /dev/null \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set conda alias to micromamba
RUN echo "alias conda='micromamba'" >> ${HOME}/.bashrc

# Add TZ configuration - https://github.com/PrefectHQ/prefect/issues/3061
ENV TZ UTC
# ========================

USER ${NB_USER}
WORKDIR ${HOME}

EXPOSE 8888
ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "/srv/start"]

# We use ONBUILD (https://docs.docker.com/engine/reference/builder/#onbuild)
# to support triggering certain behavior when specific files exist in the directories of our
# child images (such as base-notebook, pangeo-notebook, etc). For example,
# in pangeo-notebook/Dockerfile, we *only* inherit from base-image:master, and
# that triggers all these ONBUILD directives - it is as if these ONBUILD
# directives are located inside pangeo-notebook/Dockerfile. This lets us
# keep the Dockerfiles for our child docker images simple, and customize
# them by just adding files with known names to them. This is
# to *mimic* the repo2docker behavior, where users can just add
# environment.yml, requirements.txt, apt.txt etc files to get certain
# behavior without having to understand how Dockerfiles work. We use
# ONBUILD to support a subset of the files that repo2docker supports.
# We do not use repo2docker itself here, to make the images much smaller
# and easier to reason about.
# ----------------------
ONBUILD USER root
# FIXME (?): user and home folder is hardcoded for now
# FIXME (?): this line breaks the cache of all steps below
ONBUILD COPY --chown=${NB_USER}:${NB_USER} . ${HOME}

# Make sure that /opt/conda is owned by non-root user, so we can install additional packages
ONBUILD RUN chown -R ${NB_USER}:${NB_USER} ${CONDA_DIR}

# repo2docker will load files from a .binder or binder directory if
# present. We check if those directories exist, and print a diagnostic
# message here.
ONBUILD RUN echo "Checking for 'binder' or '.binder' subfolder" \
    ; if [ -d binder ] ; then \
    echo "Using 'binder/' build context" \
    ; elif [ -d .binder ] ; then \
    echo "Using '.binder/' build context" \
    ; else \
    echo "Using './' build context" \
    ; fi

# Install apt packages specified in a apt.txt file if it exists.
# Unlike repo2docker, blank lines nor comments are supported here.
ONBUILD RUN echo "Checking for 'apt.txt'..." \
    ; [ -d binder ] && cd binder \
    ; [ -d .binder ] && cd .binder \
    ; if test -f "apt.txt" ; then \
    apt-get update --fix-missing > /dev/null \
    # Read apt.txt line by line, and execute apt-get install -y for each line in apt.txt
    && xargs -a apt.txt apt-get install -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    ; fi

# If a jupyter_notebook_config.py exists, copy it to /etc/jupyter so
# it will be read by jupyter processes when they start. This feature is
# not available in repo2docker.
ONBUILD RUN echo "Checking for 'jupyter_notebook_config.py'..." \
    ; [ -d binder ] && cd binder \
    ; [ -d .binder ] && cd .binder \
    ; if test -f "jupyter_notebook_config.py" ; then \
    mkdir -p /etc/jupyter \
    && cp jupyter_notebook_config.py /etc/jupyter \
    ; fi

ONBUILD USER ${NB_USER}

# Create empty conda env and set auto activate
ONBUILD RUN micromamba create --yes --name $CONDA_ENV
ONBUILD ENV ENV_NAME=${CONDA_ENV}

# We want to keep our images as reproducible as possible. If a lock
# file with exact versions of all required packages is present, we use
# it to install packages. conda-lock (https://github.com/conda-incubator/conda-lock)
# is used to generate this conda-linux-64.lock file from a given environment.yml
# file - so we get the exact same versions each time the image is built. This
# also lets us see what packages have changed between two images by diffing
# the contents of the lock file between those image versions.
# If a lock file is not present, we use the environment.yml file. And
# if that is also not present, we use the pangeo-notebook conda-forge
# package (https://anaconda.org/conda-forge/pangeo-notebook) to install
# a list of base packages.
# After installing the packages, we cleanup some unnecessary files
# to try reduce image size - see https://jcristharif.com/conda-docker-tips.html
ONBUILD RUN echo "Checking for 'conda-lock.yml' 'conda-linux-64.lock' or 'environment.yml'..." \
    ; [ -d binder ] && cd binder \
    ; [ -d .binder ] && cd .binder \
    ; if test -f "conda-lock.yml" ; then \
    micromamba create --yes --name ${CONDA_ENV} --file conda-lock.yml \
    ; elif test -f "conda-linux-64.lock" ; then \
    micromamba create --yes --name ${CONDA_ENV} --file conda-linux-64.lock \
    ; elif test -f "environment.yml" ; then \
    micromamba install --yes --name ${CONDA_ENV} --file environment.yml  \
    ; else echo "No conda-lock.yml, conda-linux-64.lock, or environment.yml! *creating empty python 3.12*" ; \
    micromamba install --yes --name ${CONDA_ENV} --channel=conda-forge python=3.12 \
    ; fi \
    && micromamba clean -yaf \
    && micromamba run -n ${CONDA_ENV} pip cache purge \
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete \
    ; if ls ${NB_PYTHON_PREFIX}/lib/python*/site-packages/bokeh/server/static > /dev/null 2>&1; then \
    find ${NB_PYTHON_PREFIX}/lib/python*/site-packages/bokeh/server/static -follow -type f -name '*.js' ! -name '*.min.js' -delete \
    ; fi

# If a requirements.txt file exists, use pip to install packages
# listed there. We don't want to save cached wheels in the image
# to avoid wasting space.
ONBUILD RUN echo "Checking for pip 'requirements.txt'..." \
    ; [ -d binder ] && cd binder \
    ; [ -d .binder ] && cd .binder \
    ; if test -f "requirements.txt" ; then \
    micromamba run -n ${CONDA_ENV} pip install --no-cache -r requirements.txt \
    && micromamba run -n ${CONDA_DIR} pip cache purge \
    ; fi

# If a postBuild file exists, run it!
# After it's done, we try to remove any possible cruft commands there
# leave behind under $HOME - particularly stuff that jupyterlab extensions
# leave behind.
ONBUILD RUN echo "Checking for 'postBuild'..." \
    ; [ -d binder ] && cd binder \
    ; [ -d .binder ] && cd .binder \
    ; if test -f "postBuild" ; then \
    chmod +x postBuild \
    && ./postBuild \
    && rm -rf /tmp/* \
    && rm -rf ${HOME}/.cache ${HOME}/.npm ${HOME}/.yarn \
    && rm -rf ${NB_PYTHON_PREFIX}/share/jupyter/lab/staging \
    && find ${CONDA_DIR} -follow -type f -name '*.a' -delete \
    && find ${CONDA_DIR} -follow -type f -name '*.js.map' -delete \
    ; fi

# If a start file exists, put that under /srv/start. Used in the
# same way as a start file in repo2docker.
ONBUILD RUN echo "Checking for 'start'..." \
    ; [ -d binder ] && cd binder \
    ; [ -d .binder ] && cd .binder \
    ; if test -f "start" ; then \
    chmod +x start \
    && cp start /srv/start \
    ; fi
# ----------------------
