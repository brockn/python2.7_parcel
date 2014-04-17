#!/bin/bash
# exit on any error
set -e
set -x
# where to find cm tools
CM_EXT=${CM_EXT:-/opt/local/cm_ext/}
# http accessible dir to install parcels
PARCEL_REPO=${PARCEL_REPO:-/var/www/html/parcels/}
SRC_DIR=$PWD
BUILD_DIR=${BUILD_DIR:-$SRC_DIR/target}
DOWNLOAD_DIR=${DOWNLOAD_DIR:-$SRC_DIR/downloads}
# where the parcel should be installed on the *slaves*
INSTALL_DIR=${INSTALL_DIR:-/opt/cloudera/parcels/python2.7/}
TABLEAU_PACKAGE=${TABLEAU_PACKAGE:-$DOWNLOAD_DIR/TDE-API-Python-Linux-64Bit.gz}
# OS this parcel supports
OS=el6
NATIVE_DEPS=(gcc zlib-devel readline-devel gcc-c++ openssl-devel tcl-devel tk-devel \
  gdbm-devel db4-devel blas-devel lapack-devel libpng-devel)
PYTHON_DEP_NAMES=(numpy dateutil pandas scipy matplotlib pyflakes statsmodels \
  dataextract)
# version, note that we may version the 2.7.5 python install ourselves (enable/disable modules)
version=2.7.5.$(date +%Y%m%d.%H%M)
# name of pracel
parcelName=python2.7-$version
# dir we will tar to make the parcel
stagingDir=$BUILD_DIR/$parcelName

download_package() {
  if [[ -z "$1" ]]
  then
    echo "ERROR: Invalid package '$1'"
    exit 1
  fi
  local name=$(basename $1)
  if [[ ! -f $DOWNLOAD_DIR/$name ]]
  then
    pushd $DOWNLOAD_DIR
    curl -O "$1"
    if [[ ! -f $DOWNLOAD_DIR/$name ]]
    then
      echo "ERROR: Expected $DOWNLOAD_DIR/$name from $1"
      exit 1
    fi
    popd
  fi
  pushd $BUILD_DIR
  tar -zxf $DOWNLOAD_DIR/$name
  popd
}
build_package() {
  if [[ -z "$1" ]] || [[ ! -d "$BUILD_DIR/$1" ]]
  then
    echo "ERROR: Invalid package directory '$1'"
    exit 1
  fi
  pushd $BUILD_DIR/$1
  $INSTALL_DIR/bin/python setup.py build
  $INSTALL_DIR/bin/python setup.py install --prefix=$INSTALL_DIR
  popd
}

download_build() {
  if [[ -z "$1" ]] || [[ -z "$2"  ]]
  then
    echo "ERROR: Expected two args, but got '$1' and '$2'"
    exit 1
  fi
  download_package "$2"
  build_package "$1"
}
# pre-build checks
if [[ -d $INSTALL_DIR ]]
then
  echo "Intall dir $INSTALL_DIR already exits, exiting"
  exit 1
fi
sudo mkdir $INSTALL_DIR
sudo chown $USER $INSTALL_DIR
if [[ ! -f $CM_EXT/validator/target/validator.jar ]]
then
  echo "CM Ext $CM_EXT does not exist, exiting"
  exit 1
fi
if [[ ! -w $PARCEL_REPO ]]
then
  echo "Parcel Repo $PARCEL_REPO either does not exist or is not writable, exiting"
  exit 1
fi

if [[ ! -f $TABLEAU_PACKAGE ]]
then
  echo "ERROR: Expected Tableau TDE Python Package at $TABLEAU_PACKAGE"
  exit 1
fi

for dep in ${NATIVE_DEPS[@]}
do
  # FIX test
  if ! rpm -qi $dep
  then
    echo "WARN: Dependency $dep is not installed. Compilation will likely fail."
    echo "WARN: Please run 'yum install ${NATIVE_DEPS[@]}"
    echo -n "Attempting to continue anyway in..."
    for i in $(seq 1 5 | sort -r)
    do
      echo -n "${i}..."
      sleep 1
    done
    echo
  fi
done

sudo rm -rf $BUILD_DIR
mkdir -p $stagingDir

#####################
## Parcel build steps
#####################
# copy meta to staging dir
cp -R meta $stagingDir
# update the parcel.json with the correct version/os
perl -i -pe "s@%VERSION%@$version@g" $stagingDir/meta/parcel.json
perl -i -pe "s@%OS%@$OS@g" $stagingDir/meta/parcel.json

#####################
## Python build steps
#####################
cd $BUILD_DIR
# download python 2.7.5
download_package https://www.python.org/ftp/python/2.7/Python-2.7.tgz
pushd Python-2.7
patch -p1 < $SRC_DIR/src/main/patch/Python-2.7.patch
# compile
./configure --prefix=$INSTALL_DIR
make
make install

# steps ordered based on dependencies
download_build "numpy-1.8.1" "http://iweb.dl.sourceforge.net/project/numpy/NumPy/1.8.1/numpy-1.8.1.tar.gz"
# setuptools
wget https://bitbucket.org/pypa/setuptools/raw/bootstrap/ez_setup.py -O - | $INSTALL_DIR/bin/python
download_build "python-dateutil-1.5" "https://labix.org/download/python-dateutil/python-dateutil-1.5.tar.gz"
download_build "pandas-0.13.0" "https://pypi.python.org/packages/source/p/pandas/pandas-0.13.0.tar.gz"
download_build "scipy-0.13.3" "http://iweb.dl.sourceforge.net/project/scipy/scipy/0.13.3/scipy-0.13.3.tar.gz"
download_build "matplotlib-1.3.1" "http://softlayer-dal.dl.sourceforge.net/project/matplotlib/matplotlib/matplotlib-1.3.1/matplotlib-1.3.1.tar.gz"
download_build "pyflakes-0.8.1" "https://pypi.python.org/packages/source/p/pyflakes/pyflakes-0.8.1.tar.gz"
$INSTALL_DIR/bin/easy_install patsy
download_build "statsmodels-0.5.0" "https://pypi.python.org/packages/source/s/statsmodels/statsmodels-0.5.0.tar.gz"
$INSTALL_DIR/bin/easy_install ipython[all]
# custom oracle stuff
mkdir -p $BUILD_DIR/oracle
pushd $BUILD_DIR/oracle
curl -O "http://hivelocity.dl.sourceforge.net/project/cx-oracle/5.1.2/cx_Oracle-5.1.2-11g-py27-1.x86_64.rpm"
rpm2cpio cx_Oracle-5.1.2-11g-py27-1.x86_64.rpm | cpio -idmv
cp usr/lib/python2.7/site-packages/* $INSTALL_DIR/lib/python2.7/site-packages/
popd
# Tableau
pushd $BUILD_DIR
tar -zxf $TABLEAU_PACKAGE
tdeOutput=$(ls -d DataExtract*)
tdeOutputCount=$(ls -1d DataExtract* | wc -l)
if [[ $tdeOutputCount -ne 1 ]]
then
  echo "ERROR: Expected a single DataExtract* file as output of $TABLEAU_PACKAGE but got '$tdeOutput'"
  exit 1
fi
build_package $tdeOutput
popd
# Sanity checks
for dep in ${PYTHON_DEP_NAMES[@]}
do
  if ! $INSTALL_DIR/bin/python -c "import $dep"
  then
    echo "WARN: Install appears to have completed, but Could not import $dep with $INSTALL_DIR/bin/python"
  fi
done

#####################
## Parcel build steps
#####################
# move the compiled contents to staing dir
mv $INSTALL_DIR/* $stagingDir/
sudo rmdir $INSTALL_DIR
# ensure everything is owned by root in parcel
popd
# validate the parcel
java -jar $CM_EXT/validator/target/validator.jar -d $parcelName/
# create parcel
tar -zcf ${parcelName}-${OS}.parcel --owner root --group root $parcelName/
# install in http dir
mv ${parcelName}-${OS}.parcel $PARCEL_REPO/
# regen manifest
$stagingDir/bin/python $CM_EXT/make_manifest/make_manifest.py $PARCEL_REPO/
