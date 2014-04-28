#!/bin/bash
# exit on any error
set -e
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
  gdbm-devel db4-devel atlas-devel libpng-devel gcc-gfortran)
PYTHON_DEP_NAMES=(numpy dateutil pandas scipy matplotlib pyflakes statsmodels \
  dataextract sklearn)
# version, note that we may version the 2.7.5 python install ourselves (enable/disable modules)
version=2.7.5.$(date +%Y%m%d.%H%M)
# name of pracel
parcelName=python2.7-$version
# dir we will tar to make the parcel
stagingDir=$BUILD_DIR/$parcelName

################################
## Prebuild checks and env setup
################################
if [[ ! -w $DOWNLOAD_DIR ]]
then
  echo "Download dir $DOWNLOAD_DIR does not exist or is not writable, exiting"
  exit 1
fi
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

# turn on debug statements
set -x
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

EXECUTED_FROM_BUILD_PARCEL=1
. $SRC_DIR/build-python.sh 

#####################
## Parcel build steps
#####################
# move the compiled contents to staing dir
mv $INSTALL_DIR/* $stagingDir/
sudo rmdir $INSTALL_DIR
# validate the parcel
java -jar $CM_EXT/validator/target/validator.jar -d $parcelName/
# create parcel
tar -zcf ${parcelName}-${OS}.parcel --owner root --group root $parcelName/
# install in http dir
mv ${parcelName}-${OS}.parcel $PARCEL_REPO/
# regen manifest
$stagingDir/bin/python $CM_EXT/make_manifest/make_manifest.py $PARCEL_REPO/
