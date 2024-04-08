# Check if conda-lock file exists, if it does, update it, if not, create it
if [ -f conda-lock.yml ]; then
    rm conda-lock.yml
fi
conda-lock -f environment.yml