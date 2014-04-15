This is an example parcel for CM. The script build.sh builds a parcel and deploys
the parcel to a parcel repo. This script should NOT be run on a server
where CM is installed. This script depends on the packages gcc and zlib-devel.
These packages can be installed by:

   yum install gcc zlib-devel

# INSTALL_DIR

The directory which python should be installed on the CM nodes (slaves).
Defaults to `/opt/cloudera/parcels/python2.7/`


# PARCEL_REPO
The directory where the parcel should be installed. This directory should be accessible
via http for CM to access. Defaults to `/var/www/html/parcels/`

If you do not have an http server installed, install httpd:

    sudo yum -y install httpd
    sudo service httpd start
    sudo /sbin/chkconfig --level 345 httpd on

Once the webserver is running, add the URL to "Remote Parcel Repository URLs" under parcel configs.


# CM_EXT
The directory where cm_ext is installed. Defaults to `/opt/local/cm_ext/`

Installing CM Ext

    rm -rf /tmp/cm_ext
    cd /tmp
    git clone https://github.com/cloudera/cm_ext.git
    cd cm_ext
    mvn install
    sudo mkdir -p /opt/local
    cd /tmp
    sudo mv cm_ext/ /opt/local/

# Learn more about Parcels

* [CM Ext](https://github.com/cloudera/cm_ext)
* [CM Ext Wiki](https://github.com/cloudera/cm_ext/wiki)
