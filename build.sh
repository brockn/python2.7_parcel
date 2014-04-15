#!/bin/bash
set -e
CM_EXT=${CM_EXT:-/opt/local/cm_ext/}
PARCEL_REPO=${PARCEL_REPO:-/var/www/html/parcels/}
INSTALL_DIR=${INSTALL_DIR:-/opt/cloudera/parcels/python2.7/}
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
SRC=$PWD
version=2.7.5.$(date +%Y%m%d.%H%M%S)
name=python2.7-$version
buildDir=/tmp/build-$USER-$name
stagingDir=$buildDir/$name
rm -rf $buildDir
mkdir -p $stagingDir
cp -R meta $stagingDir
perl -i -pe "s@%VERSION%@$version@g" $stagingDir/meta/parcel.json
perl -i -pe "s@%OS%@$OS@g" $stagingDir/meta/parcel.json
cd $buildDir
curl -O https://www.python.org/ftp/python/2.7/Python-2.7.tgz
tar -zxf Python-2.7.tgz
pushd Python-2.7
perl -i -pe 's@^#( *zlib)@$1@g' Modules/Setup
./configure --prefix=/opt/cloudera/parcels/python2.7
make
sudo make install
sudo mv $INSTALL_DIR/* $stagingDir/
sudo rmdir $INSTALL_DIR
sudo chown -R root:root $stagingDir/
popd
java -jar $CM_EXT/validator/target/validator.jar -d $name/
tar -zcf ${name}-${OS}.parcel $name/
sudo mv ${name}-${OS}.parcel $PARCEL_REPO/
sudo $stagingDir/bin/python $CM_EXT/make_manifest/make_manifest.py $PARCEL_REPO/
