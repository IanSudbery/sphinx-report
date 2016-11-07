#!/usr/bin/env bash

# log installation information
log() {
   echo "# CGATReport log | `hostname` | `date` | $1 "
}

# message to display when the OS is not correct
sanity_check_os() {
   echo
   echo " Unsupported operating system: $OS"
   echo " Installation aborted."
   echo 
   echo " Supported operating systems are: "
   echo " Ubuntu 12.x"
   echo " CentOS 6.x"
   echo " Scientific Linux 6.x"
   echo
   exit 1;
} # sanity_check_os

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
   else
      sanity_check_os
   fi

else

   sanity_check_os

fi
} # detect_os


# install operating system dependencies
install_os_packages() {

detect_os

if [ "$OS" == "ubuntu" ] || [ "$OS" == "travis" ] ; then

   echo
   echo " Installing packages for Ubuntu "
   echo

   sudo apt-get --quiet install -y gcc g++ zlib1g-dev libssl-dev libssl1.0.0 libbz2-dev libfreetype6-dev libpng12-dev libblas-dev libatlas-dev liblapack-dev gfortran libpq-dev r-base-dev libreadline-dev libmysqlclient-dev libboost-dev libsqlite3-dev;

elif [ "$OS" == "sl" ] || [ "$OS" == "centos" ] ; then

   echo 
   echo " Installing packages for Scientific Linux / CentOS "
   echo

   yum -y install gcc zlib-devel openssl-devel bzip2-devel gcc-c++ freetype-devel libpng-devel blas atlas lapack gcc-gfortran postgresql-devel R-core-devel readline-devel mysql-devel boost-devel sqlite-devel

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

# download and install conda
wget http://repo.continuum.io/miniconda/Miniconda-latest-Linux-x86_64.sh
bash Miniconda-latest-Linux-x86_64.sh -b -p $CONDA_INSTALL_DIR
export PATH="$CONDA_INSTALL_DIR/bin:$PATH"
hash -r

# install cgat environment and additional packages: Pillow, seaborn
conda update -q conda --yes
conda info -a
conda create -q -n $CONDA_INSTALL_TYPE --override-channels --channel https://conda.binstar.org/cgat --channel defaults --channel https://conda.anaconda.org/bioconda --channel https://conda.binstar.org/r --channel https://conda.binstar.org/asmeurer --yes $CONDA_INSTALL_TYPE gcc=4.8.3 Pillow seaborn

# The following packages will be pulled in through pip:
# mpld3

echo "Setting up CGATReport"
# setup CGATPipelines
cd $TRAVIS_BUILD_DIR
python setup.py develop
