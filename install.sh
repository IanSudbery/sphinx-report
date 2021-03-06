#!/bin/bash -xe

ROOT_DIR="$( dirname "${BASH_SOURCE[0]}" )"

if [[ -z "$CONDA_PY" ]]; then
    CONDA_PY=2.7
fi

CONDA_INSTALL_TYPE=basic

if [[ -z "$CONDA_INSTALL_DIR" ]]; then
    CONDA_INSTALL_DIR=$(readlink -f env)
fi

if [[ -z "$TRAVIS_BUILD_DIR" ]]; then
    TRAVIS_BUILD_DIR="."
fi

CONDA_CHANNELS="--channel defaults --channel conda-forge --channel bioconda --channel r"
CONDA_PACKAGES="pillow seaborn pandas seaborn scipy numpy matplotlib jpeg rpy2 r-ggplot2 r-gplots"

# log installation information
log() {
   echo "# CGATReport log | `hostname` | `date` | $1 "
}

# printenv

# function to detect the Operating System
detect_os() {

if [ -f /etc/os-release ]; then

   OS=$(cat /etc/os-release | awk '/VERSION_ID/ {sub("="," "); print $2;}' | sed 's/\"//g' | awk '{sub("\\."," "); print $1;}')
   if [ "$OS" != "12" ] ; then

      echo       
      echo " Sorry, this version of Ubuntu has not been tested. Only Ubuntu 12.x is supported so far. "
      echo
      exit 1;

   fi

   OS="ubuntu"

elif [ -f /etc/system-release ]; then

   OP=$(cat /etc/system-release | awk ' {print $1;}')
   if [ "$OP" == "Scientific" ] ; then
      OP=$(cat /etc/system-release | awk ' {print $4;}' | awk '{sub("\\."," "); print $1;}')
      if [ "$OP" != "6" ] ; then
         echo
         echo " Sorry, this version of Scientific Linux has not been tested. Only 6.x versions are supported so far. "
         echo
         exit 1;
      else
         OS="sl"
      fi
   elif [ "$OP" == "CentOS" ] ; then
      OP=$(cat /etc/system-release | awk ' {print $3;}' | awk '{sub("\\."," "); print $1;}')
      if [ "$OP" != "6" ] ; then
         echo
         echo " Sorry, this version of CentOS has not been tested. Only 6.x versions are supported so far. "
         echo
         exit 1;
      else
         OS="centos"
      fi
   fi
fi

} # detect_os


# install operating system dependencies
install_os_packages() {

detect_os

if [ "$OS" == "ubuntu" ] || [ "$OS" == "travis" ] ; then

   echo
   echo " Installing packages for Ubuntu "
   echo

   sudo apt-get --quiet install -y gcc g++ zlib1g-dev libssl-dev libssl1.0.0 libbz2-dev libfreetype6-dev libpng12-dev libblas-dev libatlas-dev liblapack-dev gfortran libpq-dev r-base-dev libreadline-dev libmysqlclient-dev libboost-dev libsqlite3-dev libcairo2-dev

elif [ "$OS" == "sl" ] || [ "$OS" == "centos" ] ; then

   echo 
   echo " Installing packages for Scientific Linux / CentOS "
   echo

   yum -y install gcc zlib-devel openssl-devel bzip2-devel gcc-c++ freetype-devel libpng-devel blas atlas lapack gcc-gfortran postgresql-devel R-core-devel readline-devel mysql-devel boost-devel sqlite-devel xorg-x11-fonts-75dpi xorg-x11-fonts-100dpi org-x11-server-Xvfb cairo-devel

# cairo-dev/libcairo2-dev required for R package svglite
# 


   # additional configuration for scipy (Scientific Linux only)
   if [ "$OS" == "sl" ] ; then
      ln -s /usr/lib64/libatlas.so.3 /usr/lib64/libatlas.so
   fi

   # additional configuration for blas and lapack
   ln -s /usr/lib64/libblas.so.3 /usr/lib64/libblas.so
   ln -s /usr/lib64/liblapack.so.3 /usr/lib64/liblapack.so;

else

   sanity_check_os $OS

fi # if-OS
} # install_os_packages

# install_os_packages

# download and install conda
if [ ! -d "$CONDA_INSTALL_DIR" ]; then
    log "installing conda into $CONDA_INSTALL_DIR"
    rm -f Miniconda-latest-Linux-x86_64.sh
    wget http://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
    rm -rf "$CONDA_INSTALL_DIR"
    bash Miniconda3-latest-Linux-x86_64.sh -b -p "$CONDA_INSTALL_DIR"
    hash -r
else
    log "using existing conda enviroment in $CONDA_INSTALL_DIR"
fi

# conda update conda --yes
# conda info -a

log "creating conda environment"
"$CONDA_INSTALL_DIR"/bin/conda create --yes \
    -n "$CONDA_INSTALL_TYPE" \
    --override-channels $CONDA_CHANNELS \
    python="$CONDA_PY" \
    $CONDA_PACKAGES

# set +o nounset
source "$CONDA_INSTALL_DIR"/bin/activate "$CONDA_INSTALL_TYPE"
# set -o nounset

log "installing R dependencies"
R -f "$ROOT_DIR"/install.R

log "installing conda dependencies"
which conda

# The following packages will be pulled in through pip:
# mpld3
log "installing ggplot upgrade"
pip install --upgrade --no-dependencies ggplot

echo "setting up CGATReport"
# setup CGATPipelines
cd "$TRAVIS_BUILD_DIR"
python setup.py develop

# log "building report"
# cd doc && make html

# cd $TRAVIS_BUILD_DIR
# cat doc/cgatreport.log | cut -d " " -f 3 | sort | uniq -c
