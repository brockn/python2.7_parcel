#!/bin/bash
# exit on any error
set -e
# where to find cm tools
CM_EXT=${CM_EXT:-/opt/local/cm_ext/}
# http accessible dir to install parcels
PARCEL_REPO=${PARCEL_REPO:-/var/www/html/parcels/}
# where the parcel should be installed on the *slaves*
INSTALL_DIR=${INSTALL_DIR:-/opt/cloudera/parcels/python2.7/}
# OS this parcel supports
OS=el6
if [[ -d $INSTALL_DIR ]]
then
  echo "Intall dir $INSTALL_DIR already exits, exiting"
  exit 1
fi
if [[ ! -f $CM_EXT/validator/target/validator.jar ]]
then
  echo "CM Ext $CM_EXT does not exist, exiting"
  exit 1
fi
if [[ ! -d $PARCEL_REPO ]]
then
  echo "Parcel Repo $PARCEL_REPO does not exist, exiting"
  exit 1
fi
# version, note that we may version the 2.7.5 python install ourselves (enable/disable modules)
version=2.7.5.$(date +%Y%m%d.%H%M%S)
# name of pracel
name=python2.7-$version
# where we will build the parcel
buildDir=/tmp/build-$USER-$name
# dir we will tar to make the parcel
stagingDir=$buildDir/$name
rm -rf $buildDir
mkdir -p $stagingDir
# copy meta to staging dir
cp -R meta $stagingDir
# update the parcel.json with the correct version/os
perl -i -pe "s@%VERSION%@$version@g" $stagingDir/meta/parcel.json
perl -i -pe "s@%OS%@$OS@g" $stagingDir/meta/parcel.json
cd $buildDir
# download pythong 2.7.5
curl -O https://www.python.org/ftp/python/2.7/Python-2.7.tgz
tar -zxf Python-2.7.tgz
pushd Python-2.7
# enable zlib
perl -i -pe 's@^#( *zlib)@$1@g' Modules/Setup
# compile
./configure --prefix=/opt/cloudera/parcels/python2.7
make
sudo make install
# move the compiled contents to staing dir
sudo mv $INSTALL_DIR/* $stagingDir/
sudo rmdir $INSTALL_DIR
# ensure everything is owned by root in parcel
sudo chown -R root:root $stagingDir/
popd
# validate the parcel
java -jar $CM_EXT/validator/target/validator.jar -d $name/
# create parcel
tar -zcf ${name}-${OS}.parcel $name/
# install in http dir
sudo mv ${name}-${OS}.parcel $PARCEL_REPO/
# regen manifest
sudo $stagingDir/bin/python $CM_EXT/make_manifest/make_manifest.py $PARCEL_REPO/
