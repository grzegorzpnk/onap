This directory contains files, scripts etc. to setup local development environment for ONAP.

## Setup development environment ##

This tutorial is based on https://wiki.onap.org/display/DW/Building+Entire+ONAP.

#### Prerequisites ####

*  Install **git-repo** tool. The **git-repo** is a tool that allows to clone huge projects controlled by Git. It was originally used for Android development. Steps to install:

```
mkdir ~/bin
PATH=~/bin:$PATH
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
```

* Install Docker and Docker-compose:

```
sudo apt-get install docker.io
sudo apt install docker-compose
```

To allow Docker to run without sudo (the last command will restart an OS):

```
sudo groupadd docker
sudo usermod -aG docker $USER
sudo shutdown now -r
```

#### Downloading & Building sources ####

*  Clone this repository to your workspace on local machine.

`git clone http://10.254.188.33/onap/integration-advnet.git`

*  Before downloading ONAP sources you need to customize your projects. Edit onap-manifest.xml and comment/uncomment sections corresponding to modules that you want to download. By default SDNC, APPC and CCSDK are enabled. Note that you need to leave oparent section.

*  Create onap/ directory and init repo.

```
mkdir onap
cd onap
repo init -u https://github.com/dbainbri-ciena/onap-manifest
cp /home/onap/workspace/integration-advnet/devtool/onap-manifest.xml .repo/manifests/default.xml # local path to onap-manifest
repo sync -q --no-clone-bundle
cp aai/logging-service/License.txt .
cp /home/onap/workspace/integration-advnet/devtool/pom.xml .
```

Before compiling sources using Maven you nned to upload Maven settings.

*  Enter directory ~/.m2/
*  Download settings.xml.

`wget https://jira.onap.org/secure/attachment/10829/settings.xml`

`mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true`

*  After Maven command is completed you should be able to import project to Intellij IDE. 


#### Creating & Running Docker images ####

Firslty you need to login to ONAP Nexus repository. It will be required for all the components to download some images from there.

`docker login nexus3.onap.org:10001`

Use docker/docker as username and password.

##### CCSDK #####

> **Note!** You can have problems with compiling CCSDK from onap/ root directory, 

The procedure to compile CCSDK sources:

```
cd ccsdk/parent
mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
cd ..
cd sli/core
mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
cd ..
cd adaptors
mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
cd ..
cd northbound
mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
cd ..
cd plugins
mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true
```

Procedure to build CCSDK Docker images:

```
cd ccsdk/distribution
cd ubuntu
mvn clean install -P docker
cd ..
cd opendaylight
mvn clean install -P docker
cd ..
cd odlsli
mvn clean install -P docker
cd ..
cd dgbuilder-docker
mvn clean install -P docker
```

After this operation you should see following images on `docker images` list:

```
REPOSITORY                                         TAG                                       IMAGE ID            CREATED              SIZE
onap/ccsdk-dgbuilder-image                         latest                                    6f2d59764b51        About a minute ago   1.04 GB
onap/ccsdk-ubuntu-image                            latest                                    6653e8fb9c92        3 minutes ago        954 MB
onap/ccsdk-odlsli-image                            latest                                    0a225598810c        10 minutes ago       1.8 GB
onap/ccsdk-odl-oxygen-image                        latest                                    fab5f5a14caf        14 minutes ago       1.72 GB
```

These Docker images will be used further to build APP-C and SDN-C.

##### APP-C #####

Instruction mainly based on https://wiki.onap.org/display/DW/Building+and+Running+APPC+Docker+Images.

In order to use the *onap/ccsdk-odlsli-image* that you have built before you need to introduce modifications to APPC Dockerfile.

Open directory *appc/deployment/installation/appc/src/main/docker* and modify Dockerfile as follows:

```diff
 # ============LICENSE_END============================================
 
 # Base ubuntu with added packages needed for ONAP
-FROM onap/ccsdk-odlsli-image:0.2.3
+FROM onap/ccsdk-odlsli-image:latest
 MAINTAINER APP-C Team (appc@lists.openecomp.org)
```

> **Alternative** 
>
> Follow this procedure if you want to use stable Docker image of CCSDK ODLSLI from official Nexus repository.
>
> Download the required CCSDK image:
> 
> `docker pull nexus3.onap.org:10001/onap/ccsdk-odlsli-image:0.2.3`
> 
> and put a proper tag.
>
> `docker tag nexus3.onap.org:10001/onap/ccsdk-odlsli-image:0.2.3 onap/ccsdk-odlsli-image:0.2.3`

From the root appc/ directory invoke Maven build command (if not done yet).

`mvn clean install -U -DskipTests=true -Dmaven.test.skip=true -Dmaven.javadoc.skip=true`

Enter deployment/ directory and run:

`mvn clean install -P docker`

After this operation you should see onap/appc-image on the list (use `docker images`). Example:

```
onap/appc-image                                    1.4.0-SNAPSHOT-20180802T112607Z           90f1c7157c8a        3 hours ago         2.97 GB
onap/appc-image                                    1.4.0-SNAPSHOT-latest                     90f1c7157c8a        3 hours ago         2.97 GB
onap/appc-image                                    latest                                    90f1c7157c8a        3 hours ago         2.97 GB
```

Now, you need to run Docker images. In the deployment/ directory you can find docker-compose/ folder. From this directory run:

> **Note!** Before invoking docker-compose check if there are no cached APPC images by using `docker ps -a`. If they exist, use `docker rm -f <ID>` to remove them.


`docker-compose up -d`

> **Note!** You can comment 'dgbuilder' section in docker-compose.yml file as it may require some additional pre-pulled images.

The containers are being run. It should take up to 10 minutes to initilize OpenDayLight and its features. You can check logs using:

`docker-compose logs`

When the initialization will be completed you should see the logo of Opendaylight in the logs.

In order to check if APP-C is running:

*  Go to http://localhost:8282/apidoc/explorer/index.html
*  The username is "admin", password is "Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U" (or admin/admin).

In order to delete APPC containers run (from docker-compose directory):

`docker-compose down`

##### APP-C DOCS #####

For modifications in documentation of APP-C perform following steps

Clone general docs repository of ONAP

```
git clone http://gerrit.onap.org/r/doc
```

Install Sphinx doc builder

```
cd doc
sudo pip install -r etc/requirements.txt
```

Copy configuration files and resources into APP-C docs folder

```
cp -r docs/conf.py <path-to-your-folder>/
cp -r docs/_static/ <path-to-your-folder>/
```

Build HTML files from .rst files

```
sphinx-build -b html . ~/onap/source/doc-test

```

##### APP-C CDT #####
Clone APPC/CDT projekt

```
git clone https://gerrit.onap.org/r/appc/cdt
```

Install npm, angular-cli, nodejs and nodejs-legacy
```
sudo apt get install npm
sudo su
npm install -g @angular/cli@1.2.3
npm link @angular/cli
exit
curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -
sudo apt install nodejs
sudo apt install nodejs-legacy
```

Install required node modules and libraries
```
cd cdt
npm install
```

Read README file where is written how to build and testr application

##### SDNC-C #####

For SDN-C you need firstly to compile Maven projects in the following order:

*  sdnc/core
*  sdnc/adaptors
*  sdnc/northbound
*  sdnc/plugins
*  sdnc/oam

Then, you need to pre-pull Docker images that are needed to build SDNC Docker images.

```
docker pull nexus3.onap.org:10001/onap/ccsdk-ubuntu-image:0.3.0-SNAPSHOT

```

Then, you need to build particular SDN-C Docker images. Enter directories in the following order:

*  admportal/
*  ansible-server/
*  dmaap-listener/
*  ueb-listener/
*  sdnc/
*  dgbuilder/

and invoke there (one dir by one) below command:

`mvn clean install -P docker`

Check if Docker images have been created:

`docker images`

You should see the list of Docker images related with SDN-C, e.g.:

```
REPOSITORY                                         TAG                                       IMAGE ID            CREATED              SIZE
onap/sdnc-ansible-server-image                     1.4-STAGING-latest                        3f359dcba38f        About a minute ago   1.13 GB
onap/sdnc-ansible-server-image                     1.4.0-SNAPSHOT                            3f359dcba38f        About a minute ago   1.13 GB
onap/sdnc-ansible-server-image                     1.4.0-SNAPSHOT-STAGING-20180802T130336Z   3f359dcba38f        About a minute ago   1.13 GB
onap/sdnc-ansible-server-image                     latest                                    3f359dcba38f        About a minute ago   1.13 GB
```
Go to followign directory

* oam/installation/src/main/yaml

Define system variable MTU=1500

Edit docker-compose.yml file, change docker-compose version to 2.0 and comment out sdnc:dns section and enter:
`- 10.0.1.100`

in sdnc section
