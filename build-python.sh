#!/bin/bash

if [[ -z "$EXECUTED_FROM_BUILD_PARCEL" ]]
then
  echo "ERROR: $0 cannot be excuted on it's own."
  exit 1
fi

extract_tar() {
  name=$1
  if [[ -z $name ]]
  then
    echo "ERROR: invalid tar name"
    exit 1
  fi
  pushd $BUILD_DIR
  tar -zxf $DOWNLOAD_DIR/$name
  popd
}
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
}
download_extract() {
  download_package "$1"
  local name=$(basename $1)
  extract_tar "$name"
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
  download_extract "$2"
  build_package "$1"
}

cd $BUILD_DIR
# download python 2.7.5
download_extract "https://www.python.org/ftp/python/2.7/Python-2.7.tgz"
pushd Python-2.7
patch -p1 < $SRC_DIR/src/main/patch/Python-2.7.patch
# compile
./configure --prefix=$INSTALL_DIR
make
make install
popd

# steps ordered based on dependencies
download_build "numpy-1.8.1" "http://iweb.dl.sourceforge.net/project/numpy/NumPy/1.8.1/numpy-1.8.1.tar.gz"
# setuptools
download_build "setuptools-3.4.4" "https://pypi.python.org/packages/source/s/setuptools/setuptools-3.4.4.tar.gz"
download_build "python-dateutil-1.5" "https://labix.org/download/python-dateutil/python-dateutil-1.5.tar.gz"
download_build "pandas-0.13.0" "https://pypi.python.org/packages/source/p/pandas/pandas-0.13.0.tar.gz"
download_build "scipy-0.13.3" "http://iweb.dl.sourceforge.net/project/scipy/scipy/0.13.3/scipy-0.13.3.tar.gz"
download_build "matplotlib-1.3.1" "http://softlayer-dal.dl.sourceforge.net/project/matplotlib/matplotlib/matplotlib-1.3.1/matplotlib-1.3.1.tar.gz"
download_build "scikit-learn-0.14.1" "https://pypi.python.org/packages/source/s/scikit-learn/scikit-learn-0.14.1.tar.gz"
download_build "pyflakes-0.8.1" "https://pypi.python.org/packages/source/p/pyflakes/pyflakes-0.8.1.tar.gz"
$INSTALL_DIR/bin/easy_install patsy
download_build "statsmodels-0.5.0" "https://pypi.python.org/packages/source/s/statsmodels/statsmodels-0.5.0.tar.gz"
$INSTALL_DIR/bin/easy_install ipython[all]
# custom oracle stuff
mkdir -p $BUILD_DIR/oracle
pushd $BUILD_DIR/oracle
download_package "http://hivelocity.dl.sourceforge.net/project/cx-oracle/5.1.2/cx_Oracle-5.1.2-11g-py27-1.x86_64.rpm"
cp -f $DOWNLOAD_DIR/cx_Oracle-5.1.2-11g-py27-1.x86_64.rpm .
rpm2cpio cx_Oracle-5.1.2-11g-py27-1.x86_64.rpm | cpio -idmv
cp usr/lib/python2.7/site-packages/* $INSTALL_DIR/lib/python2.7/site-packages/
popd
# Tableau
tar -zxf $TABLEAU_PACKAGE
tdeOutput=$(ls -d DataExtract*)
tdeOutputCount=$(ls -1d DataExtract* | wc -l)
if [[ $tdeOutputCount -ne 1 ]]
then
  echo "ERROR: Expected a single DataExtract* file as output of $TABLEAU_PACKAGE but got '$tdeOutput'"
  exit 1
fi
build_package $tdeOutput
# Sanity checks
for dep in ${PYTHON_DEP_NAMES[@]}
do
  if ! $INSTALL_DIR/bin/python -c "import $dep"
  then
    echo "WARN: Install appears to have completed, but Could not import $dep with $INSTALL_DIR/bin/python"
  fi
done

